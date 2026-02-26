import Foundation
import Testing
@testable import metropolist

@Suite("Extended Stats", .tags(.gamification, .stats))
@MainActor
struct ExtendedStatsTests {
    // MARK: - Department Coverage

    @Test("Department coverage counts visited stations per department")
    func departmentCoverageBasic() {
        let stops = [
            TestFixtures.stop(station: "s-paris1"),
            TestFixtures.stop(station: "s-paris2"),
            TestFixtures.stop(station: "s-92"),
        ]
        let stationMeta: [String: StationMetadata] = [
            "s-paris1": TestFixtures.stationMeta(name: "Châtelet", postalCode: "75001"),
            "s-paris2": TestFixtures.stationMeta(name: "Nation", postalCode: "75012"),
            "s-92": TestFixtures.stationMeta(name: "La Défense", postalCode: "92060"),
        ]
        let input = GamificationInput(
            completedStops: stops,
            travels: [],
            lineMetadata: [:],
            stationMetadata: stationMeta
        )
        let stats = GamificationEngine.computeExtendedStats(from: input)

        let paris = stats.departmentCoverage.first(where: { $0.department == "75" })
        #expect(paris?.visited == 2)
        #expect(paris?.total == 2)

        let hautsDeSeine = stats.departmentCoverage.first(where: { $0.department == "92" })
        #expect(hautsDeSeine?.visited == 1)
        #expect(hautsDeSeine?.total == 1)
    }

    @Test("Non-IDF postal code excluded from department coverage")
    func nonIDFPostalCodeExcluded() {
        let stops = [TestFixtures.stop(station: "s-lyon")]
        let stationMeta: [String: StationMetadata] = [
            "s-lyon": TestFixtures.stationMeta(name: "Lyon Station", postalCode: "69001"),
        ]
        let input = GamificationInput(
            completedStops: stops,
            travels: [],
            lineMetadata: [:],
            stationMetadata: stationMeta
        )
        let stats = GamificationEngine.computeExtendedStats(from: input)
        // All department entries should have 0 visited and 0 total
        for dept in stats.departmentCoverage {
            #expect(dept.visited == 0)
            #expect(dept.total == 0)
        }
    }

    @Test("Station with nil postal code excluded from coverage")
    func nilPostalCodeExcluded() {
        let stops = [TestFixtures.stop(station: "s-unknown")]
        let stationMeta: [String: StationMetadata] = [
            "s-unknown": TestFixtures.stationMeta(name: "Unknown", postalCode: nil),
        ]
        let input = GamificationInput(
            completedStops: stops,
            travels: [],
            lineMetadata: [:],
            stationMetadata: stationMeta
        )
        let stats = GamificationEngine.computeExtendedStats(from: input)
        for dept in stats.departmentCoverage {
            #expect(dept.visited == 0)
            #expect(dept.total == 0)
        }
    }

    // MARK: - Fare Zone Coverage

    @Test("Fare zone coverage groups stations by zone")
    func fareZoneCoverage() {
        let stops = [
            TestFixtures.stop(station: "s-z1"),
            TestFixtures.stop(station: "s-z2"),
        ]
        let stationMeta: [String: StationMetadata] = [
            "s-z1": TestFixtures.stationMeta(fareZone: "1"),
            "s-z2": TestFixtures.stationMeta(fareZone: "2"),
            "s-z2b": TestFixtures.stationMeta(fareZone: "2"), // not visited, but in total
        ]
        let input = GamificationInput(
            completedStops: stops,
            travels: [],
            lineMetadata: [:],
            stationMetadata: stationMeta
        )
        let stats = GamificationEngine.computeExtendedStats(from: input)

        let zone1 = stats.fareZoneCoverage.first(where: { $0.zone == "1" })
        #expect(zone1?.visited == 1)
        #expect(zone1?.total == 1)

        let zone2 = stats.fareZoneCoverage.first(where: { $0.zone == "2" })
        #expect(zone2?.visited == 1)
        #expect(zone2?.total == 2)
    }

    @Test("Zones with zero total stations are excluded")
    func emptyZonesExcluded() {
        let input = GamificationInput(
            completedStops: [],
            travels: [],
            lineMetadata: [:],
            stationMetadata: [:]
        )
        let stats = GamificationEngine.computeExtendedStats(from: input)
        #expect(stats.fareZoneCoverage.isEmpty)
    }

