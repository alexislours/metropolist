import Foundation

extension GamificationEngine {
    struct StationAchievementResults {
        var firstBirHakeimLine6Date: Date?
        var allDepartmentsCoveredDate: Date?
        var firstOperaNightTravelDate: Date?
        var firstLine13RushHourDate: Date?
        var nthUniqueBusLineDates: [Date]
        var firstChateauRougeDate: Date?
        var firstSameRouteTenTimesDate: Date?
        var firstT3aAndT3bDate: Date?
    }

    static func computeStationAchievements(
        input: GamificationInput,
        sortedStops: [CompletedStopRecord],
        sortedTravels: [TravelRecord]
    ) -> StationAchievementResults {
        var result = StationAchievementResults(nthUniqueBusLineDates: [])
        result.firstBirHakeimLine6Date = findBirHakeimLine6Date(sortedStops: sortedStops, input: input)
        computeTravelTimeAchievements(sortedTravels: sortedTravels, input: input, result: &result)
        result.allDepartmentsCoveredDate = computeDepartmentCoverage(sortedStops: sortedStops, input: input)
        result.nthUniqueBusLineDates = computeBusLineDiscoveryDates(sortedTravels: sortedTravels, input: input)
        result.firstChateauRougeDate = findChateauRougeDate(sortedStops: sortedStops, input: input)
        result.firstSameRouteTenTimesDate = computeSameRouteTenTimes(sortedTravels: sortedTravels)
        result.firstT3aAndT3bDate = computeT3aAndT3bDate(sortedTravels: sortedTravels, input: input)
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
        let requiredDepartments: Set = ["75", "77", "78", "91", "92", "93", "94", "95"]
        var departmentFirstDates: [String: Date] = [:]
        for stop in sortedStops {
            guard let postalCode = input.stationMetadata[stop.stationSourceID]?.postalCode,
                  postalCode.count >= 2 else { continue }
            let department = String(postalCode.prefix(2))
            guard requiredDepartments.contains(department) else { continue }
            if departmentFirstDates[department] == nil {
                departmentFirstDates[department] = stop.completedAt
                if departmentFirstDates.count == requiredDepartments.count {
                    break
                }
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

    // MARK: - Same Route 10 Times

    private static func computeSameRouteTenTimes(
        sortedTravels: [TravelRecord]
    ) -> Date? {
        var routeCounts: [String: Int] = [:]
        for travel in sortedTravels {
            let routeKey = "\(travel.fromStationSourceID)→\(travel.toStationSourceID)"
            routeCounts[routeKey, default: 0] += 1
            if routeCounts[routeKey] == 10 {
                return travel.createdAt
            }
        }
        return nil
    }

    // MARK: - T3a and T3b

    private static func computeT3aAndT3bDate(
        sortedTravels: [TravelRecord],
        input: GamificationInput
    ) -> Date? {
        var firstT3aDate: Date?
        var firstT3bDate: Date?
        for travel in sortedTravels {
            let shortName = input.lineMetadata[travel.lineSourceID]?.shortName ?? ""
            if firstT3aDate == nil, shortName == "T3a" {
                firstT3aDate = travel.createdAt
            }
            if firstT3bDate == nil, shortName == "T3b" {
                firstT3bDate = travel.createdAt
            }
            if let t3a = firstT3aDate, let t3b = firstT3bDate {
                return max(t3a, t3b)
            }
        }
        return nil
    }

    // MARK: - Network Half Date

    static func computeNetworkHalfDate(
        sortedStops: [CompletedStopRecord],
        totalNetworkStops: Int
    ) -> Date? {
        guard totalNetworkStops > 0 else { return nil }
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
        uniqueStationCount: Int,
        completedLineIDs: Set<String>,
        uniqueTravelDays: [Date]
    ) -> PlayerStats {
        let linesStarted = Set(input.travels.map(\.lineSourceID))
        let (longest, current) = computeStreaks(uniqueDays: uniqueTravelDays)

        return PlayerStats(
            totalTravels: input.travels.count,
            totalStationsVisited: uniqueStationCount,
            totalStationsInNetwork: input.stationMetadata.count,
            totalLinesStarted: linesStarted.count,
            totalLinesCompleted: completedLineIDs.count,
            currentStreak: current,
            longestStreak: longest,
            firstTravelDate: input.travels.last?.createdAt
        )
    }
}
