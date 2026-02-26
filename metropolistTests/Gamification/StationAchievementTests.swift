import Foundation
import Testing
@testable import metropolist

@Suite("Station Achievements", .tags(.gamification, .achievements))
@MainActor
struct StationAchievementTests {
    // MARK: - Bir-Hakeim on Line 6

    @Test("Bir-Hakeim on line 6 returns completion date")
    func birHakeimLine6() {
        let stop = TestFixtures.stop(line: "METRO:6", station: "bh-station", at: TestFixtures.referenceDate)
        let input = GamificationInput(
            completedStops: [stop],
            travels: [],
            lineMetadata: ["METRO:6": TestFixtures.lineMeta(sourceID: "METRO:6", shortName: "6", mode: .metro)],
            stationMetadata: ["bh-station": TestFixtures.stationMeta(name: "Bir-Hakeim")]
        )
        let result = GamificationEngine.computeStationAchievements(input: input, sortedTravels: [])
        #expect(result.firstBirHakeimLine6Date == TestFixtures.referenceDate)
    }

    @Test("Bir-Hakeim on line 6 is case-insensitive")
    func birHakeimCaseInsensitive() {
        let stop = TestFixtures.stop(line: "METRO:6", station: "bh-station", at: TestFixtures.referenceDate)
        let input = GamificationInput(
            completedStops: [stop],
            travels: [],
            lineMetadata: ["METRO:6": TestFixtures.lineMeta(sourceID: "METRO:6", shortName: "6", mode: .metro)],
            stationMetadata: ["bh-station": TestFixtures.stationMeta(name: "bir-hakeim")]
        )
        let result = GamificationEngine.computeStationAchievements(input: input, sortedTravels: [])
        #expect(result.firstBirHakeimLine6Date == TestFixtures.referenceDate)
    }

    @Test("Bir-Hakeim on line 9 does not match")
    func birHakeimWrongLine() {
        let stop = TestFixtures.stop(line: "METRO:9", station: "bh-station", at: TestFixtures.referenceDate)
        let input = GamificationInput(
            completedStops: [stop],
            travels: [],
            lineMetadata: ["METRO:9": TestFixtures.lineMeta(sourceID: "METRO:9", shortName: "9", mode: .metro)],
            stationMetadata: ["bh-station": TestFixtures.stationMeta(name: "Bir-Hakeim")]
        )
        let result = GamificationEngine.computeStationAchievements(input: input, sortedTravels: [])
        #expect(result.firstBirHakeimLine6Date == nil)
    }

    // MARK: - Opéra Night Travel

    @Test("Opéra at 23h triggers night achievement")
    func operaAt23h() {
        let travelDate = TestFixtures.date(daysOffset: 0, hour: 23)
        let travel = TravelRecord(
            lineSourceID: "METRO:3",
            createdAt: travelDate,
            fromStationSourceID: "opera",
            toStationSourceID: "other"
        )
        let input = GamificationInput(
            completedStops: [],
            travels: [travel],
            lineMetadata: ["METRO:3": TestFixtures.lineMeta(sourceID: "METRO:3", shortName: "3", mode: .metro)],
            stationMetadata: [
                "opera": TestFixtures.stationMeta(name: "Opéra"),
                "other": TestFixtures.stationMeta(name: "Havre-Caumartin"),
            ]
        )
        let result = GamificationEngine.computeStationAchievements(input: input, sortedTravels: [travel])
        #expect(result.firstOperaNightTravelDate == travelDate)
    }

    @Test("Opéra at 2h triggers night achievement")
    func operaAt2h() {
        let travelDate = TestFixtures.date(daysOffset: 0, hour: 2)
        let travel = TravelRecord(
            lineSourceID: "METRO:3",
            createdAt: travelDate,
            fromStationSourceID: "other",
            toStationSourceID: "opera"
        )
        let input = GamificationInput(
            completedStops: [],
            travels: [travel],
            lineMetadata: ["METRO:3": TestFixtures.lineMeta(sourceID: "METRO:3", shortName: "3", mode: .metro)],
            stationMetadata: [
                "opera": TestFixtures.stationMeta(name: "Opéra"),
                "other": TestFixtures.stationMeta(name: "Havre-Caumartin"),
            ]
        )
        let result = GamificationEngine.computeStationAchievements(input: input, sortedTravels: [travel])
        #expect(result.firstOperaNightTravelDate == travelDate)
    }

