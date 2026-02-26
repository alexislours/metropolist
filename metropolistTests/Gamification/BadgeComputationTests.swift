import Testing
@testable import metropolist

@Suite("Badge Computation", .tags(.gamification, .badges))
@MainActor
struct BadgeComputationTests {
    // MARK: - completionTier thresholds

    @Test("Zero total returns locked")
    func zeroTotal() {
        #expect(BadgeComputation.completionTier(completed: 0, total: 0) == .locked)
        #expect(BadgeComputation.completionTier(completed: 5, total: 0) == .locked)
    }

    @Test("Below 10% returns locked")
    func belowBronze() {
        // 9% of 100 = 9 completed
        #expect(BadgeComputation.completionTier(completed: 9, total: 100) == .locked)
        #expect(BadgeComputation.completionTier(completed: 0, total: 25) == .locked)
    }

    @Test("Exactly 10% returns bronze")
    func exactlyBronze() {
        #expect(BadgeComputation.completionTier(completed: 10, total: 100) == .bronze)
    }

    @Test("Between 10% and 40% returns bronze", arguments: [
        (completed: 3, total: 25),   // 12%
        (completed: 9, total: 25),   // 36%
        (completed: 39, total: 100), // 39%
    ])
    func bronzeRange(completed: Int, total: Int) {
        #expect(BadgeComputation.completionTier(completed: completed, total: total) == .bronze)
    }

    @Test("Exactly 40% returns silver")
    func exactlySilver() {
        #expect(BadgeComputation.completionTier(completed: 40, total: 100) == .silver)
        #expect(BadgeComputation.completionTier(completed: 10, total: 25) == .silver)
    }

    @Test("Between 40% and 100% returns silver", arguments: [
        (completed: 50, total: 100),
        (completed: 99, total: 100),
        (completed: 24, total: 25),
    ])
    func silverRange(completed: Int, total: Int) {
        #expect(BadgeComputation.completionTier(completed: completed, total: total) == .silver)
    }

    @Test("100% returns gold")
    func exactlyGold() {
        #expect(BadgeComputation.completionTier(completed: 100, total: 100) == .gold)
        #expect(BadgeComputation.completionTier(completed: 25, total: 25) == .gold)
    }

    @Test("Over 100% still returns gold")
    func overGold() {
        #expect(BadgeComputation.completionTier(completed: 30, total: 25) == .gold)
    }

    // MARK: - Small lines

    @Test("Small line with 1 station: 1/1 = gold")
    func singleStationLine() {
        #expect(BadgeComputation.completionTier(completed: 1, total: 1) == .gold)
    }

    @Test("Small line with 2 stations: 1/2 = silver (50%)")
    func twoStationLine() {
        #expect(BadgeComputation.completionTier(completed: 1, total: 2) == .silver)
    }

    // MARK: - Tier ordering

    @Test("Tiers are ordered: locked < bronze < silver < gold")
    func tierOrdering() {
        #expect(BadgeTier.locked < .bronze)
        #expect(BadgeTier.bronze < .silver)
        #expect(BadgeTier.silver < .gold)
    }
}
