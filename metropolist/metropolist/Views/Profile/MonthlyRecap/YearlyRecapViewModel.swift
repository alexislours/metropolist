import SwiftUI
import TransitModels

@MainActor
@Observable
final class YearlyRecapViewModel {
    var isLoading = true
    var isEmpty = false
    var error: Error?

    var snapshot: YearlySnapshot?
    var previousYearSnapshot: YearlySnapshot?
    var accentColor: Color = .metroSignature
    var accentGradient: [Color] = [.metroSignature, .purple]
    var dominantMode: TransitMode?
    var formattedYear = ""
    var resolvedTopLine: ResolvedLine?
    var resolvedDiscoveries = ResolvedDiscoveries(newStations: [], newLines: [])
    var resolvedBadgeUpgrades: [ResolvedBadgeUpgrade] = []
    var resolvedMonthRankings: [(String, Int)] = []
    var resolvedBestMonth = ""
    var resolvedBusiestDay = ""
    var resolvedStreakRange = ""
    var resolvedMostLinesDay = ""
    var resolvedMostStationsDay = ""
    var resolvedMostDistanceDay = ""
    var mostDistanceDayMeters: Double = 0

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    private static let rangeFormatter: DateIntervalFormatter = {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private let year: Int
    private let dataStore: DataStore

    init(year: Int, dataStore: DataStore) {
        self.year = year
        self.dataStore = dataStore
        formattedYear = String(year)
    }

    func load() async {
        do {
            let travels = try dataStore.userService.allTravels()
            let completedStops = try dataStore.userService.allCompletedStops()
            let metaMap = try dataStore.allLineMetadata()
            let stationMeta = try dataStore.allStationMetadata()

            let travelRecords = travels.map {
                TravelRecord(
                    lineSourceID: $0.lineSourceID,
                    createdAt: $0.createdAt,
                    fromStationSourceID: $0.fromStationSourceID,
                    toStationSourceID: $0.toStationSourceID
                )
            }
            let stopRecords = completedStops.map {
                CompletedStopRecord(
                    lineSourceID: $0.lineSourceID,
                    stationSourceID: $0.stationSourceID,
                    completedAt: $0.completedAt
                )
            }

            let monthlySnapshots = MonthlyStatsEngine.buildAllSnapshots(
                travels: travelRecords,
                completedStops: stopRecords,
                lineMetadata: metaMap
            )

            let yearlySnapshots = YearlyStatsEngine.buildAllSnapshots(
                monthlySnapshots: monthlySnapshots,
                travels: travelRecords,
                completedStops: stopRecords
            )

            guard let yearSnap = yearlySnapshots.first(where: { $0.year == year }) else {
                isEmpty = true
                isLoading = false
                return
            }

            snapshot = yearSnap
            previousYearSnapshot = yearlySnapshots.first(where: { $0.year == year - 1 })

            let cal = Calendar.current
            let yearTravels = travels.filter { cal.component(.year, from: $0.createdAt) == year }
            computeMostDistanceDay(yearTravels: yearTravels)

            resolveDisplayData(yearSnap: yearSnap, metaMap: metaMap, stationMeta: stationMeta)
        } catch {
            self.error = error
        }
        isLoading = false
    }

    private func computeMostDistanceDay(yearTravels: [Travel]) {
        let cal = Calendar.current
        let travelsByDay = Dictionary(grouping: yearTravels) { cal.startOfDay(for: $0.createdAt) }
        var bestDay: Date = .now
        var bestDistance: Double = 0

        let transitIdentity = dataStore.transitDescriptor.cacheIdentity
        var distanceCache = DistanceCache.load(transitIdentity: transitIdentity)

        for (day, dayTravels) in travelsByDay {
            var dayDistance = 0.0
            for travel in dayTravels {
                let dist: Double? = switch distanceCache.lookup(travelID: travel.id) {
                case let .hit(cached):
                    cached
                case .miss:
                    {
                        let computed = try? DistanceCalculator.distance(
                            for: travel,
                            transitService: dataStore.transitService
                        )
                        distanceCache.set(distance: computed, forTravelID: travel.id)
                        return computed
                    }()
                }
                dayDistance += dist ?? 0
            }
            if dayDistance > bestDistance {
                bestDistance = dayDistance
                bestDay = day
            }
        }

        distanceCache.persistIfNeeded(transitIdentity: transitIdentity)

        if bestDistance > 0 {
            mostDistanceDayMeters = bestDistance
            resolvedMostDistanceDay = Self.dayFormatter.string(from: bestDay)
        }
    }

    private func resolveDisplayData(
        yearSnap: YearlySnapshot,
        metaMap: [String: LineMetadata],
        stationMeta: [String: StationMetadata]
    ) {
        // Top mode colors for gradient
        let topModes = yearSnap.modeBreakdown.sorted { $0.value > $1.value }.prefix(3)
        accentGradient = topModes.map(\.key.tintColor)
        dominantMode = topModes.first?.key
        accentColor = accentGradient.first ?? .metroSignature

        // Resolve top line
        if let topLine = yearSnap.topLine, let meta = metaMap[topLine.sourceID] {
            resolvedTopLine = ResolvedLine(
                shortName: meta.shortName,
                color: Color(hex: meta.color),
                travelCount: topLine.count
            )
        }

        // Resolve discoveries
        let newStations: [ResolvedStation] = yearSnap.totalDiscoveries.map { stationID in
            let name = stationMeta[stationID]?.name
                ?? String(localized: "Unknown station", comment: "Fallback name for unresolved station")
            return ResolvedStation(id: stationID, name: name)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        let newLines: [ResolvedNewLine] = yearSnap.totalNewLines.compactMap { lineID in
            guard let meta = metaMap[lineID] else { return nil }
            return ResolvedNewLine(
                sourceID: lineID,
                shortName: meta.shortName,
                color: Color(hex: meta.color),
                textColor: Color(hex: meta.textColor)
            )
        }.sorted { $0.shortName.localizedStandardCompare($1.shortName) == .orderedAscending }

        resolvedDiscoveries = ResolvedDiscoveries(newStations: newStations, newLines: newLines)

        // Resolve badge upgrades
        resolvedBadgeUpgrades = yearSnap.totalBadgeTierUps.compactMap { tierUp in
            guard let meta = metaMap[tierUp.lineSourceID] else { return nil }
            return ResolvedBadgeUpgrade(
                lineSourceID: tierUp.lineSourceID,
                shortName: meta.shortName,
                lineColor: Color(hex: meta.color),
                lineTextColor: Color(hex: meta.textColor),
                newTier: tierUp.newTier
            )
        }

        // Month rankings
        resolvedMonthRankings = yearSnap.monthRankings.map { month, count in
            (MonthFormatting.fullMonth(month), count)
        }

        // Best month
        resolvedBestMonth = MonthFormatting.fullMonth(yearSnap.bestMonth)

        // Busiest day & other day-based superlatives
        resolvedBusiestDay = Self.dayFormatter.string(from: yearSnap.busiestDay.0)
        resolvedMostLinesDay = Self.dayFormatter.string(from: yearSnap.mostLinesInADay.0)
        resolvedMostStationsDay = Self.dayFormatter.string(from: yearSnap.mostStationsInADay.0)

        // Streak range
        let cal = Calendar.current
        let streakStart = yearSnap.longestStreak.start
        let streakEnd = cal.date(
            byAdding: .day,
            value: yearSnap.longestStreak.length - 1,
            to: streakStart
        ) ?? streakStart
        resolvedStreakRange = Self.rangeFormatter.string(from: streakStart, to: streakEnd)
    }
}
