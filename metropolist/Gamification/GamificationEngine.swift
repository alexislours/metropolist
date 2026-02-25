import Foundation

enum GamificationEngine {
    // MARK: - XP Constants

    private static let xpPerTravel = 5
    private static let xpPerUniqueStop = 20
    private static let xpPerFirstLineBus = 25
    private static let xpPerFirstLineOther = 50
    private static let xpBaseLineCompletion = 50
    private static let xpPerLineCompletionStop = 5

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: - Main Entry Point

    static func computeSnapshot(from input: GamificationInput) -> GamificationSnapshot {
        let completedByLine = Dictionary(grouping: input.completedStops, by: \.lineSourceID)
        let linesByMode = Dictionary(grouping: input.lineMetadata.values, by: \.mode)

        let (lineProgress, completedLineIDs) = computeLineProgress(
            lineMetadata: input.lineMetadata,
            completedByLine: completedByLine
        )

        let lineBadges = lineProgress.mapValues(\.badge)

        let modeBadges = computeModeBadges(
            linesByMode: linesByMode,
            completedByLine: completedByLine
        )

        let uniqueTravelDays: [Date] = {
            let cal = Calendar.current
            var seen = Set<Date>()
            var result: [Date] = []
            for travel in input.travels {
                let day = cal.startOfDay(for: travel.createdAt)
                if seen.insert(day).inserted { result.append(day) }
            }
            result.sort()
            return result
        }()

        let uniqueStations = Set(input.completedStops.map(\.stationSourceID))

        let firstLineXP = computeFirstLineXP(
            travels: input.travels,
            lineMetadata: input.lineMetadata
        )

        let lineCompletionXP = computeLineCompletionXP(
            completedLineIDs: completedLineIDs,
            lineMetadata: input.lineMetadata
        )

        let streakXP = computeStreakXP(uniqueDays: uniqueTravelDays)

        let stats = computeStats(
            input: input,
            completedByLine: completedByLine,
            completedLineIDs: completedLineIDs,
            uniqueTravelDays: uniqueTravelDays
        )

        let achievementCtx = buildAchievementContext(
            input: input,
            linesByMode: linesByMode,
            completedByLine: completedByLine,
            uniqueTravelDays: uniqueTravelDays
        )

        let achievements = AchievementDefinitions.all.map { def in
            let date = def.evaluate(achievementCtx)
            return AchievementState(
                id: def.id,
                definition: def,
                isUnlocked: date != nil,
                unlockedAt: date
            )
        }

        let achievementXP = computeAchievementXP(achievements: achievements)

        let xpBreakdown = XPBreakdown(
            travelXP: input.travels.count * xpPerTravel,
            stopXP: uniqueStations.count * xpPerUniqueStop,
            lineCompletionXP: lineCompletionXP,
            firstLineXP: firstLineXP,
            achievementXP: achievementXP,
            streakXP: streakXP
        )

        let extendedStats = computeExtendedStats(from: input)

        let totalXP = xpBreakdown.total
        let level = LevelDefinitions.level(forXP: totalXP)
        let xpInCurrent = LevelDefinitions.xpInCurrentLevel(totalXP: totalXP)
        let xpToNext = LevelDefinitions.xpToNextLevel(totalXP: totalXP)

        return GamificationSnapshot(
            totalXP: totalXP,
            level: level,
            xpInCurrentLevel: xpInCurrent,
            xpToNextLevel: xpToNext,
            lineBadges: lineBadges,
            modeBadges: modeBadges,
            achievements: achievements,
            stats: stats,
            lineProgress: lineProgress,
            xpBreakdown: xpBreakdown,
            extendedStats: extendedStats
        )
    }

    // MARK: - Line Progress

    private static func computeLineProgress(
        lineMetadata: [String: LineMetadata],
        completedByLine: [String: [CompletedStopRecord]]
    ) -> ([String: LineProgress], Set<String>) {
        var lineProgress: [String: LineProgress] = [:]
        var completedLineIDs: Set<String> = []
        for (sourceID, meta) in lineMetadata {
            let completed = completedByLine[sourceID]?.count ?? 0
            let fraction = meta.totalStations > 0 ? Double(completed) / Double(meta.totalStations) : 0
            let badge = BadgeComputation.completionTier(completed: completed, total: meta.totalStations)
            lineProgress[sourceID] = LineProgress(
                completedStops: completed,
                totalStops: meta.totalStations,
                badge: badge,
                fraction: fraction
            )
            if completed >= meta.totalStations, meta.totalStations > 0 {
                completedLineIDs.insert(sourceID)
            }
        }
        return (lineProgress, completedLineIDs)
    }

