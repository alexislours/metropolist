import Foundation
import Testing
@testable import metropolist

@Suite("Completion Dates", .tags(.gamification, .badges))
@MainActor
struct CompletionDateTests {
    // MARK: - Mode Badge Gold

    @Test("Mode badge is gold when all lines of that mode are 100% complete")
    func modeBadgeGoldAllComplete() throws {
        let lineA = "METRO:A"
        let lineB = "METRO:B"
        let stopsA = (0 ..< 3).map { i in
            TestFixtures.stop(line: lineA, station: "a-\(i)", at: TestFixtures.date(daysOffset: i))
        }
        let stopsB = (0 ..< 3).map { i in
            TestFixtures.stop(line: lineB, station: "b-\(i)", at: TestFixtures.date(daysOffset: i))
        }
        let input = GamificationInput(
            completedStops: stopsA + stopsB,
            travels: [
                TestFixtures.travel(line: lineA, at: TestFixtures.referenceDate),
                TestFixtures.travel(line: lineB, at: TestFixtures.referenceDate),
            ],
            lineMetadata: [
                lineA: TestFixtures.lineMeta(sourceID: lineA, shortName: "A", mode: .metro, totalStations: 3),
                lineB: TestFixtures.lineMeta(sourceID: lineB, shortName: "B", mode: .metro, totalStations: 3),
            ],
            stationMetadata: [:]
        )
        let snapshot = GamificationEngine.computeSnapshot(from: input)
        let badge = try #require(snapshot.modeBadges[.metro])
        #expect(badge == .gold)
    }

    @Test("Mode badge is not gold when one line is incomplete")
    func modeBadgeNotGoldPartial() throws {
        let lineA = "METRO:A"
        let lineB = "METRO:B"
        let stopsA = (0 ..< 3).map { i in
            TestFixtures.stop(line: lineA, station: "a-\(i)", at: TestFixtures.date(daysOffset: i))
        }
        // Only 2 of 3 stops for line B
        let stopsB = (0 ..< 2).map { i in
            TestFixtures.stop(line: lineB, station: "b-\(i)", at: TestFixtures.date(daysOffset: i))
        }
        let input = GamificationInput(
            completedStops: stopsA + stopsB,
            travels: [
                TestFixtures.travel(line: lineA, at: TestFixtures.referenceDate),
                TestFixtures.travel(line: lineB, at: TestFixtures.referenceDate),
            ],
            lineMetadata: [
                lineA: TestFixtures.lineMeta(sourceID: lineA, shortName: "A", mode: .metro, totalStations: 3),
                lineB: TestFixtures.lineMeta(sourceID: lineB, shortName: "B", mode: .metro, totalStations: 3),
            ],
            stationMetadata: [:]
        )
        let snapshot = GamificationEngine.computeSnapshot(from: input)
        let badge = try #require(snapshot.modeBadges[.metro])
        #expect(badge != .gold)
    }

    // MARK: - Line Completion Date

    @Test("Line completion date is the date of the last needed station")
    func lineCompletionDateIsLastStation() throws {
        let lineID = "TRAM:1"
        let stops = [
            TestFixtures.stop(line: lineID, station: "s-0", at: TestFixtures.date(daysOffset: 0)),
            TestFixtures.stop(line: lineID, station: "s-1", at: TestFixtures.date(daysOffset: 5)),
            TestFixtures.stop(line: lineID, station: "s-2", at: TestFixtures.date(daysOffset: 10)),
        ]
        let input = GamificationInput(
            completedStops: stops,
            travels: [TestFixtures.travel(line: lineID, at: TestFixtures.referenceDate)],
            lineMetadata: [lineID: TestFixtures.lineMeta(sourceID: lineID, shortName: "1", mode: .tram, totalStations: 3)],
            stationMetadata: [:]
        )
        let snapshot = GamificationEngine.computeSnapshot(from: input)

        // "premiere_ligne" achievement should unlock at the date of the last station (day 10)
        let achievement = snapshot.achievements.first(where: { $0.id == "premiere_ligne" })
        #expect(achievement?.isUnlocked == true)
        #expect(achievement?.unlockedAt == TestFixtures.date(daysOffset: 10))
    }

    // MARK: - Mode Completion Date

