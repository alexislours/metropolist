import Foundation

extension GamificationEngine {
    static func computeStreakMilestones(uniqueDays: [Date], targets: [Int]) -> [Int: Date] {
        guard !uniqueDays.isEmpty else { return [:] }
        let cal = Calendar.current
        var results: [Int: Date] = [:]
        let targetSet = Set(targets)
        var streakLen = 1

        for target in targetSet where streakLen >= target && results[target] == nil {
            results[target] = uniqueDays[0]
        }

        for index in 1 ..< uniqueDays.count {
            let diff = cal.dateComponents([.day], from: uniqueDays[index - 1], to: uniqueDays[index]).day ?? 0
            if diff == 1 {
                streakLen += 1
                for target in targetSet where streakLen >= target && results[target] == nil {
                    results[target] = uniqueDays[index]
                }
            } else {
                streakLen = 1
            }
            if results.count == targets.count { break }
        }

        return results
    }

    static func computeStreakXP(uniqueDays: [Date]) -> Int {
        guard !uniqueDays.isEmpty else { return 0 }
        let cal = Calendar.current
        var totalXP = 0
        var streakLen = 1
        totalXP += min(5 * streakLen, 50) // Day 1: +5

        for index in 1 ..< uniqueDays.count {
            let diff = cal.dateComponents([.day], from: uniqueDays[index - 1], to: uniqueDays[index]).day ?? 0
            if diff == 1 {
                streakLen += 1
            } else {
                streakLen = 1
            }
            totalXP += min(5 * streakLen, 50)
        }

        return totalXP
    }

    static func computeStreaks(uniqueDays: [Date]) -> (longest: Int, current: Int) {
        guard !uniqueDays.isEmpty else { return (0, 0) }
        let cal = Calendar.current

        var longest = 1
        var current = 1
        var streakLen = 1

        for index in 1 ..< uniqueDays.count {
            let diff = cal.dateComponents([.day], from: uniqueDays[index - 1], to: uniqueDays[index]).day ?? 0
            if diff == 1 {
                streakLen += 1
                longest = max(longest, streakLen)
            } else {
                streakLen = 1
            }
        }

        // Current streak: check if last travel day is today or yesterday
        let today = cal.startOfDay(for: Date())
        guard let lastDay = uniqueDays.last else { return (longest, 0) }
        let daysSinceLast = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0

        if daysSinceLast <= 1 {
            // Count backwards from last day
            current = 1
            for index in stride(from: uniqueDays.count - 2, through: 0, by: -1) {
                let diff = cal.dateComponents([.day], from: uniqueDays[index], to: uniqueDays[index + 1]).day ?? 0
                if diff == 1 {
                    current += 1
                } else {
                    break
                }
            }
        } else {
            current = 0
        }

        return (longest, current)
    }
}
