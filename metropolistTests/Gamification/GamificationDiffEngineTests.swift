import Foundation
import Testing
@testable import metropolist

@Suite("Gamification Diff Engine", .tags(.gamification, .diff))
@MainActor
struct GamificationDiffEngineTests {
    // MARK: - Core Diff Behavior

    @Test("Identical snapshots return nil")
    func identicalSnapshots() {
        let snapshot = GamificationSnapshot.empty
        #expect(GamificationDiffEngine.diff(before: snapshot, after: snapshot) == nil)
    }

    @Test("XP gain alone produces non-nil event")
    func xpGainAlone() throws {
        let before = TestFixtures.snapshot(totalXP: 0)
        let after = TestFixtures.snapshot(totalXP: 25)
        let result = try #require(GamificationDiffEngine.diff(before: before, after: after))
        #expect(result.xpGained == 25)
    }

    @Test("Badge upgrade detected")
    func badgeUpgrade() throws {
        let before = TestFixtures.snapshot(
            totalXP: 50,
            lineBadges: ["METRO:1": .bronze]
        )
        let after = TestFixtures.snapshot(
            totalXP: 100,
            lineBadges: ["METRO:1": .silver]
        )
        let result = try #require(GamificationDiffEngine.diff(before: before, after: after))
        #expect(result.newBadges.count == 1)
        #expect(result.newBadges.first?.lineSourceID == "METRO:1")
        #expect(result.newBadges.first?.tier == .silver)
    }

    @Test("Mode badge upgrade detected")
    func modeBadgeUpgrade() throws {
        let before = TestFixtures.snapshot(
            totalXP: 0,
            modeBadges: [.metro: .locked]
        )
        let after = TestFixtures.snapshot(
            totalXP: 50,
            modeBadges: [.metro: .bronze]
        )
        let result = try #require(GamificationDiffEngine.diff(before: before, after: after))
        #expect(result.newModeBadges.count == 1)
        #expect(result.newModeBadges.first?.mode == .metro)
        #expect(result.newModeBadges.first?.tier == .bronze)
    }

    @Test("Level-up detected")
    func levelUp() throws {
        let before = TestFixtures.snapshot(
            totalXP: 50,
            level: PlayerLevel(number: 1, xpThreshold: 0)
        )
        let after = TestFixtures.snapshot(
            totalXP: 150,
            level: PlayerLevel(number: 2, xpThreshold: 100)
        )
        let result = try #require(GamificationDiffEngine.diff(before: before, after: after))
        #expect(result.leveledUp == true)
        #expect(result.newLevel?.number == 2)
    }

    @Test("No level-up when level unchanged")
    func noLevelUp() throws {
        let before = TestFixtures.snapshot(totalXP: 10)
        let after = TestFixtures.snapshot(totalXP: 50)
        let result = try #require(GamificationDiffEngine.diff(before: before, after: after))
        #expect(result.leveledUp == false)
        #expect(result.newLevel == nil)
    }

    @Test("New achievement detected")
    func newAchievement() throws {
        let def = AchievementDefinitions.explorer[0] // "premier_pas"
        let locked = AchievementState(id: def.id, definition: def, isUnlocked: false, unlockedAt: nil)
        let unlocked = AchievementState(id: def.id, definition: def, isUnlocked: true, unlockedAt: TestFixtures.referenceDate)

        let before = TestFixtures.snapshot(totalXP: 0, achievements: [locked])
        let after = TestFixtures.snapshot(totalXP: 25, achievements: [unlocked])
        let result = try #require(GamificationDiffEngine.diff(before: before, after: after))
        #expect(result.newAchievements.count == 1)
        #expect(result.newAchievements.first?.id == "premier_pas")
    }

    // MARK: - XP Items

    @Test("Base travel XP item always present")
    func baseTravelXPItem() throws {
        let before = TestFixtures.snapshot(totalXP: 0)
        let after = TestFixtures.snapshot(totalXP: 5)
        let result = try #require(GamificationDiffEngine.diff(before: before, after: after))
        #expect(result.xpItems.contains(where: { $0.kind == .baseTravel && $0.xpValue == 5 }))
    }

    @Test("Discovery bonus for first travel on metro line is 50 XP")
    func metroDiscoveryBonus() throws {
        let before = TestFixtures.snapshot(totalXP: 0)
        let after = TestFixtures.snapshot(totalXP: 75)
        let context = DiffContext(
            lineSourceID: "METRO:1",
            lineShortName: "1",
            lineMode: .metro,
            newStopsCount: 1,
            isFirstTravelOnLine: true,
            afterLineProgress: nil
        )
        let result = try #require(GamificationDiffEngine.diff(before: before, after: after, context: context))
        let discoveryItem = result.xpItems.first(where: { $0.kind == .discoveryBonus })
        #expect(discoveryItem?.xpValue == 50)
    }

    @Test("Discovery bonus for first travel on bus line is 25 XP")
    func busDiscoveryBonus() throws {
        let before = TestFixtures.snapshot(totalXP: 0)
        let after = TestFixtures.snapshot(totalXP: 50)
        let context = DiffContext(
            lineSourceID: "BUS:42",
            lineShortName: "42",
            lineMode: .bus,
            newStopsCount: 1,
            isFirstTravelOnLine: true,
            afterLineProgress: nil
        )
        let result = try #require(GamificationDiffEngine.diff(before: before, after: after, context: context))
        let discoveryItem = result.xpItems.first(where: { $0.kind == .discoveryBonus })
        #expect(discoveryItem?.xpValue == 25)
    }

    // MARK: - Teaser

    @Test("Teaser shows stops to next badge when within 15")
    func teaserStopsToNextBadge() throws {
        let progress = LineProgress(completedStops: 8, totalStops: 25, badge: .bronze, fraction: 0.32)
        let before = TestFixtures.snapshot(totalXP: 0)
        let after = TestFixtures.snapshot(
            totalXP: 25,
            xpInCurrentLevel: 25,
            xpToNextLevel: 100
        )
        let context = DiffContext(
            lineSourceID: "METRO:1",
            lineShortName: "1",
            lineMode: .metro,
            newStopsCount: 1,
            isFirstTravelOnLine: false,
            afterLineProgress: progress
        )
        let result = try #require(GamificationDiffEngine.diff(before: before, after: after, context: context))
        // Silver at 40% of 25 = 10 stops. 10 - 8 = 2 remaining.
        #expect(result.teaser == .stopsToNextBadge(lineShortName: "1", stopsRemaining: 2, nextTier: .silver))
    }

    @Test("Teaser falls back to XP-to-next-level when no badge is close")
    func teaserXPToNextLevel() throws {
        let before = TestFixtures.snapshot(totalXP: 0)
        let after = TestFixtures.snapshot(
            totalXP: 30,
            xpInCurrentLevel: 30,
            xpToNextLevel: 100
        )
        let result = try #require(GamificationDiffEngine.diff(before: before, after: after))
        // xpRemaining = xpToNextLevel - xpInCurrentLevel = 100 - 30 = 70
        let nextLevel = LevelDefinitions.nextLevel(after: LevelDefinitions.level(forXP: 30))
        #expect(result.teaser == .xpToNextLevel(xpRemaining: 70, nextLevel: nextLevel))
    }
}
