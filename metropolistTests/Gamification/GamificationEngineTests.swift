import Testing
@testable import metropolist

@Suite("Gamification Engine", .tags(.gamification))
@MainActor
struct GamificationEngineTests {
    // MARK: - Empty Input

    @Test("Empty input produces empty snapshot")
    func emptyInput() {
        let input = GamificationInput(
            completedStops: [],
            travels: [],
            lineMetadata: [:],
            stationMetadata: [:]
        )
        let snapshot = GamificationEngine.computeSnapshot(from: input)

        #expect(snapshot.totalXP == 0)
        #expect(snapshot.level.number == 1)
        #expect(snapshot.lineBadges.isEmpty)
        #expect(snapshot.modeBadges.isEmpty)
        #expect(snapshot.stats.totalTravels == 0)
        #expect(snapshot.stats.totalStationsVisited == 0)
    }

    // MARK: - Single Travel XP Breakdown

    @Test("Single metro travel with one stop gives correct XP breakdown")
    func singleTravelXP() {
        let input = TestFixtures.inputWithStops(count: 1, totalStations: 25, line: "METRO:1", mode: .metro)
        let snapshot = GamificationEngine.computeSnapshot(from: input)

        // 1 travel × 5 = 5 travelXP
        #expect(snapshot.xpBreakdown.travelXP == 5)
        // 1 unique stop × 20 = 20 stopXP
        #expect(snapshot.xpBreakdown.stopXP == 20)
        // First metro line = 50 firstLineXP
        #expect(snapshot.xpBreakdown.firstLineXP == 50)
        // Not completed, so 0 lineCompletionXP
        #expect(snapshot.xpBreakdown.lineCompletionXP == 0)
        // Total = 5 + 20 + 50 + streakXP + achievementXP
        #expect(snapshot.totalXP == snapshot.xpBreakdown.total)
    }

    // MARK: - Bus vs Metro First-Line XP

    @Test("Bus first-line XP is 25, metro is 50")
    func firstLineXPByMode() {
        let busInput = TestFixtures.inputWithStops(count: 1, totalStations: 50, line: "BUS:42", mode: .bus)
        let metroInput = TestFixtures.inputWithStops(count: 1, totalStations: 25, line: "METRO:1", mode: .metro)

        let busSnapshot = GamificationEngine.computeSnapshot(from: busInput)
        let metroSnapshot = GamificationEngine.computeSnapshot(from: metroInput)

        #expect(busSnapshot.xpBreakdown.firstLineXP == 25)
        #expect(metroSnapshot.xpBreakdown.firstLineXP == 50)
    }

    // MARK: - Line Completion Gold Badge

    @Test("Completing all stops on a line awards gold badge and completion XP")
    func lineCompletionGoldBadge() throws {
        let totalStations = 5
        let lineID = "TRAM:3a"
        let stops = (0 ..< totalStations).map { i in
            TestFixtures.stop(line: lineID, station: "tram-stop-\(i)", at: TestFixtures.date(daysOffset: i))
        }
        let travels = [TestFixtures.travel(line: lineID, at: TestFixtures.referenceDate)]
        let meta = TestFixtures.lineMeta(sourceID: lineID, shortName: "3a", mode: .tram, totalStations: totalStations)

        let input = GamificationInput(
            completedStops: stops,
            travels: travels,
            lineMetadata: [lineID: meta],
            stationMetadata: [:]
        )
        let snapshot = GamificationEngine.computeSnapshot(from: input)

        let badge = try #require(snapshot.lineBadges[lineID])
        #expect(badge == .gold)

        // Line completion XP = 50 base + (5 stations × 5) = 75
        #expect(snapshot.xpBreakdown.lineCompletionXP == 75)
    }

    // MARK: - Partial Progress Badge

    @Test("Partial progress awards correct badge tier")
    func partialProgressBadge() throws {
        // 10 of 25 = 40% → silver
        let input = TestFixtures.inputWithStops(count: 10, totalStations: 25)
        let snapshot = GamificationEngine.computeSnapshot(from: input)

        let badge = try #require(snapshot.lineBadges["METRO:1"])
        #expect(badge == .silver)

        let progress = try #require(snapshot.lineProgress["METRO:1"])
        #expect(progress.completedStops == 10)
        #expect(progress.totalStops == 25)
    }

    // MARK: - Mode Badge Aggregation

    @Test("Mode badge aggregates all lines of that mode")
    func modeBadgeAggregation() throws {
        // Two metro lines: line A has 5/10 (50% = silver), line B has 0/10
        // Combined: 5/20 = 25% → bronze
        let lineA = "METRO:A"
        let lineB = "METRO:B"
        let stops = (0 ..< 5).map { i in
            TestFixtures.stop(line: lineA, station: "a-\(i)", at: TestFixtures.date(daysOffset: i))
        }
        let travels = [TestFixtures.travel(line: lineA, at: TestFixtures.referenceDate)]
        let metaA = TestFixtures.lineMeta(sourceID: lineA, shortName: "A", mode: .metro, totalStations: 10)
        let metaB = TestFixtures.lineMeta(sourceID: lineB, shortName: "B", mode: .metro, totalStations: 10)

        let input = GamificationInput(
            completedStops: stops,
            travels: travels,
            lineMetadata: [lineA: metaA, lineB: metaB],
            stationMetadata: [:]
        )
        let snapshot = GamificationEngine.computeSnapshot(from: input)

        let modeBadge = try #require(snapshot.modeBadges[.metro])
        #expect(modeBadge == .bronze)
    }

    // MARK: - Stats

    @Test("Stats reflect travel and station counts")
    func statsCount() {
        let lineID = "METRO:1"
        let stops = (0 ..< 3).map { i in
            TestFixtures.stop(line: lineID, station: "s-\(i)", at: TestFixtures.date(daysOffset: i))
        }
        let travels = (0 ..< 2).map { i in
            TestFixtures.travel(line: lineID, from: "s-\(i)", to: "s-\(i + 1)", at: TestFixtures.date(daysOffset: i))
        }
        let meta = TestFixtures.lineMeta(sourceID: lineID, totalStations: 25)

        let input = GamificationInput(
            completedStops: stops,
            travels: travels,
            lineMetadata: [lineID: meta],
            stationMetadata: [:]
        )
        let snapshot = GamificationEngine.computeSnapshot(from: input)

        #expect(snapshot.stats.totalTravels == 2)
        #expect(snapshot.stats.totalStationsVisited == 3)
        #expect(snapshot.stats.totalLinesStarted == 1)
        #expect(snapshot.stats.totalLinesCompleted == 0)
    }

    // MARK: - XP Total Consistency

    @Test("totalXP always equals xpBreakdown.total")
    func xpConsistency() {
        let input = TestFixtures.inputWithStops(count: 5, totalStations: 25)
        let snapshot = GamificationEngine.computeSnapshot(from: input)

        #expect(snapshot.totalXP == snapshot.xpBreakdown.total)
    }
}
