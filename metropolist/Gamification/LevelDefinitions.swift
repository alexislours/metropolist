import Foundation

struct PlayerLevel: Equatable, Identifiable {
    let number: Int
    let xpThreshold: Int

    var id: Int {
        number
    }
}

enum LevelDefinitions {
    /// XP threshold for a given level number.
    /// Formula: 100 * (n - 1)^2
    /// L1: 0, L2: 100, L3: 400, L4: 900, L5: 1600, L6: 2500, ...
    static func xpThreshold(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        return 100 * (level - 1) * (level - 1)
    }

    static func level(forXP points: Int) -> PlayerLevel {
        // Solve 100 * (n-1)^2 <= points  →  n-1 <= sqrt(points / 100)  →  n = floor(sqrt(points / 100)) + 1
        let lvl = points >= 100 ? Int(sqrt(Double(points) / 100.0)) + 1 : 1
        return PlayerLevel(number: lvl, xpThreshold: xpThreshold(forLevel: lvl))
    }

    static func xpInCurrentLevel(totalXP: Int) -> Int {
        let current = level(forXP: totalXP)
        return totalXP - current.xpThreshold
    }

    static func xpToNextLevel(totalXP: Int) -> Int {
        let current = level(forXP: totalXP)
        let nextThreshold = xpThreshold(forLevel: current.number + 1)
        return nextThreshold - current.xpThreshold
    }

    static func nextLevel(after level: PlayerLevel) -> PlayerLevel {
        let next = level.number + 1
        return PlayerLevel(number: next, xpThreshold: xpThreshold(forLevel: next))
    }
}
