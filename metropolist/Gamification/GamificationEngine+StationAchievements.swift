import Foundation

extension GamificationEngine {
    struct StationAchievementResults {
        var firstBirHakeimLine6Date: Date?
        var allDepartmentsCoveredDate: Date?
        var firstOperaNightTravelDate: Date?
        var firstLine13RushHourDate: Date?
        var nthUniqueBusLineDates: [Date]
        var firstChateauRougeDate: Date?
    }

    static func computeStationAchievements(
        input: GamificationInput,
        sortedTravels: [TravelRecord]
    ) -> StationAchievementResults {
        let sortedStops = input.completedStops.sorted { $0.completedAt < $1.completedAt }

        var result = StationAchievementResults(nthUniqueBusLineDates: [])
        result.firstBirHakeimLine6Date = findBirHakeimLine6Date(sortedStops: sortedStops, input: input)
        computeTravelTimeAchievements(sortedTravels: sortedTravels, input: input, result: &result)
        result.allDepartmentsCoveredDate = computeDepartmentCoverage(sortedStops: sortedStops, input: input)
        result.nthUniqueBusLineDates = computeBusLineDiscoveryDates(sortedTravels: sortedTravels, input: input)
        result.firstChateauRougeDate = findChateauRougeDate(sortedStops: sortedStops, input: input)
        return result
    }

    // MARK: - Bir-Hakeim on Line 6

    private static func findBirHakeimLine6Date(
        sortedStops: [CompletedStopRecord],
        input: GamificationInput
    ) -> Date? {
        for stop in sortedStops {
            let stationName = input.stationMetadata[stop.stationSourceID]?.name ?? ""
            let lineShortName = input.lineMetadata[stop.lineSourceID]?.shortName ?? ""
            if stationName.localizedCaseInsensitiveContains("Bir-Hakeim"), lineShortName == "6" {
                return stop.completedAt
            }
        }
        return nil
    }

    // MARK: - Time-Based Travel Achievements

    private static func computeTravelTimeAchievements(
        sortedTravels: [TravelRecord],
        input: GamificationInput,
        result: inout StationAchievementResults
    ) {
        let cal = Calendar.current
        for travel in sortedTravels {
            let hour = cal.component(.hour, from: travel.createdAt)

            if result.firstOperaNightTravelDate == nil,
               hour >= 23 || hour < 3 {
                let fromName = input.stationMetadata[travel.fromStationSourceID]?.name ?? ""
                let toName = input.stationMetadata[travel.toStationSourceID]?.name ?? ""
                if fromName.localizedCaseInsensitiveContains("Opéra")
                    || toName.localizedCaseInsensitiveContains("Opéra") {
                    result.firstOperaNightTravelDate = travel.createdAt
                }
            }

            if result.firstLine13RushHourDate == nil,
               hour == 8 {
                let lineShortName = input.lineMetadata[travel.lineSourceID]?.shortName ?? ""
                if lineShortName == "13" {
                    result.firstLine13RushHourDate = travel.createdAt
                }
            }
        }
    }

    // MARK: - Department Coverage

    private static func computeDepartmentCoverage(
        sortedStops: [CompletedStopRecord],
        input: GamificationInput
    ) -> Date? {
        let requiredDepartments: Set<String> = ["75", "77", "78", "91", "92", "93", "94", "95"]
        var departmentFirstDates: [String: Date] = [:]
        for stop in sortedStops {
            guard let postalCode = input.stationMetadata[stop.stationSourceID]?.postalCode,
                  postalCode.count >= 2 else { continue }
            let department = String(postalCode.prefix(2))
            guard requiredDepartments.contains(department) else { continue }
            if departmentFirstDates[department] == nil {
                departmentFirstDates[department] = stop.completedAt
            }
        }
        guard requiredDepartments.allSatisfy({ departmentFirstDates[$0] != nil }) else { return nil }
        return departmentFirstDates.values.max()
    }

    // MARK: - Bus Line Discovery

    private static func computeBusLineDiscoveryDates(
        sortedTravels: [TravelRecord],
        input: GamificationInput
    ) -> [Date] {
        var seenBusLines: Set<String> = []
        var dates: [Date] = []
        for travel in sortedTravels {
            guard input.lineMetadata[travel.lineSourceID]?.mode == .bus else { continue }
            if seenBusLines.insert(travel.lineSourceID).inserted {
                dates.append(travel.createdAt)
            }
        }
        return dates
    }

    // MARK: - Château Rouge

    private static func findChateauRougeDate(
        sortedStops: [CompletedStopRecord],
        input: GamificationInput
    ) -> Date? {
        for stop in sortedStops {
            let stationName = input.stationMetadata[stop.stationSourceID]?.name ?? ""
            if stationName.localizedCaseInsensitiveContains("Château Rouge") {
                return stop.completedAt
            }
        }
        return nil
    }

    // MARK: - Network Half Date

    static func computeNetworkHalfDate(
        stops: [CompletedStopRecord],
        totalNetworkStops: Int
    ) -> Date? {
        guard totalNetworkStops > 0 else { return nil }
        let sortedStops = stops.sorted { $0.completedAt < $1.completedAt }
        var count = 0
        for stop in sortedStops {
            count += 1
            if Double(count) / Double(totalNetworkStops) >= 0.5 {
                return stop.completedAt
            }
        }
        return nil
    }

    // MARK: - Stats Computation

    static func computeStats(
        input: GamificationInput,
        completedByLine _: [String: [CompletedStopRecord]],
        completedLineIDs: Set<String>,
        uniqueTravelDays: [Date]
    ) -> PlayerStats {
        let uniqueStations = Set(input.completedStops.map(\.stationSourceID))
        let linesStarted = Set(input.travels.map(\.lineSourceID))
        let (_, current) = computeStreaks(uniqueDays: uniqueTravelDays)

        return PlayerStats(
            totalTravels: input.travels.count,
            totalStationsVisited: uniqueStations.count,
            totalLinesStarted: linesStarted.count,
            totalLinesCompleted: completedLineIDs.count,
            currentStreak: current,
            firstTravelDate: input.travels.last?.createdAt
        )
    }
}
