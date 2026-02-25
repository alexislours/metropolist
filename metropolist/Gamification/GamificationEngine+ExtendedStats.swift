import Foundation

extension GamificationEngine {
    static func computeExtendedStats(from input: GamificationInput) -> ExtendedStats {
        ExtendedStats(
            travelsPerWeek: computeTravelsPerWeek(travels: input.travels),
            busiestDayOfWeek: computeBusiestDayOfWeek(travels: input.travels),
            busiestHourOfDay: computeBusiestHourOfDay(travels: input.travels),
            topStations: computeTopStations(
                completedStops: input.completedStops,
                stationMetadata: input.stationMetadata,
                limit: 5
            ),
            topLines: computeTopLines(
                travels: input.travels,
                lineMetadata: input.lineMetadata,
                limit: 5
            ),
            departmentCoverage: computeDepartmentBreakdown(
                completedStops: input.completedStops,
                stationMetadata: input.stationMetadata
            ),
            fareZoneCoverage: computeFareZoneBreakdown(
                completedStops: input.completedStops,
                stationMetadata: input.stationMetadata
            )
        )
    }

    // MARK: - Travels Per Week

    private static func computeTravelsPerWeek(travels: [TravelRecord]) -> [WeeklyTravelCount] {
        guard !travels.isEmpty else { return [] }
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday

        var weekCounts: [Date: Int] = [:]
        for travel in travels {
            let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: travel.createdAt)
            if let weekStart = cal.date(from: components) {
                weekCounts[weekStart, default: 0] += 1
            }
        }

        let sortedWeeks = weekCounts.keys.sorted()
        guard let first = sortedWeeks.first, let last = sortedWeeks.last else { return [] }

        // Limit to last 12 weeks for chart readability
        let twelveWeeksAgo = cal.date(byAdding: .weekOfYear, value: -12, to: last) ?? first
        let cutoff = max(first, twelveWeeksAgo)

        var results: [WeeklyTravelCount] = []
        var current = cutoff

        while current <= last {
            let count = weekCounts[current] ?? 0
            results.append(WeeklyTravelCount(id: current, count: count))
            guard let next = cal.date(byAdding: .weekOfYear, value: 1, to: current) else { break }
            current = next
        }

