import Foundation

// MARK: - Lightweight Input Records (no SwiftData dependency)

struct CompletedStopRecord {
    let lineSourceID: String
    let stationSourceID: String
    let completedAt: Date
}

struct TravelRecord {
    let lineSourceID: String
    let createdAt: Date
    let fromStationSourceID: String
    let toStationSourceID: String
}

struct StationMetadata {
    let name: String
    let postalCode: String?
    let fareZone: String?
}

struct LineMetadata {
    let sourceID: String
    let shortName: String
    let longName: String
    let mode: TransitMode
    let submode: String?
    let color: String
    let textColor: String
    let totalStations: Int
}

// MARK: - Engine Input

struct GamificationInput {
    let completedStops: [CompletedStopRecord]
    let travels: [TravelRecord]
    let lineMetadata: [String: LineMetadata]
    let stationMetadata: [String: StationMetadata]
}

// MARK: - Engine Output

struct GamificationSnapshot: Equatable {
    let totalXP: Int
    let level: PlayerLevel
    let xpInCurrentLevel: Int
    let xpToNextLevel: Int
    let lineBadges: [String: BadgeTier]
    let modeBadges: [TransitMode: BadgeTier]
    let achievements: [AchievementState]
    let stats: PlayerStats
    let lineProgress: [String: LineProgress]
    let xpBreakdown: XPBreakdown
    let extendedStats: ExtendedStats

    static let empty = GamificationSnapshot(
        totalXP: 0,
        level: LevelDefinitions.level(forXP: 0),
        xpInCurrentLevel: 0,
        xpToNextLevel: LevelDefinitions.xpToNextLevel(totalXP: 0),
        lineBadges: [:],
        modeBadges: [:],
        achievements: [],
        stats: .empty,
        lineProgress: [:],
        xpBreakdown: XPBreakdown(travelXP: 0, stopXP: 0, lineCompletionXP: 0, firstLineXP: 0, achievementXP: 0, streakXP: 0),
        extendedStats: .empty
    )
}

// MARK: - XP

struct XPBreakdown: Equatable {
    let travelXP: Int
    let stopXP: Int
    let lineCompletionXP: Int
    let firstLineXP: Int
    let achievementXP: Int
    let streakXP: Int

    var total: Int {
        travelXP + stopXP + lineCompletionXP + firstLineXP + achievementXP + streakXP
    }
}

// MARK: - Badges

struct LineProgress: Equatable {
    let completedStops: Int
    let totalStops: Int
    let badge: BadgeTier
    let fraction: Double
}

// MARK: - Stats

struct PlayerStats: Equatable {
    let totalTravels: Int
    let totalStationsVisited: Int
    let totalLinesStarted: Int
    let totalLinesCompleted: Int
    let currentStreak: Int
    let longestStreak: Int
    let firstTravelDate: Date?

    static let empty = PlayerStats(
        totalTravels: 0,
        totalStationsVisited: 0,
        totalLinesStarted: 0,
        totalLinesCompleted: 0,
        currentStreak: 0,
        longestStreak: 0,
        firstTravelDate: nil
    )
}

// MARK: - Extended Stats

struct ExtendedStats: Equatable {
    let travelsPerWeek: [WeeklyTravelCount]
    let busiestDayOfWeek: DayOfWeekStat?
    let busiestHourOfDay: HourOfDayStat?
    let topStations: [RankedStation]
    let topLines: [RankedLine]
    let departmentCoverage: [DepartmentCoverage]
    let fareZoneCoverage: [FareZoneCoverage]

    static let empty = ExtendedStats(
        travelsPerWeek: [],
        busiestDayOfWeek: nil,
        busiestHourOfDay: nil,
        topStations: [],
        topLines: [],
        departmentCoverage: [],
        fareZoneCoverage: []
    )
}

struct WeeklyTravelCount: Identifiable, Equatable {
    let id: Date
    let count: Int
}

struct DayOfWeekStat: Equatable {
    let dayIndex: Int
    let dayName: String
    let allDays: [DayCount]

