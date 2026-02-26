import Foundation
import Testing
@testable import metropolist

@Suite("Travels Per Week", .tags(.gamification, .stats))
@MainActor
struct TravelsPerWeekTests {
    // MARK: - Empty / Single

    @Test("Empty travels returns empty array")
    func emptyTravels() {
        let input = GamificationInput(
            completedStops: [],
            travels: [],
            lineMetadata: [:],
            stationMetadata: [:]
        )
        let stats = GamificationEngine.computeExtendedStats(from: input)
        #expect(stats.travelsPerWeek.isEmpty)
    }

    @Test("Single travel returns one week entry")
    func singleTravel() {
        let input = GamificationInput(
            completedStops: [],
            travels: [TestFixtures.travel(at: TestFixtures.referenceDate)],
            lineMetadata: [:],
            stationMetadata: [:]
        )
        let stats = GamificationEngine.computeExtendedStats(from: input)
        #expect(stats.travelsPerWeek.count == 1)
        #expect(stats.travelsPerWeek[0].count == 1)
    }

    // MARK: - Aggregation

    @Test("Travels in same week are aggregated into one entry")
    func sameWeekAggregated() {
        // Reference date is Wed Jan 15 2025. Mon=Jan 13, Fri=Jan 17 are in the same Mon-start week.
        let travels = [
            TestFixtures.travel(at: TestFixtures.date(daysOffset: -2)), // Mon Jan 13
            TestFixtures.travel(at: TestFixtures.referenceDate),        // Wed Jan 15
            TestFixtures.travel(at: TestFixtures.date(daysOffset: 2)),  // Fri Jan 17
        ]
        let input = GamificationInput(
            completedStops: [],
            travels: travels,
            lineMetadata: [:],
            stationMetadata: [:]
        )
        let stats = GamificationEngine.computeExtendedStats(from: input)
        #expect(stats.travelsPerWeek.count == 1)
        #expect(stats.travelsPerWeek[0].count == 3)
    }

    @Test("Travels across two weeks produce two entries")
    func twoWeeks() {
        let travels = [
            TestFixtures.travel(at: TestFixtures.referenceDate),           // Wed Jan 15
            TestFixtures.travel(at: TestFixtures.date(daysOffset: 7)),     // Wed Jan 22
        ]
        let input = GamificationInput(
            completedStops: [],
            travels: travels,
            lineMetadata: [:],
            stationMetadata: [:]
        )
        let stats = GamificationEngine.computeExtendedStats(from: input)
        #expect(stats.travelsPerWeek.count == 2)
        #expect(stats.travelsPerWeek[0].count == 1)
        #expect(stats.travelsPerWeek[1].count == 1)
    }

    // MARK: - Gap Filling

    @Test("Gap weeks are filled with zero counts")
    func gapWeeksFilled() {
        // Two weeks apart = one gap week in between
        let travels = [
            TestFixtures.travel(at: TestFixtures.referenceDate),            // Wed Jan 15
            TestFixtures.travel(at: TestFixtures.date(daysOffset: 14)),     // Wed Jan 29
        ]
        let input = GamificationInput(
            completedStops: [],
            travels: travels,
            lineMetadata: [:],
            stationMetadata: [:]
        )
        let stats = GamificationEngine.computeExtendedStats(from: input)
        #expect(stats.travelsPerWeek.count == 3)
        #expect(stats.travelsPerWeek[0].count == 1) // Week of Jan 13
        #expect(stats.travelsPerWeek[1].count == 0) // Gap: week of Jan 20
        #expect(stats.travelsPerWeek[2].count == 1) // Week of Jan 27
    }

    // MARK: - 12-Week Limit

    @Test("Old weeks are trimmed when history exceeds window")
    func oldWeeksTrimmed() {
        // Create one travel per week for 20 weeks
        let travels = (0 ..< 20).map { week in
            TestFixtures.travel(at: TestFixtures.date(daysOffset: week * 7))
        }
        let input = GamificationInput(
            completedStops: [],
            travels: travels,
            lineMetadata: [:],
            stationMetadata: [:]
        )
        let stats = GamificationEngine.computeExtendedStats(from: input)
        // The window goes back 12 weeks from the last, producing 13 entries
        // (the cutoff week itself + 12 weeks after it). Either way, the earliest weeks are dropped.
        #expect(stats.travelsPerWeek.count < 20)
        #expect(stats.travelsPerWeek.count == 13)
    }

    // MARK: - Monday Start Boundary

    @Test("Sunday and Monday fall in different weeks (Monday-start)")
    func mondayStartBoundary() {
        // Jan 15 (Wed) + 4 = Jan 19 (Sun), + 5 = Jan 20 (Mon)
        // With Monday-start weeks, Sunday is the last day of a week and Monday starts a new one.
        let travels = [
            TestFixtures.travel(at: TestFixtures.date(daysOffset: 4)),  // Sun Jan 19
            TestFixtures.travel(at: TestFixtures.date(daysOffset: 5)),  // Mon Jan 20
        ]
        let input = GamificationInput(
            completedStops: [],
            travels: travels,
            lineMetadata: [:],
            stationMetadata: [:]
        )
        let stats = GamificationEngine.computeExtendedStats(from: input)
        #expect(stats.travelsPerWeek.count == 2)
    }
}