        return results
    }

    // MARK: - Busiest Day of Week

    private static func computeBusiestDayOfWeek(travels: [TravelRecord]) -> DayOfWeekStat? {
        guard !travels.isEmpty else { return nil }
        let cal = Calendar.current
        var counts: [Int: Int] = [:]

        for travel in travels {
            let weekday = cal.component(.weekday, from: travel.createdAt)
            counts[weekday, default: 0] += 1
        }

        let daySymbols = cal.weekdaySymbols
        let allDays = (1 ... 7).map { day in
            DayOfWeekStat.DayCount(dayIndex: day, dayName: daySymbols[day - 1], count: counts[day] ?? 0)
        }

        guard let best = allDays.max(by: { $0.count < $1.count }) else { return nil }
        return DayOfWeekStat(
            dayIndex: best.dayIndex,
            dayName: best.dayName,
            allDays: allDays
        )
    }

    // MARK: - Busiest Hour of Day

    private static func computeBusiestHourOfDay(travels: [TravelRecord]) -> HourOfDayStat? {
        guard !travels.isEmpty else { return nil }
        let cal = Calendar.current
        var counts: [Int: Int] = [:]

        for travel in travels {
            let hour = cal.component(.hour, from: travel.createdAt)
            counts[hour, default: 0] += 1
        }

        let allHours = (0 ..< 24).map { hour in
            HourOfDayStat.HourCount(hour: hour, count: counts[hour] ?? 0)
        }

        guard let best = allHours.max(by: { $0.count < $1.count }) else { return nil }
        return HourOfDayStat(hour: best.hour, allHours: allHours)
    }

    // MARK: - Top Stations

    private static func computeTopStations(
        completedStops: [CompletedStopRecord],
        stationMetadata: [String: StationMetadata],
        limit: Int
    ) -> [RankedStation] {
        var counts: [String: Int] = [:]
        for stop in completedStops {
            counts[stop.stationSourceID, default: 0] += 1
        }

        return counts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { stationID, count in
                RankedStation(
                    stationSourceID: stationID,
                    name: stationMetadata[stationID]?.name ?? stationID,
                    visitCount: count
                )
            }
    }

    // MARK: - Top Lines

    private static func computeTopLines(
        travels: [TravelRecord],
        lineMetadata: [String: LineMetadata],
        limit: Int
    ) -> [RankedLine] {
        var counts: [String: Int] = [:]
        for travel in travels {
            counts[travel.lineSourceID, default: 0] += 1
        }

        return counts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .compactMap { lineID, count in
                guard let meta = lineMetadata[lineID] else { return nil }
                return RankedLine(
                    lineSourceID: lineID,
                    shortName: meta.shortName,
                    mode: meta.mode,
                    color: meta.color,
                    textColor: meta.textColor,
                    travelCount: count
                )
            }
    }

    // MARK: - Department Coverage Breakdown

    private static let departmentNames: [String: String] = [
        "75": "Paris",
        "77": "Seine-et-Marne",
        "78": "Yvelines",
        "91": "Essonne",
        "92": "Hauts-de-Seine",
        "93": "Seine-Saint-Denis",
        "94": "Val-de-Marne",
        "95": "Val-d'Oise",
    ]

    private static func computeDepartmentBreakdown(
        completedStops: [CompletedStopRecord],
        stationMetadata: [String: StationMetadata]
    ) -> [DepartmentCoverage] {
        let requiredDepartments = ["75", "77", "78", "91", "92", "93", "94", "95"]

        // Count total stations per department (from all known stations)
        var totalByDept: [String: Set<String>] = [:]
        for (stationID, meta) in stationMetadata {
            guard let postalCode = meta.postalCode, postalCode.count >= 2 else { continue }
            let dept = String(postalCode.prefix(2))
            guard requiredDepartments.contains(dept) else { continue }
            totalByDept[dept, default: []].insert(stationID)
        }

        // Count visited stations per department
        let visitedStationIDs = Set(completedStops.map(\.stationSourceID))
        var visitedByDept: [String: Int] = [:]
        for dept in requiredDepartments {
            let deptStations = totalByDept[dept] ?? []
            visitedByDept[dept] = deptStations.intersection(visitedStationIDs).count
        }

        return requiredDepartments.map { dept in
            DepartmentCoverage(
                department: dept,
                label: "\(departmentNames[dept] ?? dept) (\(dept))",
                visited: visitedByDept[dept] ?? 0,
                total: totalByDept[dept]?.count ?? 0
            )
        }
    }

    // MARK: - Fare Zone Coverage Breakdown

    private static func computeFareZoneBreakdown(
        completedStops: [CompletedStopRecord],
        stationMetadata: [String: StationMetadata]
    ) -> [FareZoneCoverage] {
        let zones = ["1", "2", "3", "4", "5"]

        // Count total stations per fare zone
        var totalByZone: [String: Set<String>] = [:]
        for (stationID, meta) in stationMetadata {
            guard let fareZone = meta.fareZone else { continue }
            totalByZone[fareZone, default: []].insert(stationID)
        }

        // Count visited stations per fare zone
        let visitedStationIDs = Set(completedStops.map(\.stationSourceID))
        var visitedByZone: [String: Int] = [:]
        for zone in zones {
            let zoneStations = totalByZone[zone] ?? []
            visitedByZone[zone] = zoneStations.intersection(visitedStationIDs).count
        }

        return zones.compactMap { zone in
            let total = totalByZone[zone]?.count ?? 0
            guard total > 0 else { return nil }
            return FareZoneCoverage(
                zone: zone,
                visited: visitedByZone[zone] ?? 0,
                total: total
            )
        }
    }
}
