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

    static let empty = GamificationSnapshot(
        totalXP: 0,
        level: LevelDefinitions.level(forXP: 0),
        xpInCurrentLevel: 0,
        xpToNextLevel: LevelDefinitions.xpToNextLevel(totalXP: 0),
        lineBadges: [:],
        modeBadges: [:],
        achievements: [],
        stats: .empty,
        lineProgress: [:]
    )
}

// MARK: - XP

struct XPBreakdown: Equatable {
    let travelXP: Int
    let stopXP: Int
    let lineCompletionXP: Int
    let modeCompletionXP: Int

    var total: Int {
        travelXP + stopXP + lineCompletionXP + modeCompletionXP
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
    let totalCompletedStops: Int
    let currentStreak: Int
    let firstTravelDate: Date?

    static let empty = PlayerStats(
        totalTravels: 0,
        totalStationsVisited: 0,
        totalLinesStarted: 0,
        totalLinesCompleted: 0,
        totalCompletedStops: 0,
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

// MARK: - Celebration

struct CelebrationEvent: Equatable {
    let xpGained: Int
    let newBadges: [(lineSourceID: String, tier: BadgeTier)]
    let newModeBadges: [(mode: TransitMode, tier: BadgeTier)]
    let newAchievements: [AchievementDefinition]
    let leveledUp: Bool
    let newLevel: PlayerLevel?

    var hasContent: Bool {
        xpGained > 0 || !newBadges.isEmpty || !newModeBadges.isEmpty || !newAchievements.isEmpty || leveledUp
    }

    static func == (lhs: CelebrationEvent, rhs: CelebrationEvent) -> Bool {
        lhs.xpGained == rhs.xpGained &&
            lhs.leveledUp == rhs.leveledUp &&
            lhs.newLevel == rhs.newLevel &&
            lhs.newAchievements.map(\.id) == rhs.newAchievements.map(\.id) &&
            lhs.newBadges.map(\.lineSourceID) == rhs.newBadges.map(\.lineSourceID)
    }
}
