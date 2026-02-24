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
        xpBreakdown: XPBreakdown(travelXP: 0, stopXP: 0, lineCompletionXP: 0, firstLineXP: 0, achievementXP: 0, streakXP: 0)
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
    let firstTravelDate: Date?

    static let empty = PlayerStats(
        totalTravels: 0,
        totalStationsVisited: 0,
        totalLinesStarted: 0,
        totalLinesCompleted: 0,
        currentStreak: 0,
        firstTravelDate: nil
    )
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
    let beforeLevel: PlayerLevel
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
