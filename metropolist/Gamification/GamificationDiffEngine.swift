import Foundation

struct DiffContext {
    let lineSourceID: String
    let lineShortName: String
    let lineMode: TransitMode
    let newStopsCount: Int
    let isFirstTravelOnLine: Bool
    let afterLineProgress: LineProgress?
}

enum GamificationDiffEngine {
    static func diff(
        before: GamificationSnapshot,
        after: GamificationSnapshot,
        context: DiffContext? = nil
    ) -> CelebrationEvent? {
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

        // Build XP items
        let xpItems = buildXPItems(
            before: before,
            after: after,
            context: context,
            newBadges: newBadges,
            newAchievements: newAchievements
        )

        // Build level progress
        let levelProgress = CelebrationLevelProgress(
            afterLevel: after.level,
            beforeXPInLevel: before.xpInCurrentLevel,
            beforeXPToNext: before.xpToNextLevel,
            afterXPInLevel: after.xpInCurrentLevel,
            afterXPToNext: after.xpToNextLevel,
            leveledUp: leveledUp
        )

        // Build teaser
        let teaser = buildTeaser(after: after, context: context)

        let event = CelebrationEvent(
            xpGained: xpGained,
            newBadges: newBadges,
            newModeBadges: newModeBadges,
            newAchievements: newAchievements,
            leveledUp: leveledUp,
            newLevel: newLevel,
            xpItems: xpItems,
            levelProgress: levelProgress,
            teaser: teaser
        )

        return event.hasContent ? event : nil
    }

    // MARK: - XP Item Builder

    private static func buildXPItems(
        before: GamificationSnapshot,
        after: GamificationSnapshot,
        context: DiffContext?,
        newBadges: [(lineSourceID: String, tier: BadgeTier)],
        newAchievements: [AchievementDefinition]
    ) -> [CelebrationXPItem] {
        var items: [CelebrationXPItem] = []

        // Base travel XP (always awarded)
        items.append(CelebrationXPItem(
            kind: .baseTravel,
            xpValue: GamificationEngine.xpPerTravel,
            label: String(localized: "Travel recorded", comment: "XP item: base travel XP"),
            systemImage: "tram.fill"
        ))

        if let ctx = context {
            // Discovery bonus (first travel on this line)
            if ctx.isFirstTravelOnLine {
                let discoveryXP = ctx.lineMode == .bus ? GamificationEngine.xpPerFirstLineBus : GamificationEngine.xpPerFirstLineOther
                items.append(CelebrationXPItem(
                    kind: .discoveryBonus,
                    xpValue: discoveryXP,
                    label: String(localized: "New line discovered!", comment: "XP item: first travel on line bonus"),
                    systemImage: "sparkles"
                ))
            }

            // New stations
            if ctx.newStopsCount > 0 {
                let stopsXP = ctx.newStopsCount * GamificationEngine.xpPerUniqueStop
                items.append(CelebrationXPItem(
                    kind: .newStations,
                    xpValue: stopsXP,
                    label: String(
                        localized: "\(ctx.newStopsCount) new stations",
                        comment: "XP item: new unique stations visited"
                    ),
                    systemImage: "mappin.and.ellipse"
                ))
            }
        }

        // Badge milestones
        for badge in newBadges {
            // Estimate badge XP: difference in line completion tier thresholds
            // This is approximate — the exact XP is baked into the total diff
            items.append(CelebrationXPItem(
                kind: .badgeMilestone,
                xpValue: 0, // XP already counted in other categories
                label: String(localized: "\(badge.tier.label) badge earned", comment: "XP item: badge tier milestone"),
                systemImage: badge.tier.systemImage
            ))
        }

        // Line completion
        if let ctx = context {
            let afterProgress = ctx.afterLineProgress
            let beforeProgress = before.lineProgress[ctx.lineSourceID]
            if afterProgress?.fraction == 1.0, (beforeProgress?.fraction ?? 0) < 1.0 {
                let totalStops = afterProgress?.totalStops ?? 0
                let completionXP = GamificationEngine.xpBaseLineCompletion + (totalStops * GamificationEngine.xpPerLineCompletionStop)
                items.append(CelebrationXPItem(
                    kind: .lineCompletion,
                    xpValue: completionXP,
                    label: String(localized: "Line completed!", comment: "XP item: full line completion bonus"),
                    systemImage: "checkmark.seal.fill"
                ))
            }
        }

        // Streak bonus
        let streakXPDiff = computeStreakXPDiff(before: before, after: after)
        if streakXPDiff > 0 {
            items.append(CelebrationXPItem(
                kind: .streak,
                xpValue: streakXPDiff,
                label: String(
                    localized: "\(after.stats.currentStreak)-day streak",
                    comment: "XP item: streak bonus"
                ),
                systemImage: "flame.fill"
            ))
        }

        // Achievement rewards
        for achievement in newAchievements {
            items.append(CelebrationXPItem(
                kind: .achievement,
                xpValue: achievement.xpReward,
                label: achievement.title,
                systemImage: achievement.systemImage
            ))
        }

        return items
    }

    private static func computeStreakXPDiff(
        before: GamificationSnapshot,
        after: GamificationSnapshot
    ) -> Int {
        // Streak XP is the difference in total streak-based XP between snapshots.
        // We approximate by checking if streak grew and computing the marginal XP.
        let beforeStreak = before.stats.currentStreak
        let afterStreak = after.stats.currentStreak
        guard afterStreak > beforeStreak else { return 0 }
        return min(5 * afterStreak, 50)
    }

    // MARK: - Teaser Builder

    private static func buildTeaser(
        after: GamificationSnapshot,
        context: DiffContext?
    ) -> CelebrationTeaser? {
        // Priority 1: closest badge milestone on the current line (within 15 stops)
        if let ctx = context, let progress = ctx.afterLineProgress {
            let nextTier = nextBadgeTier(for: progress.badge)
            if let tier = nextTier {
                let thresholdFraction = tier.threshold
                let stopsNeeded = Int(ceil(thresholdFraction * Double(progress.totalStops))) - progress.completedStops
                if stopsNeeded > 0, stopsNeeded <= 15 {
                    return .stopsToNextBadge(
                        lineShortName: ctx.lineShortName,
                        stopsRemaining: stopsNeeded,
                        nextTier: tier
                    )
                }
            }
        }

        // Priority 2: XP to next level
        let xpRemaining = after.xpToNextLevel - after.xpInCurrentLevel
        if xpRemaining > 0 {
            let nextLevel = LevelDefinitions.nextLevel(after: after.level)
            return .xpToNextLevel(xpRemaining: xpRemaining, nextLevel: nextLevel)
        }

        return nil
    }

    private static func nextBadgeTier(for current: BadgeTier) -> BadgeTier? {
        switch current {
        case .locked: .bronze
        case .bronze: .silver
        case .silver: .gold
        case .gold: nil
        }
    }
}
