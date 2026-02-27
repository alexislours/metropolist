import WidgetKit

struct MetropolistEntry: TimelineEntry {
    let date: Date
    let data: WidgetData

    static let placeholder = MetropolistEntry(
        date: .now,
        data: WidgetData(
            levelNumber: 5,
            totalXP: 1800,
            xpInCurrentLevel: 200,
            xpToNextLevel: 500,
            currentStreak: 3,
            longestStreak: 7,
            totalTravels: 42,
            totalStationsVisited: 128,
            totalLinesStarted: 12,
            totalLinesCompleted: 2,
            updatedAt: .now,
            bronzeBadges: 10,
            silverBadges: 5,
            goldBadges: 2,
            totalBadgeSlots: 18,
            unlockedAchievements: 9,
            totalAchievements: 31,
            totalStationsInNetwork: 820
        )
    )
}

struct MetropolistTimelineProvider: TimelineProvider {
    func placeholder(in _: Context) -> MetropolistEntry {
        .placeholder
    }

    func getSnapshot(in _: Context, completion: @escaping (MetropolistEntry) -> Void) {
        let data = WidgetDataStore.read() ?? .empty
        completion(MetropolistEntry(date: .now, data: data))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<MetropolistEntry>) -> Void) {
        let data = WidgetDataStore.read() ?? .empty
        let entry = MetropolistEntry(date: .now, data: data)
        completion(Timeline(entries: [entry], policy: .never))
    }
}
