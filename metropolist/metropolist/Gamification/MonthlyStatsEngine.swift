import SwiftUI

// MARK: - Monthly Stats Types

struct BadgeTierUp: Equatable {
    let lineSourceID: String
    let newTier: BadgeTier
}

struct MonthlySnapshot: Equatable {
    let month: DateComponents
    let travelCount: Int
    let uniqueStationsDiscovered: [String]
    let linesStarted: [String]
    let topLine: TopLine?
    let modeBreakdown: [TransitMode: Int]
    let bestStreak: Int
    let activeDays: Int
    let badgeTierUps: [BadgeTierUp]

    struct TopLine: Equatable {
        let sourceID: String
        let count: Int
    }
}

struct MonthContext: Equatable {
    let current: MonthlySnapshot
    let previous: MonthlySnapshot?
}

// MARK: - Engine

enum MonthlyStatsEngine {
    static func buildAllSnapshots(
        travels: [TravelRecord],
        completedStops: [CompletedStopRecord],
        lineMetadata: [String: LineMetadata]
    ) -> [MonthlySnapshot] {
        let cal = Calendar.current

        let travelsByMonth = Dictionary(grouping: travels) { travel in
            cal.dateComponents([.year, .month], from: travel.createdAt)
        }

        let stopsByMonth = Dictionary(grouping: completedStops) { stop in
            cal.dateComponents([.year, .month], from: stop.completedAt)
        }

        // Determine first-time discoveries globally (sorted by completedAt)
        let sortedStops = completedStops.sorted { $0.completedAt < $1.completedAt }
        var globalSeenStations: Set<String> = []
        var firstDiscoveryMonth: [String: DateComponents] = [:]
        for stop in sortedStops where globalSeenStations.insert(stop.stationSourceID).inserted {
            let month = cal.dateComponents([.year, .month], from: stop.completedAt)
            firstDiscoveryMonth[stop.stationSourceID] = month
        }

        // Determine first line started globally (first CompletedStop per line)
        var globalSeenLines: Set<String> = []
        var firstLineMonth: [String: DateComponents] = [:]
        for stop in sortedStops where globalSeenLines.insert(stop.lineSourceID).inserted {
            let month = cal.dateComponents([.year, .month], from: stop.completedAt)
            firstLineMonth[stop.lineSourceID] = month
        }

        // Collect all months that have at least one travel
        let allMonths = travelsByMonth.keys.sorted { lhs, rhs in
            guard let lhsYear = lhs.year, let rhsYear = rhs.year else { return false }
            if lhsYear != rhsYear {
                return lhsYear < rhsYear
            }
            guard let lhsMonth = lhs.month, let rhsMonth = rhs.month else { return false }
            return lhsMonth < rhsMonth
        }

        guard !allMonths.isEmpty else { return [] }

        // Build cumulative stop counts per line, walking months in order,
        // to compute badge tier transitions
        var cumulativeStopsByLine: [String: Set<String>] = [:]

        var snapshots: [MonthlySnapshot] = []

        for month in allMonths {
            let monthTravels = travelsByMonth[month] ?? []
            let monthStops = stopsByMonth[month] ?? []

            // Badge tiers BEFORE this month's stops
            let badgesBefore = computeBadgeTiers(
                cumulativeStopsByLine: cumulativeStopsByLine,
                lineMetadata: lineMetadata
            )

            // Add this month's stops to cumulative
            for stop in monthStops {
                cumulativeStopsByLine[stop.lineSourceID, default: []].insert(stop.stationSourceID)
            }

            // Badge tiers AFTER this month's stops
            let badgesAfter = computeBadgeTiers(
                cumulativeStopsByLine: cumulativeStopsByLine,
                lineMetadata: lineMetadata
            )

            let tierUps = computeTierUps(before: badgesBefore, after: badgesAfter)

            let discoveries = firstDiscoveryMonth
                .filter { $0.value == month }
                .map(\.key)

            let started = firstLineMonth
                .filter { $0.value == month }
                .map(\.key)

            let topLine = computeTopLine(travels: monthTravels)
            let modeBreakdown = computeModeBreakdown(travels: monthTravels, lineMetadata: lineMetadata)
            let bestStreak = computeBestStreak(travels: monthTravels, calendar: cal)
            let activeDays = computeActiveDays(travels: monthTravels, calendar: cal)

            snapshots.append(MonthlySnapshot(
                month: month,
                travelCount: monthTravels.count,
                uniqueStationsDiscovered: discoveries,
                linesStarted: started,
                topLine: topLine,
                modeBreakdown: modeBreakdown,
                bestStreak: bestStreak,
                activeDays: activeDays,
                badgeTierUps: tierUps
            ))
        }

        return snapshots
    }

