import Foundation

struct WidgetData: Codable, Sendable {
    let levelNumber: Int
    let totalXP: Int
    let xpInCurrentLevel: Int
    let xpToNextLevel: Int
    let currentStreak: Int
    let longestStreak: Int
    let totalTravels: Int
    let totalStationsVisited: Int
    let totalLinesStarted: Int
    let totalLinesCompleted: Int
    let updatedAt: Date

    // New fields (optional for backward compatibility)
    let bronzeBadges: Int?
    let silverBadges: Int?
    let goldBadges: Int?
    let totalBadgeSlots: Int?
    let unlockedAchievements: Int?
    let totalAchievements: Int?
    let totalStationsInNetwork: Int?

    static let empty = WidgetData(
        levelNumber: 1,
        totalXP: 0,
        xpInCurrentLevel: 0,
        xpToNextLevel: 100,
        currentStreak: 0,
        longestStreak: 0,
        totalTravels: 0,
        totalStationsVisited: 0,
        totalLinesStarted: 0,
        totalLinesCompleted: 0,
        updatedAt: .distantPast,
        bronzeBadges: 0,
        silverBadges: 0,
        goldBadges: 0,
        totalBadgeSlots: 0,
        unlockedAchievements: 0,
        totalAchievements: 0,
        totalStationsInNetwork: 0
    )

    init(
        levelNumber: Int,
        totalXP: Int,
        xpInCurrentLevel: Int,
        xpToNextLevel: Int,
        currentStreak: Int,
        longestStreak: Int,
        totalTravels: Int,
        totalStationsVisited: Int,
        totalLinesStarted: Int,
        totalLinesCompleted: Int,
        updatedAt: Date,
        bronzeBadges: Int? = nil,
        silverBadges: Int? = nil,
        goldBadges: Int? = nil,
        totalBadgeSlots: Int? = nil,
        unlockedAchievements: Int? = nil,
        totalAchievements: Int? = nil,
        totalStationsInNetwork: Int? = nil
    ) {
        self.levelNumber = levelNumber
        self.totalXP = totalXP
        self.xpInCurrentLevel = xpInCurrentLevel
        self.xpToNextLevel = xpToNextLevel
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.totalTravels = totalTravels
        self.totalStationsVisited = totalStationsVisited
        self.totalLinesStarted = totalLinesStarted
        self.totalLinesCompleted = totalLinesCompleted
        self.updatedAt = updatedAt
        self.bronzeBadges = bronzeBadges
        self.silverBadges = silverBadges
        self.goldBadges = goldBadges
        self.totalBadgeSlots = totalBadgeSlots
        self.unlockedAchievements = unlockedAchievements
        self.totalAchievements = totalAchievements
        self.totalStationsInNetwork = totalStationsInNetwork
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        levelNumber = try container.decode(Int.self, forKey: .levelNumber)
        totalXP = try container.decode(Int.self, forKey: .totalXP)
        xpInCurrentLevel = try container.decode(Int.self, forKey: .xpInCurrentLevel)
        xpToNextLevel = try container.decode(Int.self, forKey: .xpToNextLevel)
        currentStreak = try container.decode(Int.self, forKey: .currentStreak)
        longestStreak = try container.decode(Int.self, forKey: .longestStreak)
        totalTravels = try container.decode(Int.self, forKey: .totalTravels)
        totalStationsVisited = try container.decode(Int.self, forKey: .totalStationsVisited)
        totalLinesStarted = try container.decode(Int.self, forKey: .totalLinesStarted)
        totalLinesCompleted = try container.decode(Int.self, forKey: .totalLinesCompleted)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        bronzeBadges = try container.decodeIfPresent(Int.self, forKey: .bronzeBadges)
        silverBadges = try container.decodeIfPresent(Int.self, forKey: .silverBadges)
        goldBadges = try container.decodeIfPresent(Int.self, forKey: .goldBadges)
        totalBadgeSlots = try container.decodeIfPresent(Int.self, forKey: .totalBadgeSlots)
        unlockedAchievements = try container.decodeIfPresent(Int.self, forKey: .unlockedAchievements)
        totalAchievements = try container.decodeIfPresent(Int.self, forKey: .totalAchievements)
        totalStationsInNetwork = try container.decodeIfPresent(Int.self, forKey: .totalStationsInNetwork)
    }
}

enum WidgetDataStore {
    private static let suiteName = "group.com.alexislours.metropolist"
    private static let key = "widgetData"

    static func read() -> WidgetData? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key)
        else {
            return nil
        }
        return try? JSONDecoder().decode(WidgetData.self, from: data)
    }

    static func write(_ widgetData: WidgetData) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(widgetData)
        else {
            return
        }
        defaults.set(data, forKey: key)
    }
}