    // MARK: - Mode Badges

    private static func computeModeBadges(
        linesByMode: [TransitMode: [LineMetadata]],
        completedByLine: [String: [CompletedStopRecord]]
    ) -> [TransitMode: BadgeTier] {
        var modeBadges: [TransitMode: BadgeTier] = [:]
        for (mode, lines) in linesByMode {
            var totalStops = 0
            var completedStops = 0
            for line in lines {
                totalStops += line.totalStations
                completedStops += completedByLine[line.sourceID]?.count ?? 0
            }
            modeBadges[mode] = BadgeComputation.completionTier(completed: completedStops, total: totalStops)
        }
        return modeBadges
    }

    // MARK: - XP Computation

    private static func computeFirstLineXP(
        travels: [TravelRecord],
        lineMetadata: [String: LineMetadata]
    ) -> Int {
        var seenLines: Set<String> = []
        var total = 0
        for travel in travels {
            guard seenLines.insert(travel.lineSourceID).inserted else { continue }
            let isBus = lineMetadata[travel.lineSourceID]?.mode == .bus
            total += isBus ? xpPerFirstLineBus : xpPerFirstLineOther
        }
        return total
    }

    private static func computeLineCompletionXP(
        completedLineIDs: Set<String>,
        lineMetadata: [String: LineMetadata]
    ) -> Int {
        var total = 0
        for lineID in completedLineIDs {
            let totalStations = lineMetadata[lineID]?.totalStations ?? 0
            total += xpBaseLineCompletion + (totalStations * xpPerLineCompletionStop)
        }
        return total
    }

    private static func computeAchievementXP(achievements: [AchievementState]) -> Int {
        achievements
            .filter(\.isUnlocked)
            .reduce(0) { $0 + $1.definition.xpReward }
    }

    // MARK: - Achievement Context

    private static func buildAchievementContext(
        input: GamificationInput,
        linesByMode: [TransitMode: [LineMetadata]],
        completedByLine: [String: [CompletedStopRecord]],
        uniqueTravelDays: [Date]
    ) -> AchievementContext {
        let sortedTravels = input.travels.sorted { $0.createdAt < $1.createdAt }
        let sortedTravelDates = sortedTravels.map(\.createdAt)
        let totalNetworkStops = input.lineMetadata.values.reduce(0) { $0 + $1.totalStations }
        let modesUsed: Set<TransitMode> = Set(input.travels.compactMap { travel in
            input.lineMetadata[travel.lineSourceID]?.mode
        })
        let uniqueDates = computeUniqueDates(
            stops: input.completedStops,
            travels: sortedTravels
        )
        let lineCompletionDates = computeLineCompletionDates(
            lineMetadata: input.lineMetadata,
            completedByLine: completedByLine
        )
        let modeCompletionDates = computeModeCompletionDates(
            linesByMode: linesByMode,
            lineCompletionDates: lineCompletionDates
        )
        let travelMilestones = computeTravelMilestones(
            sortedTravels: sortedTravels,
            lineMetadata: input.lineMetadata
        )
        let streakMilestoneDates = computeStreakMilestones(uniqueDays: uniqueTravelDays, targets: [7, 30])
        let networkHalfDate = computeNetworkHalfDate(
            stops: input.completedStops,
            totalNetworkStops: totalNetworkStops
        )
        let linesByModeIDs: [TransitMode: Set<String>] = linesByMode.mapValues { lines in
            Set(lines.map(\.sourceID))
        }

        let stationAchievements = computeStationAchievements(
            input: input,
            sortedTravels: sortedTravels
        )

        let rerCCompletionDate: Date? = {
            guard let rerCID = input.lineMetadata.first(where: { $0.value.mode == .rer && $0.value.shortName == "C" })?.key else {
                return nil
            }
            return lineCompletionDates[rerCID]
        }()

        return AchievementContext(
            totalTravels: input.travels.count,
            modesUsed: modesUsed,
            linesByMode: linesByModeIDs,
            travelDates: input.travels.map(\.createdAt),
            firstTravelDate: sortedTravels.first?.createdAt,
            nthUniqueStationDates: uniqueDates.stationDates,
            nthUniqueLineDates: uniqueDates.lineDates,
            sortedTravelDates: sortedTravelDates,
            sortedLineCompletionDates: lineCompletionDates.values.sorted(),
            modeCompletionDates: modeCompletionDates,
            modeFirstUsedDates: travelMilestones.modeFirstUsedDates,
            firstMultiModeDayDate: travelMilestones.firstMultiModeDayDate,
            firstNoctilienDate: travelMilestones.firstNoctilienDate,
            streakMilestoneDates: streakMilestoneDates,
            networkHalfDate: networkHalfDate,
            firstBirHakeimLine6Date: stationAchievements.firstBirHakeimLine6Date,
            allDepartmentsCoveredDate: stationAchievements.allDepartmentsCoveredDate,
            firstOperaNightTravelDate: stationAchievements.firstOperaNightTravelDate,
            firstLine13RushHourDate: stationAchievements.firstLine13RushHourDate,
            nthUniqueBusLineDates: stationAchievements.nthUniqueBusLineDates,
            rerCCompletionDate: rerCCompletionDate,
            firstChateauRougeDate: stationAchievements.firstChateauRougeDate
        )
    }