    @Test("Mode completion date is the latest line completion date")
    func modeCompletionDateIsLatest() throws {
        let lineA = "TRAM:A"
        let lineB = "TRAM:B"
        // Line A completed at day 5 (last station)
        let stopsA = (0 ..< 2).map { i in
            TestFixtures.stop(line: lineA, station: "a-\(i)", at: TestFixtures.date(daysOffset: i * 5))
        }
        // Line B completed at day 10 (last station)
        let stopsB = (0 ..< 2).map { i in
            TestFixtures.stop(line: lineB, station: "b-\(i)", at: TestFixtures.date(daysOffset: i * 10))
        }
        let input = GamificationInput(
            completedStops: stopsA + stopsB,
            travels: [
                TestFixtures.travel(line: lineA, at: TestFixtures.referenceDate),
                TestFixtures.travel(line: lineB, at: TestFixtures.referenceDate),
            ],
            lineMetadata: [
                lineA: TestFixtures.lineMeta(sourceID: lineA, shortName: "A", mode: .tram, totalStations: 2),
                lineB: TestFixtures.lineMeta(sourceID: lineB, shortName: "B", mode: .tram, totalStations: 2),
            ],
            stationMetadata: [:]
        )
        let snapshot = GamificationEngine.computeSnapshot(from: input)

        // "baron_du_tramway" should unlock at day 10 (latest of the two line completions)
        let achievement = snapshot.achievements.first(where: { $0.id == "baron_du_tramway" })
        #expect(achievement?.isUnlocked == true)
        #expect(achievement?.unlockedAt == TestFixtures.date(daysOffset: 10))
    }

    @Test("Mode completion nil when one line is incomplete")
    func modeCompletionNilPartial() {
        let lineA = "TRAM:A"
        let lineB = "TRAM:B"
        let stopsA = (0 ..< 2).map { i in
            TestFixtures.stop(line: lineA, station: "a-\(i)", at: TestFixtures.date(daysOffset: i))
        }
        // Only 1 of 2 for line B
        let stopsB = [TestFixtures.stop(line: lineB, station: "b-0", at: TestFixtures.referenceDate)]
        let input = GamificationInput(
            completedStops: stopsA + stopsB,
            travels: [
                TestFixtures.travel(line: lineA, at: TestFixtures.referenceDate),
                TestFixtures.travel(line: lineB, at: TestFixtures.referenceDate),
            ],
            lineMetadata: [
                lineA: TestFixtures.lineMeta(sourceID: lineA, shortName: "A", mode: .tram, totalStations: 2),
                lineB: TestFixtures.lineMeta(sourceID: lineB, shortName: "B", mode: .tram, totalStations: 2),
            ],
            stationMetadata: [:]
        )
        let snapshot = GamificationEngine.computeSnapshot(from: input)
        let achievement = snapshot.achievements.first(where: { $0.id == "baron_du_tramway" })
        #expect(achievement?.isUnlocked == false)
    }

    // MARK: - Duplicate Stops

    @Test("Line completion ignores duplicate stop records for the same station")
    func lineCompletionIgnoresDuplicates() throws {
        let lineID = "METRO:1"
        // 5 stop records, but only 3 unique station IDs
        let stops = [
            TestFixtures.stop(line: lineID, station: "s-0", at: TestFixtures.date(daysOffset: 0)),
            TestFixtures.stop(line: lineID, station: "s-1", at: TestFixtures.date(daysOffset: 1)),
            TestFixtures.stop(line: lineID, station: "s-0", at: TestFixtures.date(daysOffset: 2)), // duplicate
            TestFixtures.stop(line: lineID, station: "s-1", at: TestFixtures.date(daysOffset: 3)), // duplicate
            TestFixtures.stop(line: lineID, station: "s-2", at: TestFixtures.date(daysOffset: 4)), // 3rd unique
        ]
        let input = GamificationInput(
            completedStops: stops,
            travels: [TestFixtures.travel(line: lineID, at: TestFixtures.referenceDate)],
            lineMetadata: [lineID: TestFixtures.lineMeta(sourceID: lineID, shortName: "1", mode: .metro, totalStations: 3)],
            stationMetadata: [:]
        )
        let snapshot = GamificationEngine.computeSnapshot(from: input)

        // Line should be completed at day 4 (when the 3rd unique station was visited)
        let progress = try #require(snapshot.lineProgress[lineID])
        #expect(progress.badge == .gold)

        let achievement = snapshot.achievements.first(where: { $0.id == "premiere_ligne" })
        #expect(achievement?.isUnlocked == true)
        #expect(achievement?.unlockedAt == TestFixtures.date(daysOffset: 4))
    }
}
