import WidgetKit

enum WidgetDataBridge {
    static func updateWidget(from snapshot: GamificationSnapshot) {
        let badgeValues = Array(snapshot.lineBadges.values)
        let data = WidgetData(
            levelNumber: snapshot.level.number,
            totalXP: snapshot.totalXP,
            xpInCurrentLevel: snapshot.xpInCurrentLevel,
            xpToNextLevel: snapshot.xpToNextLevel,
            currentStreak: snapshot.stats.currentStreak,
            longestStreak: snapshot.stats.longestStreak,
            totalTravels: snapshot.stats.totalTravels,
            totalStationsVisited: snapshot.stats.totalStationsVisited,
            totalLinesStarted: snapshot.stats.totalLinesStarted,
            totalLinesCompleted: snapshot.stats.totalLinesCompleted,
            updatedAt: Date(),
            bronzeBadges: badgeValues.filter { $0 >= .bronze }.count,
            silverBadges: badgeValues.filter { $0 >= .silver }.count,
            goldBadges: badgeValues.filter { $0 >= .gold }.count,
            totalBadgeSlots: badgeValues.count,
            unlockedAchievements: snapshot.achievements.filter(\.isUnlocked).count,
            totalAchievements: snapshot.achievements.count,
            totalStationsInNetwork: snapshot.stats.totalStationsInNetwork
        )
        WidgetDataStore.write(data)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