    @Test("Opéra at 22h does not trigger night achievement")
    func operaAt22h() {
        let travelDate = TestFixtures.date(daysOffset: 0, hour: 22)
        let travel = TravelRecord(
            lineSourceID: "METRO:3",
            createdAt: travelDate,
            fromStationSourceID: "opera",
            toStationSourceID: "other"
        )
        let input = GamificationInput(
            completedStops: [],
            travels: [travel],
            lineMetadata: ["METRO:3": TestFixtures.lineMeta(sourceID: "METRO:3", shortName: "3", mode: .metro)],
            stationMetadata: [
                "opera": TestFixtures.stationMeta(name: "Opéra"),
                "other": TestFixtures.stationMeta(name: "Havre-Caumartin"),
            ]
        )
        let result = GamificationEngine.computeStationAchievements(input: input, sortedTravels: [travel])
        #expect(result.firstOperaNightTravelDate == nil)
    }

    @Test("Opéra at 3h does not trigger night achievement")
    func operaAt3h() {
        let travelDate = TestFixtures.date(daysOffset: 0, hour: 3)
        let travel = TravelRecord(
            lineSourceID: "METRO:3",
            createdAt: travelDate,
            fromStationSourceID: "opera",
            toStationSourceID: "other"
        )
        let input = GamificationInput(
            completedStops: [],
            travels: [travel],
            lineMetadata: ["METRO:3": TestFixtures.lineMeta(sourceID: "METRO:3", shortName: "3", mode: .metro)],
            stationMetadata: [
                "opera": TestFixtures.stationMeta(name: "Opéra"),
                "other": TestFixtures.stationMeta(name: "Havre-Caumartin"),
            ]
        )
        let result = GamificationEngine.computeStationAchievements(input: input, sortedTravels: [travel])
        #expect(result.firstOperaNightTravelDate == nil)
    }

    // MARK: - Line 13 Rush Hour

    @Test("Line 13 at 8h triggers rush hour achievement")
    func line13At8h() {
        let travelDate = TestFixtures.date(daysOffset: 0, hour: 8)
        let travel = TravelRecord(
            lineSourceID: "METRO:13",
            createdAt: travelDate,
            fromStationSourceID: "from",
            toStationSourceID: "to"
        )
        let input = GamificationInput(
            completedStops: [],
            travels: [travel],
            lineMetadata: ["METRO:13": TestFixtures.lineMeta(sourceID: "METRO:13", shortName: "13", mode: .metro)],
            stationMetadata: [:]
        )
        let result = GamificationEngine.computeStationAchievements(input: input, sortedTravels: [travel])
        #expect(result.firstLine13RushHourDate == travelDate)
    }

    @Test("Line 13 at 9h does not trigger rush hour achievement")
    func line13At9h() {
        let travelDate = TestFixtures.date(daysOffset: 0, hour: 9)
        let travel = TravelRecord(
            lineSourceID: "METRO:13",
            createdAt: travelDate,
            fromStationSourceID: "from",
            toStationSourceID: "to"
        )
        let input = GamificationInput(
            completedStops: [],
            travels: [travel],
            lineMetadata: ["METRO:13": TestFixtures.lineMeta(sourceID: "METRO:13", shortName: "13", mode: .metro)],
            stationMetadata: [:]
        )
        let result = GamificationEngine.computeStationAchievements(input: input, sortedTravels: [travel])
        #expect(result.firstLine13RushHourDate == nil)
    }

    // MARK: - Department Coverage

