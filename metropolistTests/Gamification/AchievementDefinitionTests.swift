import Foundation
import Testing
@testable import metropolist

@Suite("Achievement Definitions", .tags(.gamification, .achievements))
@MainActor
struct AchievementDefinitionTests {
    private func definition(id: String) -> AchievementDefinition {
        AchievementDefinitions.all.first(where: { $0.id == id })!
    }

    // MARK: - Versatile (polyvalent)

    @Test("Versatile unlocks when all modes used, returns latest first-used date")
    func polyvalentUnlocks() {
        let ref = TestFixtures.referenceDate
        let day1 = TestFixtures.date(daysOffset: 1)
        let ctx = TestFixtures.achievementContext(
            modesUsed: [.metro, .rer],
            linesByMode: [.metro: ["M1"], .rer: ["RA"]],
            modeFirstUsedDates: [.metro: ref, .rer: day1]
        )
        #expect(definition(id: "polyvalent").evaluate(ctx) == day1)
    }

    @Test("Versatile nil when one mode missing")
    func polyvalentMissingMode() {
        let ctx = TestFixtures.achievementContext(
            modesUsed: [.metro, .rer],
            linesByMode: [.metro: ["M1"], .rer: ["RA"], .tram: ["T1"]]
        )
        #expect(definition(id: "polyvalent").evaluate(ctx) == nil)
    }

    @Test("Versatile nil when linesByMode is empty")
    func polyvalentEmptyLinesByMode() {
        let ctx = TestFixtures.achievementContext(
            modesUsed: [.metro],
            linesByMode: [:]
        )
        #expect(definition(id: "polyvalent").evaluate(ctx) == nil)
    }

    // MARK: - Early Bird (leve_tot)

    @Test("Early Bird unlocks at 4 AM")
    func earlyBirdAt4AM() {
        let date4am = TestFixtures.date(daysOffset: 0, hour: 4)
        let ctx = TestFixtures.achievementContext(travelDates: [date4am])
        #expect(definition(id: "leve_tot").evaluate(ctx) == date4am)
    }

    @Test("Early Bird nil at 3 AM (below range)")
    func earlyBirdAt3AM() {
        let ctx = TestFixtures.achievementContext(
            travelDates: [TestFixtures.date(daysOffset: 0, hour: 3)]
        )
        #expect(definition(id: "leve_tot").evaluate(ctx) == nil)
    }

    @Test("Early Bird nil at 6 AM (above range)")
    func earlyBirdAt6AM() {
        let ctx = TestFixtures.achievementContext(
            travelDates: [TestFixtures.date(daysOffset: 0, hour: 6)]
        )
        #expect(definition(id: "leve_tot").evaluate(ctx) == nil)
    }

    @Test("Early Bird returns first match in array order (unsorted travelDates)")
    func earlyBirdUnsortedOrder() {
        // Day 5 at 5 AM appears first in array, day 0 at 5 AM second.
        // Since travelDates is iterated in order, day 5 is returned (not the earlier day 0).
        let day5 = TestFixtures.date(daysOffset: 5, hour: 5)
        let day0 = TestFixtures.date(daysOffset: 0, hour: 5)
        let ctx = TestFixtures.achievementContext(travelDates: [day5, day0])
        #expect(definition(id: "leve_tot").evaluate(ctx) == day5)
    }

    // MARK: - Winter is Coming (secret_winter_is_coming)

    @Test("Winter is Coming unlocks in December")
    func winterDecember() {
        var comps = DateComponents()
        comps.year = 2024
        comps.month = 12
        comps.day = 15
        comps.hour = 10
        let dec = Calendar.current.date(from: comps)!
        let ctx = TestFixtures.achievementContext(sortedTravelDates: [dec])
        #expect(definition(id: "secret_winter_is_coming").evaluate(ctx) == dec)
    }

    @Test("Winter is Coming unlocks in January")
    func winterJanuary() {
        // referenceDate is Jan 15 — month 1
        let ctx = TestFixtures.achievementContext(
            sortedTravelDates: [TestFixtures.referenceDate]
        )
        #expect(definition(id: "secret_winter_is_coming").evaluate(ctx) == TestFixtures.referenceDate)
    }

    @Test("Winter is Coming nil in February")
    func winterFebruary() {
        var comps = DateComponents()
        comps.year = 2025
        comps.month = 2
        comps.day = 10
        comps.hour = 10
        let feb = Calendar.current.date(from: comps)!
        let ctx = TestFixtures.achievementContext(sortedTravelDates: [feb])
        #expect(definition(id: "secret_winter_is_coming").evaluate(ctx) == nil)
    }

    // MARK: - Over 9000 (secret_over_9000)

    @Test("Over 9000 nil at exactly 9000 stations")
    func over9000AtExactly9000() {
        let dates = (0 ..< 9000).map { TestFixtures.date(daysOffset: $0) }
        let ctx = TestFixtures.achievementContext(nthUniqueStationDates: dates)
        #expect(definition(id: "secret_over_9000").evaluate(ctx) == nil)
    }

    @Test("Over 9000 unlocks at 9001 stations")
    func over9000At9001() {
        let dates = (0 ..< 9001).map { TestFixtures.date(daysOffset: $0) }
        let ctx = TestFixtures.achievementContext(nthUniqueStationDates: dates)
        #expect(definition(id: "secret_over_9000").evaluate(ctx) == dates[9000])
    }

    // MARK: - Centurion

    @Test("Centurion unlocks at exactly 100 travels")
    func centurionAt100() {
        let dates = (0 ..< 100).map { TestFixtures.date(daysOffset: $0) }
        let ctx = TestFixtures.achievementContext(sortedTravelDates: dates)
        #expect(definition(id: "centurion").evaluate(ctx) == dates[99])
    }

    @Test("Centurion nil at 99 travels")
    func centurionAt99() {
        let dates = (0 ..< 99).map { TestFixtures.date(daysOffset: $0) }
        let ctx = TestFixtures.achievementContext(sortedTravelDates: dates)
        #expect(definition(id: "centurion").evaluate(ctx) == nil)
    }
}