    private static func computeUniqueDates(
        stops: [CompletedStopRecord],
        travels: [TravelRecord]
    ) -> (stationDates: [Date], lineDates: [Date]) {
        let sortedStops = stops.sorted { $0.completedAt < $1.completedAt }

        var seenStations: Set<String> = []
        var stationDates: [Date] = []
        for stop in sortedStops where seenStations.insert(stop.stationSourceID).inserted {
            stationDates.append(stop.completedAt)
        }

        var seenLines: Set<String> = []
        var lineDates: [Date] = []
        for travel in travels where seenLines.insert(travel.lineSourceID).inserted {
            lineDates.append(travel.createdAt)
        }

        return (stationDates, lineDates)
    }

    private static func computeLineCompletionDates(
        lineMetadata: [String: LineMetadata],
        completedByLine: [String: [CompletedStopRecord]]
    ) -> [String: Date] {
        var lineCompletionDates: [String: Date] = [:]
        for (sourceID, meta) in lineMetadata {
            guard meta.totalStations > 0 else { continue }
            let stops = (completedByLine[sourceID] ?? []).sorted { $0.completedAt < $1.completedAt }
            var uniqueInLine: Set<String> = []
            for stop in stops {
                uniqueInLine.insert(stop.stationSourceID)
                if uniqueInLine.count >= meta.totalStations {
                    lineCompletionDates[sourceID] = stop.completedAt
                    break
                }
            }
        }
        return lineCompletionDates
    }

    private static func computeModeCompletionDates(
        linesByMode: [TransitMode: [LineMetadata]],
        lineCompletionDates: [String: Date]
    ) -> [TransitMode: Date] {
        var modeCompletionDates: [TransitMode: Date] = [:]
        for (mode, lines) in linesByMode {
            let allIDs = Set(lines.map(\.sourceID))
            guard !allIDs.isEmpty, allIDs.allSatisfy({ lineCompletionDates[$0] != nil }) else { continue }
            modeCompletionDates[mode] = allIDs.compactMap { lineCompletionDates[$0] }.max()
        }
        return modeCompletionDates
    }

    private struct TravelMilestones {
        var modeFirstUsedDates: [TransitMode: Date]
        var firstMultiModeDayDate: Date?
        var firstNoctilienDate: Date?
    }

    private static func computeTravelMilestones(
        sortedTravels: [TravelRecord],
        lineMetadata: [String: LineMetadata]
    ) -> TravelMilestones {
        var modeFirstUsedDates: [TransitMode: Date] = [:]
        var firstMultiModeDayDate: Date?
        var dayModeTracking: [String: Set<TransitMode>] = [:]
        var firstNoctilienDate: Date?

        for travel in sortedTravels {
            if let mode = lineMetadata[travel.lineSourceID]?.mode {
                if modeFirstUsedDates[mode] == nil {
                    modeFirstUsedDates[mode] = travel.createdAt
                }
                let day = Self.dayFormatter.string(from: travel.createdAt)
                dayModeTracking[day, default: []].insert(mode)
                if (dayModeTracking[day]?.count ?? 0) >= 3, firstMultiModeDayDate == nil {
                    firstMultiModeDayDate = travel.createdAt
                }
            }
            if firstNoctilienDate == nil {
                if lineMetadata[travel.lineSourceID]?.submode == "nightBus" {
                    firstNoctilienDate = travel.createdAt
                }
            }
        }

        return TravelMilestones(
            modeFirstUsedDates: modeFirstUsedDates,
            firstMultiModeDayDate: firstMultiModeDayDate,
            firstNoctilienDate: firstNoctilienDate
        )
    }
}
