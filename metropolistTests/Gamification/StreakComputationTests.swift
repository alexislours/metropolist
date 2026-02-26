import Testing
@testable import metropolist

@Suite("Streak Computation", .tags(.gamification, .streaks))
@MainActor
struct StreakComputationTests {
    // MARK: - computeStreaks (longest only — current depends on Date())

    @Test("Empty days returns zero for both streaks")
    func emptyStreaks() {
        let result = GamificationEngine.computeStreaks(uniqueDays: [])
        #expect(result.longest == 0)
        #expect(result.current == 0)
    }

    @Test("Single day returns longest 1")
    func singleDay() {
        let result = GamificationEngine.computeStreaks(uniqueDays: [TestFixtures.referenceDate])
        #expect(result.longest == 1)
    }

    @Test("Consecutive days produce correct longest streak")
    func consecutiveDays() {
        let days = TestFixtures.consecutiveDays(count: 5)
        let result = GamificationEngine.computeStreaks(uniqueDays: days)
        #expect(result.longest == 5)
    }

    @Test("Gap resets streak and longest reflects pre-gap run")
    func gapResetsStreak() {
        // Days 0,1,2 (streak of 3) then gap at 3-4, then days 5,6 (streak of 2)
        let days = [0, 1, 2, 5, 6].map { TestFixtures.date(daysOffset: $0) }
        let result = GamificationEngine.computeStreaks(uniqueDays: days)
        #expect(result.longest == 3)
    }

    @Test("Longest streak found in middle of sequence")
    func longestInMiddle() {
        // Day 0 alone, then 2-6 (5 consecutive), then 10-11 (2 consecutive)
        let days = [0, 2, 3, 4, 5, 6, 10, 11].map { TestFixtures.date(daysOffset: $0) }
        let result = GamificationEngine.computeStreaks(uniqueDays: days)
        #expect(result.longest == 5)
    }

    // MARK: - computeStreakXP

    @Test("Empty days returns zero XP")
    func emptyXP() {
        #expect(GamificationEngine.computeStreakXP(uniqueDays: []) == 0)
    }

    @Test("Single day awards 5 XP")
    func singleDayXP() {
        #expect(GamificationEngine.computeStreakXP(uniqueDays: [TestFixtures.referenceDate]) == 5)
    }

    @Test("Three consecutive days award cumulative XP")
    func threeDaysXP() {
        let days = TestFixtures.consecutiveDays(count: 3)
        // Day 1: 5, Day 2: 10, Day 3: 15 = 30
        #expect(GamificationEngine.computeStreakXP(uniqueDays: days) == 30)
    }

    @Test("XP per day caps at 50")
    func xpCap() {
        let days = TestFixtures.consecutiveDays(count: 12)
        // Days 1-9: 5+10+15+20+25+30+35+40+45 = 225
        // Days 10-12: 50+50+50 = 150
        // Total = 375
        #expect(GamificationEngine.computeStreakXP(uniqueDays: days) == 375)
    }

    @Test("Gap resets XP multiplier")
    func gapResetsXPMultiplier() {
        // Days 0,1,2 (streak of 3) then gap, then days 5,6 (new streak of 2)
        let days = [0, 1, 2, 5, 6].map { TestFixtures.date(daysOffset: $0) }
        // First streak: 5+10+15 = 30
        // Second streak: 5+10 = 15
        // Total = 45
        #expect(GamificationEngine.computeStreakXP(uniqueDays: days) == 45)
    }

    // MARK: - computeStreakMilestones

    @Test("Empty days returns empty milestones")
    func emptyMilestones() {
        let result = GamificationEngine.computeStreakMilestones(uniqueDays: [], targets: [7, 30])
        #expect(result.isEmpty)
    }

    @Test("7-day streak milestone is set on day 7")
    func sevenDayMilestone() {
        let days = TestFixtures.consecutiveDays(count: 10)
        let result = GamificationEngine.computeStreakMilestones(uniqueDays: days, targets: [7])
        // Day at index 6 is the 7th consecutive day
        #expect(result[7] == TestFixtures.date(daysOffset: 6))
    }

    @Test("Target not reached returns empty for that target")
    func targetNotReached() {
        let days = TestFixtures.consecutiveDays(count: 5)
        let result = GamificationEngine.computeStreakMilestones(uniqueDays: days, targets: [7])
        #expect(result.isEmpty)
    }

    @Test("Multiple targets resolved from single streak")
    func multipleTargets() {
        let days = TestFixtures.consecutiveDays(count: 31)
        let result = GamificationEngine.computeStreakMilestones(uniqueDays: days, targets: [7, 30])
        #expect(result[7] == TestFixtures.date(daysOffset: 6))
        #expect(result[30] == TestFixtures.date(daysOffset: 29))
    }
}
