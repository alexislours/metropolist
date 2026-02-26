import Testing
import SwiftData
import TransitModels
@testable import metropolist

@Suite("DataStore", .tags(.dataStore))
@MainActor
struct DataStoreTests {
    private func makeSUT() -> (store: AppDataStore, transitCtx: ModelContext, userCtx: ModelContext) {
        let tCtx = TestSupport.makeTransitContext()
        let uCtx = TestSupport.makeUserContext()
        let store = AppDataStore(transitContext: tCtx, userContext: uCtx)
        return (store, tCtx, uCtx)
    }

    // MARK: - stationCountsByLine

    @Test("stationCountsByLine returns correct counts")
    func stationCountsByLine() throws {
        let (store, tCtx, _) = makeSUT()
        TestSupport.seedCompleteLine(in: tCtx, lineSourceID: "METRO:1",
                                     stationNames: ["A", "B", "C"])

        let counts = try store.stationCountsByLine()
        #expect(counts["METRO:1"] == 3)
    }

    @Test("stationCountsByLine caches after first call")
    func stationCountsCaching() throws {
        let (store, tCtx, _) = makeSUT()
        TestSupport.seedCompleteLine(in: tCtx, lineSourceID: "METRO:1",
                                     stationNames: ["A", "B", "C"])

        let first = try store.stationCountsByLine()
        #expect(first["METRO:1"] == 3)

        // Add more stops — cache should still return 3
        TestSupport.seedLineStop(in: tCtx, lineSourceID: "METRO:1", stationSourceID: "extra",
                                 routeVariantSourceID: "METRO:1:v1", order: 99)
        try tCtx.save()

        let cached = try store.stationCountsByLine()
        #expect(cached["METRO:1"] == 3)
    }

    // MARK: - allLineMetadata

    @Test("allLineMetadata builds metadata with correct fields")
    func allLineMetadata() throws {
        let (store, tCtx, _) = makeSUT()
        TestSupport.seedCompleteLine(in: tCtx, lineSourceID: "METRO:1", shortName: "1",
                                     stationNames: ["A", "B"])

        let meta = try store.allLineMetadata()
        let m1 = try #require(meta["METRO:1"])
        #expect(m1.shortName == "1")
        #expect(m1.mode == TransitMode.metro)
        #expect(m1.totalStations == 2)
    }

    @Test("allLineMetadata caches result")
    func allLineMetadataCaching() throws {
        let (store, tCtx, _) = makeSUT()
        TestSupport.seedCompleteLine(in: tCtx, lineSourceID: "METRO:1",
                                     stationNames: ["A"])

        let first = try store.allLineMetadata()
        #expect(first.count == 1)

        // Insert another line — cache should still have count 1
        TestSupport.seedCompleteLine(in: tCtx, lineSourceID: "METRO:2", shortName: "2",
                                     stationNames: ["X"])
        let cached = try store.allLineMetadata()
        #expect(cached.count == 1)
    }

    // MARK: - deleteTravelCascading

    @Test("deleteTravelCascading deletes travel and orphaned stops")
    func deleteTravelCascadingOrphans() throws {
        let (store, tCtx, _) = makeSUT()
        let (_, variant, stations) = TestSupport.seedCompleteLine(
            in: tCtx, lineSourceID: "METRO:1", stationNames: ["A", "B", "C"]
        )

        let stationIDs = stations.map { $0.sourceID }
        let travel = try store.userService.recordTravel(
            lineSourceID: "METRO:1",
            routeVariantSourceID: variant.sourceID,
            fromStationSourceID: stations[0].sourceID,
            toStationSourceID: stations[2].sourceID,
            intermediateStationSourceIDs: stationIDs
        )
        #expect(try store.userService.allTravels().count == 1)

        try store.deleteTravelCascading(id: travel.id)

        #expect(try store.userService.allTravels().count == 0)
        #expect(try store.userService.completedStopIDs(forLineSourceID: "METRO:1").isEmpty)
    }

    @Test("deleteTravelCascading reassigns stops covered by another travel")
    func deleteTravelCascadingReassign() throws {
        let (store, tCtx, _) = makeSUT()
        let (_, variant, stations) = TestSupport.seedCompleteLine(
            in: tCtx, lineSourceID: "METRO:1", stationNames: ["A", "B", "C", "D", "E"]
        )

        // Travel 1: A -> C (covers A, B, C)
        let t1 = try store.userService.recordTravel(
            lineSourceID: "METRO:1",
            routeVariantSourceID: variant.sourceID,
            fromStationSourceID: stations[0].sourceID,
            toStationSourceID: stations[2].sourceID,
            intermediateStationSourceIDs: [stations[0].sourceID, stations[1].sourceID, stations[2].sourceID]
        )

        // Travel 2: B -> D (covers B, C, D)
        try store.userService.recordTravel(
            lineSourceID: "METRO:1",
            routeVariantSourceID: variant.sourceID,
            fromStationSourceID: stations[1].sourceID,
            toStationSourceID: stations[3].sourceID,
            intermediateStationSourceIDs: [stations[1].sourceID, stations[2].sourceID, stations[3].sourceID]
        )

        // Delete travel 1 — B and C should be reassigned, A should be deleted
        try store.deleteTravelCascading(id: t1.id)

        #expect(try store.userService.allTravels().count == 1)
        let remaining = try store.userService.completedStopIDs(forLineSourceID: "METRO:1")
        #expect(remaining.contains(stations[1].sourceID)) // B reassigned
        #expect(remaining.contains(stations[2].sourceID)) // C reassigned
        #expect(remaining.contains(stations[3].sourceID)) // D from t2
        #expect(!remaining.contains(stations[0].sourceID)) // A orphaned and deleted
    }

    @Test("deleteTravelCascading with unknown ID does nothing")
    func deleteTravelCascadingUnknown() throws {
        let (store, _, _) = makeSUT()
        try store.deleteTravelCascading(id: "nonexistent")
        // No crash, no error
    }

    // MARK: - travelsPassingThrough

    @Test("travelsPassingThrough returns travel that includes the station")
    func travelsPassingThrough() throws {
        let (store, tCtx, _) = makeSUT()
        let (_, variant, stations) = TestSupport.seedCompleteLine(
            in: tCtx, lineSourceID: "METRO:1", stationNames: ["A", "B", "C", "D", "E"]
        )

        // Travel from A to D
        try store.userService.recordTravel(
            lineSourceID: "METRO:1",
            routeVariantSourceID: variant.sourceID,
            fromStationSourceID: stations[0].sourceID,
            toStationSourceID: stations[3].sourceID,
            intermediateStationSourceIDs: []
        )

        // Station B (order 1) is between A (order 0) and D (order 3)
        let passingB = try store.travelsPassingThrough(stationSourceID: stations[1].sourceID)
        #expect(passingB.count == 1)

        // Station E (order 4) is outside A-D range
        let passingE = try store.travelsPassingThrough(stationSourceID: stations[4].sourceID)
        #expect(passingE.count == 0)
    }

    @Test("travelsPassingThrough returns empty for station with no line stops")
    func travelsPassingThroughNoStops() throws {
        let (store, _, _) = makeSUT()
        let result = try store.travelsPassingThrough(stationSourceID: "nonexistent")
        #expect(result.isEmpty)
    }

    // MARK: - userDataVersion

    @Test("userDataVersion starts at zero")
    func userDataVersionInitial() {
        let (store, _, _) = makeSUT()
        #expect(store.userDataVersion == 0)
    }
}