    struct DayCount: Identifiable, Equatable {
        var id: Int {
            dayIndex
        }

        let dayIndex: Int
        let dayName: String
        let count: Int
    }
}

struct HourOfDayStat: Equatable {
    let hour: Int
    let allHours: [HourCount]

    struct HourCount: Identifiable, Equatable {
        var id: Int {
            hour
        }

        let hour: Int
        let count: Int
    }
}

struct RankedStation: Identifiable, Equatable {
    var id: String {
        stationSourceID
    }

    let stationSourceID: String
    let name: String
    let visitCount: Int
}

struct RankedLine: Identifiable, Equatable {
    var id: String {
        lineSourceID
    }

    let lineSourceID: String
    let shortName: String
    let mode: TransitMode
    let color: String
    let textColor: String
    let travelCount: Int
}

struct DepartmentCoverage: Identifiable, Equatable {
    var id: String {
        department
    }

    let department: String
    let label: String
    let visited: Int
    let total: Int
    var percentage: Double {
        total > 0 ? Double(visited) / Double(total) : 0
    }
}

struct FareZoneCoverage: Identifiable, Equatable {
    var id: String {
        zone
    }

    let zone: String
    let visited: Int
    let total: Int
    var percentage: Double {
        total > 0 ? Double(visited) / Double(total) : 0
    }
}

// MARK: - Achievements

struct AchievementState: Identifiable, Equatable {
    let id: String
    let definition: AchievementDefinition
    let isUnlocked: Bool
    let unlockedAt: Date?
}

// MARK: - Celebration XP Breakdown

struct CelebrationXPItem: Identifiable, Equatable {
    let id = UUID()
    let kind: Kind
    let xpValue: Int
    let label: String
    let systemImage: String

    enum Kind: Equatable {
        case baseTravel
        case discoveryBonus
        case newStations
        case badgeMilestone
        case lineCompletion
        case achievement
        case streak
    }

    static func == (lhs: CelebrationXPItem, rhs: CelebrationXPItem) -> Bool {
        lhs.kind == rhs.kind && lhs.xpValue == rhs.xpValue && lhs.label == rhs.label
    }
}

struct CelebrationLevelProgress: Equatable {
    let afterLevel: PlayerLevel
    let beforeXPInLevel: Int
    let beforeXPToNext: Int
    let afterXPInLevel: Int
    let afterXPToNext: Int
    let leveledUp: Bool
}

enum CelebrationTeaser: Equatable {
    case stopsToNextBadge(lineShortName: String, stopsRemaining: Int, nextTier: BadgeTier)
    case xpToNextLevel(xpRemaining: Int, nextLevel: PlayerLevel)
}

// MARK: - Celebration

struct CelebrationEvent: Equatable {
    let xpGained: Int
    let newBadges: [(lineSourceID: String, tier: BadgeTier)]
    let newModeBadges: [(mode: TransitMode, tier: BadgeTier)]
    let newAchievements: [AchievementDefinition]
    let leveledUp: Bool
    let newLevel: PlayerLevel?
    let xpItems: [CelebrationXPItem]
    let levelProgress: CelebrationLevelProgress
    let teaser: CelebrationTeaser?

    var hasContent: Bool {
        xpGained > 0 || !newBadges.isEmpty || !newModeBadges.isEmpty || !newAchievements.isEmpty || leveledUp
    }

    static func == (lhs: CelebrationEvent, rhs: CelebrationEvent) -> Bool {
        lhs.xpGained == rhs.xpGained &&
            lhs.leveledUp == rhs.leveledUp &&
            lhs.newLevel == rhs.newLevel &&
            lhs.newAchievements.map(\.id) == rhs.newAchievements.map(\.id) &&
            lhs.newBadges.map(\.lineSourceID) == rhs.newBadges.map(\.lineSourceID) &&
            lhs.xpItems == rhs.xpItems &&
            lhs.levelProgress == rhs.levelProgress &&
            lhs.teaser == rhs.teaser
    }
}
