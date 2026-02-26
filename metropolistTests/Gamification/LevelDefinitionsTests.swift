import Testing
@testable import metropolist

@Suite("Level Definitions", .tags(.gamification, .levels))
@MainActor
struct LevelDefinitionsTests {
    // MARK: - xpThreshold

    @Test("Level 1 threshold is 0")
    func level1Threshold() {
        #expect(LevelDefinitions.xpThreshold(forLevel: 1) == 0)
    }

    @Test("Level 2 threshold is 100")
    func level2Threshold() {
        #expect(LevelDefinitions.xpThreshold(forLevel: 2) == 100)
    }

    @Test("Threshold formula: 100 * (n-1)^2", arguments: [
        (level: 3, expected: 400),
        (level: 4, expected: 900),
        (level: 5, expected: 1600),
        (level: 10, expected: 8100),
        (level: 50, expected: 240_100),
    ])
    func thresholdFormula(level: Int, expected: Int) {
        #expect(LevelDefinitions.xpThreshold(forLevel: level) == expected)
    }

    @Test("Below-1 level returns 0")
    func belowLevel1() {
        #expect(LevelDefinitions.xpThreshold(forLevel: 0) == 0)
        #expect(LevelDefinitions.xpThreshold(forLevel: -1) == 0)
    }

    // MARK: - level(forXP:)

    @Test("0 XP is level 1")
    func zeroXPIsLevel1() {
        let level = LevelDefinitions.level(forXP: 0)
        #expect(level.number == 1)
        #expect(level.xpThreshold == 0)
    }

    @Test("99 XP is still level 1")
    func justBelowLevel2() {
        #expect(LevelDefinitions.level(forXP: 99).number == 1)
    }

    @Test("100 XP is level 2")
    func exactlyLevel2() {
        #expect(LevelDefinitions.level(forXP: 100).number == 2)
    }

    @Test("Level from XP at boundaries", arguments: [
        (xp: 399, expected: 2),
        (xp: 400, expected: 3),
        (xp: 900, expected: 4),
        (xp: 8100, expected: 10),
    ])
    func levelFromXPBoundaries(xp: Int, expected: Int) {
        #expect(LevelDefinitions.level(forXP: xp).number == expected)
    }

    // MARK: - Round-trip invariant

    @Test("Round-trip: threshold(level(forXP: threshold)) == threshold", arguments: 1 ... 50)
    func roundTrip(level: Int) {
        let threshold = LevelDefinitions.xpThreshold(forLevel: level)
        let computed = LevelDefinitions.level(forXP: threshold)
        #expect(computed.number == level)
        #expect(computed.xpThreshold == threshold)
    }

    // MARK: - xpInCurrentLevel / xpToNextLevel

    @Test("xpInCurrentLevel at level boundaries")
    func xpInCurrentLevelBoundaries() {
        // At exactly level 2 threshold (100 XP), in-level progress is 0
        #expect(LevelDefinitions.xpInCurrentLevel(totalXP: 100) == 0)
        // 150 XP = level 2, 50 XP into it
        #expect(LevelDefinitions.xpInCurrentLevel(totalXP: 150) == 50)
        // 0 XP = level 1, 0 into it
        #expect(LevelDefinitions.xpInCurrentLevel(totalXP: 0) == 0)
    }

    @Test("xpToNextLevel returns correct gap")
    func xpToNextLevel() {
        // Level 1 → 2: gap is 100
        #expect(LevelDefinitions.xpToNextLevel(totalXP: 0) == 100)
        // Level 2 → 3: gap is 400 - 100 = 300
        #expect(LevelDefinitions.xpToNextLevel(totalXP: 100) == 300)
        // Level 3 → 4: gap is 900 - 400 = 500
        #expect(LevelDefinitions.xpToNextLevel(totalXP: 400) == 500)
    }
}
