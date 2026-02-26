import Testing
import SwiftData
import TransitModels
@testable import metropolist

@Suite("ProfileViewModel", .tags(.viewModel))
@MainActor
struct ProfileViewModelTests {
    // MARK: - load

    @Test("load populates snapshot and display data")
    func loadPopulates() async throws {
        let tCtx = TestSupport.makeTransitContext()
        let uCtx = TestSupport.makeUserContext()
        let (_, variant, stations) = TestSupport.seedCompleteLine(
            in: tCtx, lineSourceID: "METRO:1", shortName: "1", mode: "metro",
            stationNames: ["A", "B", "C"]
        )
        let store = AppDataStore(transitContext: tCtx, userContext: uCtx)

        try store.userService.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: variant.sourceID,
            fromStationSourceID: stations[0].sourceID,
            toStationSourceID: stations[2].sourceID,
            intermediateStationSourceIDs: stations.map { $0.sourceID }
        )

        let vm = ProfileViewModel(dataStore: store)
        await vm.load()

        #expect(!vm.isLoading)
        #expect(vm.snapshot.stats.totalTravels == 1)
        #expect(vm.snapshot.stats.totalStationsVisited == 3)
        #expect(!vm.lineMetadataMap.isEmpty)
        #expect(!vm.linesByMode.isEmpty)
        #expect(vm.recentTravels.count == 1)
    }

    @Test("load with no data produces empty snapshot")
    func loadEmpty() async {
        let store = AppDataStore(
            transitContext: TestSupport.makeTransitContext(),
            userContext: TestSupport.makeUserContext()
        )
        let vm = ProfileViewModel(dataStore: store)
        await vm.load()

        #expect(!vm.isLoading)
        #expect(vm.snapshot.stats.totalTravels == 0)
        #expect(vm.recentTravels.isEmpty)
        #expect(vm.modeBreakdown.isEmpty)
    }

    // MARK: - modeBreakdown

    @Test("modeBreakdown reflects travel distribution across modes")
    func modeBreakdown() async throws {
        let tCtx = TestSupport.makeTransitContext()
        let uCtx = TestSupport.makeUserContext()
        let (_, mv, ms) = TestSupport.seedCompleteLine(
            in: tCtx, lineSourceID: "METRO:1", shortName: "1", mode: "metro",
            stationNames: ["A", "B"]
        )
        let (_, bv, bs) = TestSupport.seedCompleteLine(
            in: tCtx, lineSourceID: "BUS:42", shortName: "42", mode: "bus",
            stationNames: ["X", "Y"]
        )

        let store = AppDataStore(transitContext: tCtx, userContext: uCtx)

        // 2 metro travels, 1 bus travel
        try store.userService.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: mv.sourceID,
            fromStationSourceID: ms[0].sourceID, toStationSourceID: ms[1].sourceID,
            intermediateStationSourceIDs: []
        )
        try store.userService.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: mv.sourceID,
            fromStationSourceID: ms[0].sourceID, toStationSourceID: ms[1].sourceID,
            intermediateStationSourceIDs: []
        )
        try store.userService.recordTravel(
            lineSourceID: "BUS:42", routeVariantSourceID: bv.sourceID,
            fromStationSourceID: bs[0].sourceID, toStationSourceID: bs[1].sourceID,
            intermediateStationSourceIDs: []
        )

        let vm = ProfileViewModel(dataStore: store)
        await vm.load()

        #expect(vm.modeBreakdown.count == 2)
        let metroEntry = vm.modeBreakdown.first { $0.mode == .metro }
        #expect(metroEntry?.count == 2)
        let busEntry = vm.modeBreakdown.first { $0.mode == .bus }
        #expect(busEntry?.count == 1)
    }

    // MARK: - travelSearchIndex

    @Test("travelSearchIndex contains line, station, and mode names")
    func searchIndex() async throws {
        let tCtx = TestSupport.makeTransitContext()
        let uCtx = TestSupport.makeUserContext()
        let (_, variant, stations) = TestSupport.seedCompleteLine(
            in: tCtx, lineSourceID: "METRO:1", shortName: "1",
            stationNames: ["Chatelet", "Nation"]
        )
        let store = AppDataStore(transitContext: tCtx, userContext: uCtx)
        let travel = try store.userService.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: variant.sourceID,
            fromStationSourceID: stations[0].sourceID,
            toStationSourceID: stations[1].sourceID,
            intermediateStationSourceIDs: []
        )

        let vm = ProfileViewModel(dataStore: store)
        await vm.load()

        let index = try #require(vm.travelSearchIndex[travel.id])
        #expect(index.contains("chatelet"))
        #expect(index.contains("nation"))
        #expect(index.contains("1"))
    }

    // MARK: - stationNames resolution

    @Test("stationNames resolves from and to station names")
    func stationNamesResolution() async throws {
        let tCtx = TestSupport.makeTransitContext()
        let uCtx = TestSupport.makeUserContext()
        let (_, variant, stations) = TestSupport.seedCompleteLine(
            in: tCtx, lineSourceID: "METRO:1", shortName: "1",
            stationNames: ["Chatelet", "Nation"]
        )
        let store = AppDataStore(transitContext: tCtx, userContext: uCtx)
        try store.userService.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: variant.sourceID,
            fromStationSourceID: stations[0].sourceID,
            toStationSourceID: stations[1].sourceID,
            intermediateStationSourceIDs: []
        )

        let vm = ProfileViewModel(dataStore: store)
        await vm.load()

        #expect(vm.stationNames[stations[0].sourceID] == "Chatelet")
        #expect(vm.stationNames[stations[1].sourceID] == "Nation")
    }
}
