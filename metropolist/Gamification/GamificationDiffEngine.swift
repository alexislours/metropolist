import Foundation

enum GamificationDiffEngine {
    static func diff(before: GamificationSnapshot, after: GamificationSnapshot) -> CelebrationEvent? {
        let xpGained = after.totalXP - before.totalXP

        // New line badges (upgraded tier)
        var newBadges: [(lineSourceID: String, tier: BadgeTier)] = []
        for (lineID, afterTier) in after.lineBadges {
            let beforeTier = before.lineBadges[lineID] ?? .locked
            if afterTier > beforeTier {
                newBadges.append((lineSourceID: lineID, tier: afterTier))
            }
        }

        // New mode badges
        var newModeBadges: [(mode: TransitMode, tier: BadgeTier)] = []
        for (mode, afterTier) in after.modeBadges {
            let beforeTier = before.modeBadges[mode] ?? .locked
            if afterTier > beforeTier {
                newModeBadges.append((mode: mode, tier: afterTier))
            }
        }

        // New achievements
        let beforeUnlocked = Set(before.achievements.filter(\.isUnlocked).map(\.id))
        let newAchievements = after.achievements
            .filter { $0.isUnlocked && !beforeUnlocked.contains($0.id) }
            .map(\.definition)

        // Level up
        let leveledUp = after.level.number > before.level.number
        let newLevel = leveledUp ? after.level : nil

        let event = CelebrationEvent(
            xpGained: xpGained,
            newBadges: newBadges,
            newModeBadges: newModeBadges,
            newAchievements: newAchievements,
            leveledUp: leveledUp,
            newLevel: newLevel
        )

        return event.hasContent ? event : nil
    }
}
