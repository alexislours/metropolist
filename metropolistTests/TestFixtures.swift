import Foundation
@testable import metropolist

enum TestFixtures {
    // MARK: - Reference Dates

    /// Fixed reference date: 2025-01-15 10:00:00 UTC
    static let referenceDate: Date = {
        var comps = DateComponents()
        comps.year = 2025
        comps.month = 1
        comps.day = 15
        comps.hour = 10
        comps.minute = 0
        comps.second = 0
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar.current.date(from: comps)!
    }()

    /// Returns a date offset by `days` from `referenceDate`.
    static func date(daysOffset days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: referenceDate)!
    }

    // MARK: - Record Builders

    static func stop(
        line: String = "METRO:1",
        station: String = "station-A",
        at date: Date? = nil
    ) -> CompletedStopRecord {
        CompletedStopRecord(
            lineSourceID: line,
            stationSourceID: station,
            completedAt: date ?? referenceDate
        )
    }

    static func travel(
        line: String = "METRO:1",
        from: String = "station-A",
        to: String = "station-B",
        at date: Date? = nil
    ) -> TravelRecord {
        TravelRecord(
            lineSourceID: line,
            createdAt: date ?? referenceDate,
            fromStationSourceID: from,
            toStationSourceID: to
        )
    }

    static func lineMeta(
        sourceID: String = "METRO:1",
        shortName: String = "1",
        longName: String = "Ligne 1",
        mode: TransitMode = .metro,
        totalStations: Int = 25
    ) -> LineMetadata {
        LineMetadata(
            sourceID: sourceID,
            shortName: shortName,
            longName: longName,
            mode: mode,
            submode: nil,
            color: "#FFCD00",
            textColor: "#000000",
            totalStations: totalStations
        )
    }

    // MARK: - Composite Helpers

    /// Creates a `GamificationInput` with `count` unique stops on a single line
    /// and one travel, with `totalStations` as the line's total.
    static func inputWithStops(
        count: Int,
        totalStations: Int = 25,
        line: String = "METRO:1",
        mode: TransitMode = .metro
    ) -> GamificationInput {
        let stops = (0 ..< count).map { i in
            stop(line: line, station: "station-\(i)", at: date(daysOffset: i))
        }
        let travels = count > 0 ? [travel(line: line, at: referenceDate)] : []
        let meta = lineMeta(sourceID: line, shortName: "1", mode: mode, totalStations: totalStations)
        return GamificationInput(
            completedStops: stops,
            travels: travels,
            lineMetadata: [line: meta],
            stationMetadata: [:]
        )
    }

    /// Creates an array of dates representing `count` consecutive days starting from `referenceDate`.
    static func consecutiveDays(count: Int) -> [Date] {
        (0 ..< count).map { date(daysOffset: $0) }
    }

    /// Returns a date at a specific hour on a given day offset.
    /// Uses the current calendar's timezone so that `Calendar.current.component(.hour, from:)`
    /// returns the expected hour value (production code uses Calendar.current).
    static func date(daysOffset days: Int, hour: Int, minute: Int = 0) -> Date {
        var cal = Calendar.current
        cal.timeZone = cal.timeZone
        var comps = DateComponents()
        comps.year = 2025
        comps.month = 1
        comps.day = 15 + days
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return cal.date(from: comps)!
    }

    // MARK: - Station Metadata Builder

    static func stationMeta(
        name: String = "Station A",
        postalCode: String? = "75001",
        fareZone: String? = "1"
    ) -> StationMetadata {
        StationMetadata(name: name, postalCode: postalCode, fareZone: fareZone)
    }

    // MARK: - Achievement Context Builder

    static func achievementContext(
        totalTravels: Int = 0,
        modesUsed: Set<TransitMode> = [],
        linesByMode: [TransitMode: Set<String>] = [:],
        travelDates: [Date] = [],
        firstTravelDate: Date? = nil,
        nthUniqueStationDates: [Date] = [],
        nthUniqueLineDates: [Date] = [],
        sortedTravelDates: [Date] = [],
        sortedLineCompletionDates: [Date] = [],
        modeCompletionDates: [TransitMode: Date] = [:],
        modeFirstUsedDates: [TransitMode: Date] = [:],
        firstMultiModeDayDate: Date? = nil,
        firstNoctilienDate: Date? = nil,
        streakMilestoneDates: [Int: Date] = [:],
        networkHalfDate: Date? = nil,
        firstBirHakeimLine6Date: Date? = nil,
        allDepartmentsCoveredDate: Date? = nil,
        firstOperaNightTravelDate: Date? = nil,
        firstLine13RushHourDate: Date? = nil,
        nthUniqueBusLineDates: [Date] = [],
        rerCCompletionDate: Date? = nil,
        firstChateauRougeDate: Date? = nil
    ) -> AchievementContext {
        AchievementContext(
            totalTravels: totalTravels,
            modesUsed: modesUsed,
            linesByMode: linesByMode,
            travelDates: travelDates,
            firstTravelDate: firstTravelDate,
            nthUniqueStationDates: nthUniqueStationDates,
            nthUniqueLineDates: nthUniqueLineDates,
            sortedTravelDates: sortedTravelDates,
            sortedLineCompletionDates: sortedLineCompletionDates,
            modeCompletionDates: modeCompletionDates,
            modeFirstUsedDates: modeFirstUsedDates,
            firstMultiModeDayDate: firstMultiModeDayDate,
            firstNoctilienDate: firstNoctilienDate,
            streakMilestoneDates: streakMilestoneDates,
            networkHalfDate: networkHalfDate,
            firstBirHakeimLine6Date: firstBirHakeimLine6Date,
            allDepartmentsCoveredDate: allDepartmentsCoveredDate,
            firstOperaNightTravelDate: firstOperaNightTravelDate,
            firstLine13RushHourDate: firstLine13RushHourDate,
            nthUniqueBusLineDates: nthUniqueBusLineDates,
            rerCCompletionDate: rerCCompletionDate,
            firstChateauRougeDate: firstChateauRougeDate
        )
    }

    // MARK: - Snapshot Builder

    /// Builds a minimal GamificationSnapshot for diff testing.
    @MainActor static func snapshot(
        totalXP: Int = 0,
        level: PlayerLevel = LevelDefinitions.level(forXP: 0),
        xpInCurrentLevel: Int = 0,
        xpToNextLevel: Int = LevelDefinitions.xpToNextLevel(totalXP: 0),
        lineBadges: [String: BadgeTier] = [:],
        modeBadges: [TransitMode: BadgeTier] = [:],
        achievements: [AchievementState] = [],
        stats: PlayerStats = .empty,
        lineProgress: [String: LineProgress] = [:],
        xpBreakdown: XPBreakdown = XPBreakdown(
            travelXP: 0, stopXP: 0, lineCompletionXP: 0,
            firstLineXP: 0, achievementXP: 0, streakXP: 0
        ),
        extendedStats: ExtendedStats = .empty
    ) -> GamificationSnapshot {
        GamificationSnapshot(
            totalXP: totalXP,
            level: level,
            xpInCurrentLevel: xpInCurrentLevel,
            xpToNextLevel: xpToNextLevel,
            lineBadges: lineBadges,
            modeBadges: modeBadges,
            achievements: achievements,
            stats: stats,
            lineProgress: lineProgress,
            xpBreakdown: xpBreakdown,
            extendedStats: extendedStats
        )
    }
}
