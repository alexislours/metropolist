import Foundation

enum BadgeTier: Int, Comparable, Equatable, CaseIterable {
    case locked = 0
    case bronze = 1
    case silver = 2
    case gold = 3

    static func < (lhs: BadgeTier, rhs: BadgeTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .locked: String(localized: "Locked", comment: "Badge tier: not yet earned")
        case .bronze: String(localized: "Bronze", comment: "Badge tier: bronze level")
        case .silver: String(localized: "Silver", comment: "Badge tier: silver level")
        case .gold: String(localized: "Gold", comment: "Badge tier: gold level")
        }
    }

    var systemImage: String {
        switch self {
        case .locked: "lock.fill"
        case .bronze: "medal.fill"
        case .silver: "medal.fill"
        case .gold: "medal.star.fill"
        }
    }
}

enum BadgeComputation {
    /// Completion-based badge: Bronze ≥10%, Silver ≥40%, Gold = 100%
    static func completionTier(completed: Int, total: Int) -> BadgeTier {
        guard total > 0 else { return .locked }
        let fraction = Double(completed) / Double(total)
        if fraction >= 1.0 { return .gold }
        if fraction >= 0.4 { return .silver }
        if fraction >= 0.1 { return .bronze }
        return .locked
    }
}
