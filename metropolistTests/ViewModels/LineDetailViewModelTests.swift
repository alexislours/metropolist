import Testing
import SwiftData
import TransitModels
@testable import metropolist

@Suite("LineDetailViewModel", .tags(.viewModel))
@MainActor
struct LineDetailViewModelTests {
    // MARK: - loadData

    @Test("loadData populates line, variants, and stations")
    func loadData() async throws {
        let tCtx = TestSupport.makeTransitContext()
        let uCtx = TestSupport.makeUserContext()
        TestSupport.seedCompleteLine(
            in: tCtx, lineSourceID: "METRO:1", shortName: "1",
            stationNames: ["A", "B", "C", "D"]
        )
        let store = AppDataStore(transitContext: tCtx, userContext: uCtx)

        let vm = LineDetailViewModel(lineSourceID: "METRO:1", dataStore: store)
        await vm.loadData()

        #expect(vm.line?.sourceID == "METRO:1")
        #expect(vm.line?.shortName == "1")
        #expect(vm.variants.count == 1)
        #expect(vm.totalStations == 4)
        #expect(vm.stationsMap.count == 4)
        #expect(vm.travelCount == 0)
        #expect(vm.lastTravelDate == nil)
    }

    @Test("loadData reflects completed stops from user service")
    func loadDataWithCompletions() async throws {
        let tCtx = TestSupport.makeTransitContext()
        let uCtx = TestSupport.makeUserContext()
        let (_, variant, stations) = TestSupport.seedCompleteLine(
            in: tCtx, lineSourceID: "METRO:1", stationNames: ["A", "B", "C"]
        )
        let store = AppDataStore(transitContext: tCtx, userContext: uCtx)

        try store.userService.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: variant.sourceID,
            fromStationSourceID: stations[0].sourceID,
            toStationSourceID: stations[1].sourceID,
            intermediateStationSourceIDs: [stations[0].sourceID, stations[1].sourceID]
        )

        let vm = LineDetailViewModel(lineSourceID: "METRO:1", dataStore: store)
        await vm.loadData()

        #expect(vm.completedStopIDs.count == 2)
        #expect(vm.travelCount == 1)
        #expect(vm.lastTravelDate != nil)
        #expect(vm.recentTravels.count == 1)
    }

    @Test("loadData populates connecting lines map")
    func loadDataConnectingLines() async throws {
        let tCtx = TestSupport.makeTransitContext()
        let uCtx = TestSupport.makeUserContext()
        // Line 1 has station "shared"
        TestSupport.seedLine(in: tCtx, sourceID: "METRO:1", shortName: "1")
        TestSupport.seedLine(in: tCtx, sourceID: "METRO:4", shortName: "4")
        let variant = TestSupport.seedRouteVariant(
            in: tCtx, sourceID: "METRO:1:v1", lineSourceID: "METRO:1", stationCount: 2
        )
        TestSupport.seedStation(in: tCtx, sourceID: "shared", name: "Shared")
        TestSupport.seedStation(in: tCtx, sourceID: "only1", name: "Only1")
        TestSupport.seedLineStop(in: tCtx, lineSourceID: "METRO:1", stationSourceID: "shared",
                                 routeVariantSourceID: variant.sourceID, order: 0)
        TestSupport.seedLineStop(in: tCtx, lineSourceID: "METRO:1", stationSourceID: "only1",
                                 routeVariantSourceID: variant.sourceID, order: 1)
        // Line 4 also serves "shared"
        TestSupport.seedLineStop(in: tCtx, lineSourceID: "METRO:4", stationSourceID: "shared",
                                 routeVariantSourceID: "METRO:4:v1", order: 0)
        try tCtx.save()

        let store = AppDataStore(transitContext: tCtx, userContext: uCtx)
        let vm = LineDetailViewModel(lineSourceID: "METRO:1", dataStore: store)
        await vm.loadData()

        // "shared" should have METRO:4 as connecting line (METRO:1 excluded)
        let connecting = vm.connectingLinesMap["shared"]
        #expect(connecting?.count == 1)
        #expect(connecting?.first?.sourceID == "METRO:4")
    }

    // MARK: - refresh

    @Test("refresh updates completion and travel data after new travel")
    func refresh() async throws {
        let tCtx = TestSupport.makeTransitContext()
        let uCtx = TestSupport.makeUserContext()
        let (_, variant, stations) = TestSupport.seedCompleteLine(
            in: tCtx, lineSourceID: "METRO:1", stationNames: ["A", "B", "C"]
        )
        let store = AppDataStore(transitContext: tCtx, userContext: uCtx)

        let vm = LineDetailViewModel(lineSourceID: "METRO:1", dataStore: store)
        await vm.loadData()
        #expect(vm.travelCount == 0)
        #expect(vm.completedStopIDs.isEmpty)

        // Record a travel after initial load
        try store.userService.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: variant.sourceID,
            fromStationSourceID: stations[0].sourceID,
            toStationSourceID: stations[2].sourceID,
            intermediateStationSourceIDs: stations.map { $0.sourceID }
        )

        vm.refresh()

        #expect(vm.travelCount == 1)
        #expect(vm.completedStopIDs.count == 3)
        #expect(vm.recentTravels.count == 1)
        #expect(vm.lastTravelDate != nil)
    }

    // MARK: - selectedVariant

    @Test("selectedVariant reflects selectedVariantIndex")
    func selectedVariant() async throws {
        let tCtx = TestSupport.makeTransitContext()
        let uCtx = TestSupport.makeUserContext()

        // Seed line with two variants
        TestSupport.seedLine(in: tCtx, sourceID: "METRO:1", shortName: "1")
        TestSupport.seedRouteVariant(in: tCtx, sourceID: "v1", lineSourceID: "METRO:1",
                                     direction: 0, headsign: "West")
        TestSupport.seedRouteVariant(in: tCtx, sourceID: "v2", lineSourceID: "METRO:1",
                                     direction: 1, headsign: "East")
        TestSupport.seedStation(in: tCtx, sourceID: "s0", name: "A")
        TestSupport.seedLineStop(in: tCtx, lineSourceID: "METRO:1", stationSourceID: "s0",
                                 routeVariantSourceID: "v1", order: 0)
        TestSupport.seedLineStop(in: tCtx, lineSourceID: "METRO:1", stationSourceID: "s0",
                                 routeVariantSourceID: "v2", order: 0)
        try tCtx.save()

        let store = AppDataStore(transitContext: tCtx, userContext: uCtx)
        let vm = LineDetailViewModel(lineSourceID: "METRO:1", dataStore: store)
        await vm.loadData()

        #expect(vm.variants.count == 2)
        #expect(vm.selectedVariantIndex == 0)
        #expect(vm.selectedVariant?.sourceID == vm.variants[0].sourceID)

        vm.selectedVariantIndex = 1
        #expect(vm.selectedVariant?.sourceID == vm.variants[1].sourceID)
    }
}