    // MARK: - Top Stations

    @Test("Top stations ranked by visit count, limited to 5")
    func topStationsRanking() {
        // Create 7 stations with varying visit counts
        var stops: [CompletedStopRecord] = []
        for i in 0 ..< 7 {
            let visitCount = 7 - i // station-0 has 7 visits, station-6 has 1
            for _ in 0 ..< visitCount {
                stops.append(TestFixtures.stop(station: "station-\(i)"))
            }
        }
        var stationMeta: [String: StationMetadata] = [:]
        for i in 0 ..< 7 {
            stationMeta["station-\(i)"] = TestFixtures.stationMeta(name: "Station \(i)")
        }
        let input = GamificationInput(
            completedStops: stops,
            travels: [],
            lineMetadata: [:],
            stationMetadata: stationMeta
        )
        let stats = GamificationEngine.computeExtendedStats(from: input)

        #expect(stats.topStations.count == 5)
        #expect(stats.topStations[0].visitCount == 7)
        #expect(stats.topStations[4].visitCount == 3)
    }

    @Test("Station name falls back to sourceID when metadata missing")
    func stationNameFallback() {
        let stops = [TestFixtures.stop(station: "unknown-id")]
        let input = GamificationInput(
            completedStops: stops,
            travels: [],
            lineMetadata: [:],
            stationMetadata: [:] // no metadata for this station
        )
        let stats = GamificationEngine.computeExtendedStats(from: input)
        #expect(stats.topStations.first?.name == "unknown-id")
    }

    // MARK: - Top Lines

    @Test("Top lines ranked by travel count")
    func topLinesRanking() {
        let travels = [
            TestFixtures.travel(line: "METRO:1"),
            TestFixtures.travel(line: "METRO:1"),
            TestFixtures.travel(line: "METRO:1"),
            TestFixtures.travel(line: "RER:A"),
            TestFixtures.travel(line: "RER:A"),
            TestFixtures.travel(line: "BUS:42"),
        ]
        let lineMeta: [String: LineMetadata] = [
            "METRO:1": TestFixtures.lineMeta(sourceID: "METRO:1", shortName: "1", mode: .metro),
            "RER:A": TestFixtures.lineMeta(sourceID: "RER:A", shortName: "A", mode: .rer),
            "BUS:42": TestFixtures.lineMeta(sourceID: "BUS:42", shortName: "42", mode: .bus),
        ]
        let input = GamificationInput(
            completedStops: [],
            travels: travels,
            lineMetadata: lineMeta,
            stationMetadata: [:]
        )
        let stats = GamificationEngine.computeExtendedStats(from: input)
        #expect(stats.topLines.count == 3)
        #expect(stats.topLines[0].travelCount == 3)
        #expect(stats.topLines[0].shortName == "1")
    }

    // MARK: - Busiest Day / Hour

    @Test("Busiest day of week identified correctly")
    func busiestDay() throws {
        // Reference date (2025-01-15) is a Wednesday
        // Create 3 travels on Wednesday, 1 on Thursday
        let travels = [
            TestFixtures.travel(at: TestFixtures.referenceDate),
            TestFixtures.travel(at: TestFixtures.referenceDate),
            TestFixtures.travel(at: TestFixtures.referenceDate),
            TestFixtures.travel(at: TestFixtures.date(daysOffset: 1)), // Thursday
        ]
        let input = GamificationInput(
            completedStops: [],
            travels: travels,
            lineMetadata: [:],
            stationMetadata: [:]
        )
        let stats = GamificationEngine.computeExtendedStats(from: input)
        let busiest = try #require(stats.busiestDayOfWeek)
        // Wednesday is weekday 4 in Calendar (Sun=1, Mon=2, ..., Wed=4)
        #expect(busiest.dayIndex == 4)
        #expect(busiest.allDays.count == 7)
    }

    @Test("Empty travels produce nil busiest stats")
    func emptyTravelsNilStats() {
        let input = GamificationInput(
            completedStops: [],
            travels: [],
            lineMetadata: [:],
            stationMetadata: [:]
        )
        let stats = GamificationEngine.computeExtendedStats(from: input)
        #expect(stats.busiestDayOfWeek == nil)
        #expect(stats.busiestHourOfDay == nil)
    }
}