    @Test("All 8 departments covered returns date of last department visited")
    func allDepartmentsCovered() {
        let departments = ["75", "77", "78", "91", "92", "93", "94", "95"]
        let stops = departments.enumerated().map { i, dept in
            TestFixtures.stop(line: "METRO:1", station: "station-\(dept)", at: TestFixtures.date(daysOffset: i))
        }
        var stationMeta: [String: StationMetadata] = [:]
        for dept in departments {
            stationMeta["station-\(dept)"] = TestFixtures.stationMeta(name: "Station \(dept)", postalCode: "\(dept)001")
        }
        let input = GamificationInput(
            completedStops: stops,
            travels: [],
            lineMetadata: ["METRO:1": TestFixtures.lineMeta()],
            stationMetadata: stationMeta
        )
        let result = GamificationEngine.computeStationAchievements(input: input, sortedTravels: [])
        // Last department visited is at daysOffset: 7 (index 7)
        #expect(result.allDepartmentsCoveredDate == TestFixtures.date(daysOffset: 7))
    }

    @Test("Missing one department returns nil")
    func missingOneDepartment() {
        // Only 7 of 8 departments
        let departments = ["75", "77", "78", "91", "92", "93", "94"]
        let stops = departments.enumerated().map { i, dept in
            TestFixtures.stop(line: "METRO:1", station: "station-\(dept)", at: TestFixtures.date(daysOffset: i))
        }
        var stationMeta: [String: StationMetadata] = [:]
        for dept in departments {
            stationMeta["station-\(dept)"] = TestFixtures.stationMeta(name: "Station \(dept)", postalCode: "\(dept)001")
        }
        let input = GamificationInput(
            completedStops: stops,
            travels: [],
            lineMetadata: ["METRO:1": TestFixtures.lineMeta()],
            stationMetadata: stationMeta
        )
        let result = GamificationEngine.computeStationAchievements(input: input, sortedTravels: [])
        #expect(result.allDepartmentsCoveredDate == nil)
    }

    // MARK: - Bus Line Discovery

    @Test("Bus line discovery dates are chronological first-use")
    func busLineDiscovery() {
        let travels = [
            TravelRecord(lineSourceID: "BUS:42", createdAt: TestFixtures.date(daysOffset: 0), fromStationSourceID: "a", toStationSourceID: "b"),
            TravelRecord(lineSourceID: "BUS:42", createdAt: TestFixtures.date(daysOffset: 1), fromStationSourceID: "a", toStationSourceID: "b"),
            TravelRecord(lineSourceID: "BUS:63", createdAt: TestFixtures.date(daysOffset: 2), fromStationSourceID: "c", toStationSourceID: "d"),
            TravelRecord(lineSourceID: "METRO:1", createdAt: TestFixtures.date(daysOffset: 3), fromStationSourceID: "e", toStationSourceID: "f"),
        ]
        let input = GamificationInput(
            completedStops: [],
            travels: travels,
            lineMetadata: [
                "BUS:42": TestFixtures.lineMeta(sourceID: "BUS:42", shortName: "42", mode: .bus),
                "BUS:63": TestFixtures.lineMeta(sourceID: "BUS:63", shortName: "63", mode: .bus),
                "METRO:1": TestFixtures.lineMeta(sourceID: "METRO:1", shortName: "1", mode: .metro),
            ],
            stationMetadata: [:]
        )
        let result = GamificationEngine.computeStationAchievements(input: input, sortedTravels: travels)
        #expect(result.nthUniqueBusLineDates.count == 2)
        #expect(result.nthUniqueBusLineDates[0] == TestFixtures.date(daysOffset: 0))
        #expect(result.nthUniqueBusLineDates[1] == TestFixtures.date(daysOffset: 2))
    }

    // MARK: - Network Half Date

    @Test("Network half date returns date when 50% reached")
    func networkHalfDate() {
        let stops = (0 ..< 10).map { i in
            TestFixtures.stop(line: "METRO:1", station: "station-\(i)", at: TestFixtures.date(daysOffset: i))
        }
        let result = GamificationEngine.computeNetworkHalfDate(stops: stops, totalNetworkStops: 20)
        // 10/20 = 50%, reached at the 10th stop (index 9, daysOffset 9)
        #expect(result == TestFixtures.date(daysOffset: 9))
    }
}