    static func buildContext(
        for month: DateComponents,
        allSnapshots: [MonthlySnapshot]
    ) -> MonthContext? {
        guard let index = allSnapshots.firstIndex(where: { $0.month == month }) else {
            return nil
        }

        let current = allSnapshots[index]
        let previous: MonthlySnapshot? = index > 0 ? allSnapshots[index - 1] : nil

        return MonthContext(
            current: current,
            previous: previous
        )
    }

    // MARK: - Private Helpers

    private static func computeTopLine(travels: [TravelRecord]) -> MonthlySnapshot.TopLine? {
        guard !travels.isEmpty else { return nil }
        var counts: [String: Int] = [:]
        for travel in travels {
            counts[travel.lineSourceID, default: 0] += 1
        }
        guard let top = counts.max(by: { $0.value < $1.value }) else { return nil }
        return MonthlySnapshot.TopLine(sourceID: top.key, count: top.value)
    }

    private static func computeModeBreakdown(
        travels: [TravelRecord],
        lineMetadata: [String: LineMetadata]
    ) -> [TransitMode: Int] {
        var breakdown: [TransitMode: Int] = [:]
        for travel in travels {
            if let mode = lineMetadata[travel.lineSourceID]?.mode {
                breakdown[mode, default: 0] += 1
            }
        }
        return breakdown
    }

    private static func computeBestStreak(travels: [TravelRecord], calendar: Calendar) -> Int {
        guard !travels.isEmpty else { return 0 }

        var uniqueDays: Set<Date> = []
        for travel in travels {
            uniqueDays.insert(calendar.startOfDay(for: travel.createdAt))
        }

        let sortedDays = uniqueDays.sorted()
        guard !sortedDays.isEmpty else { return 0 }

        var best = 1
        var current = 1

        for index in 1 ..< sortedDays.count {
            let diff = calendar.dateComponents([.day], from: sortedDays[index - 1], to: sortedDays[index]).day ?? 0
            if diff == 1 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }

        return best
    }

    private static func computeActiveDays(travels: [TravelRecord], calendar: Calendar) -> Int {
        var days: Set<Date> = []
        for travel in travels {
            days.insert(calendar.startOfDay(for: travel.createdAt))
        }
        return days.count
    }

    private static func computeBadgeTiers(
        cumulativeStopsByLine: [String: Set<String>],
        lineMetadata: [String: LineMetadata]
    ) -> [String: BadgeTier] {
        var tiers: [String: BadgeTier] = [:]
        for (lineID, meta) in lineMetadata {
            let completed = cumulativeStopsByLine[lineID]?.count ?? 0
            tiers[lineID] = BadgeComputation.completionTier(completed: completed, total: meta.totalStations)
        }
        return tiers
    }

    private static func computeTierUps(
        before: [String: BadgeTier],
        after: [String: BadgeTier]
    ) -> [BadgeTierUp] {
        var tierUps: [BadgeTierUp] = []
        for (lineID, newTier) in after {
            let oldTier = before[lineID] ?? .locked
            if newTier > oldTier {
                tierUps.append(BadgeTierUp(lineSourceID: lineID, newTier: newTier))
            }
        }
        return tierUps.sorted { $0.lineSourceID < $1.lineSourceID }
    }
}

// MARK: - Month Formatting

enum MonthFormatting {
    private static let fullMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter
    }()

    private static let abbreviatedMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter
    }()

    static func fullMonth(_ month: DateComponents) -> String {
        var cal = Calendar.current
        cal.timeZone = .current
        guard let date = cal.date(from: month) else { return "" }
        return fullMonthFormatter.string(from: date)
    }

    static func abbreviatedMonth(_ month: DateComponents) -> String {
        var cal = Calendar.current
        cal.timeZone = .current
        guard let date = cal.date(from: month) else { return "" }
        return abbreviatedMonthFormatter.string(from: date)
    }
}
