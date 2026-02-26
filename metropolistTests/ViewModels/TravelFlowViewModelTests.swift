import SwiftUI
import Testing
import SwiftData
import TransitModels
@testable import metropolist

@Suite("TravelFlowViewModel", .tags(.viewModel, .travel))
@MainActor
struct TravelFlowViewModelTests {
    // MARK: - selectOrigin

    @Test("selectOrigin with single line auto-selects line")
    func selectOriginSingleLine() throws {
        let tCtx = TestSupport.makeTransitContext()
        let (_, _, stations) = TestSupport.seedCompleteLine(
            in: tCtx, lineSourceID: "METRO:1", stationNames: ["A", "B", "C"]
        )
        let store = AppDataStore(transitContext: tCtx, userContext: TestSupport.makeUserContext())
        let vm = TravelFlowViewModel(dataStore: store)

        vm.selectOrigin(stations[0])

        #expect(vm.originStation?.sourceID == stations[0].sourceID)
        #expect(vm.selectedLine?.sourceID == "METRO:1")
        #expect(vm.stationLines.count == 1)
        #expect(!vm.showError)
    }

    @Test("selectOrigin with multiple lines navigates to pickLine")
    func selectOriginMultipleLines() throws {
        let tCtx = TestSupport.makeTransitContext()
        let station = TestSupport.seedStation(in: tCtx, sourceID: "chatelet", name: "Chatelet")
        TestSupport.seedLine(in: tCtx, sourceID: "METRO:1", shortName: "1")
        TestSupport.seedLine(in: tCtx, sourceID: "METRO:4", shortName: "4")
        TestSupport.seedLineStop(in: tCtx, lineSourceID: "METRO:1", stationSourceID: "chatelet",
                                 routeVariantSourceID: "v1", order: 5)
        TestSupport.seedLineStop(in: tCtx, lineSourceID: "METRO:4", stationSourceID: "chatelet",
                                 routeVariantSourceID: "v4", order: 3)
        try tCtx.save()

        let store = AppDataStore(transitContext: tCtx, userContext: TestSupport.makeUserContext())
        let vm = TravelFlowViewModel(dataStore: store)

        vm.selectOrigin(station)

        #expect(vm.stationLines.count == 2)
        #expect(vm.selectedLine == nil)
        #expect(vm.originStation?.sourceID == "chatelet")
        #expect(!vm.showError)
    }

    @Test("selectOrigin with no lines shows error")
    func selectOriginNoLines() throws {
        let tCtx = TestSupport.makeTransitContext()
        let station = TestSupport.seedStation(in: tCtx, sourceID: "orphan", name: "Orphan")
        try tCtx.save()

        let store = AppDataStore(transitContext: tCtx, userContext: TestSupport.makeUserContext())
        let vm = TravelFlowViewModel(dataStore: store)

        vm.selectOrigin(station)

        #expect(vm.showError == true)
        #expect(vm.errorMessage != nil)
        #expect(vm.originStation == nil)
    }

    // MARK: - Prefill

    @Test("selectOrigin with prefill auto-selects matching line")
    func selectOriginWithPrefill() throws {
        let tCtx = TestSupport.makeTransitContext()
        let station = TestSupport.seedStation(in: tCtx, sourceID: "chatelet", name: "Chatelet")
        TestSupport.seedLine(in: tCtx, sourceID: "METRO:1", shortName: "1")
        TestSupport.seedLine(in: tCtx, sourceID: "METRO:4", shortName: "4")
        TestSupport.seedLineStop(in: tCtx, lineSourceID: "METRO:1", stationSourceID: "chatelet",
                                 routeVariantSourceID: "v1", order: 5)
        TestSupport.seedLineStop(in: tCtx, lineSourceID: "METRO:4", stationSourceID: "chatelet",
                                 routeVariantSourceID: "v4", order: 3)
        try tCtx.save()

        let prefill = TravelFlowPrefill(lineSourceID: "METRO:4", stationSourceID: nil)
        let store = AppDataStore(transitContext: tCtx, userContext: TestSupport.makeUserContext())
        let vm = TravelFlowViewModel(dataStore: store, prefill: prefill)

        vm.selectOrigin(station)

        // With prefill for METRO:4, should auto-select that line even though multiple lines exist
        #expect(vm.selectedLine?.sourceID == "METRO:4")
    }

    @Test("autoSelectOriginFromPrefill selects station")
    func autoSelectOriginFromPrefill() throws {
        let tCtx = TestSupport.makeTransitContext()
        let (_, _, stations) = TestSupport.seedCompleteLine(
            in: tCtx, lineSourceID: "METRO:1", stationNames: ["A", "B"]
        )
        let prefill = TravelFlowPrefill(
            lineSourceID: "METRO:1",
            stationSourceID: stations[0].sourceID
        )
        let store = AppDataStore(transitContext: tCtx, userContext: TestSupport.makeUserContext())
        let vm = TravelFlowViewModel(dataStore: store, prefill: prefill)

        vm.autoSelectOriginFromPrefill()

        #expect(vm.originStation?.sourceID == stations[0].sourceID)
        // Should also auto-select the line since prefill matches
        #expect(vm.selectedLine?.sourceID == "METRO:1")
    }

    @Test("autoSelectOriginFromPrefill does nothing without stationSourceID")
    func autoSelectOriginFromPrefillNoStation() {
        let tCtx = TestSupport.makeTransitContext()
        let prefill = TravelFlowPrefill(lineSourceID: "METRO:1", stationSourceID: nil)
        let store = AppDataStore(transitContext: tCtx, userContext: TestSupport.makeUserContext())
        let vm = TravelFlowViewModel(dataStore: store, prefill: prefill)

        vm.autoSelectOriginFromPrefill()

        #expect(vm.originStation == nil)
    }

    // MARK: - searchStations

    @Test("searchStations returns matching stations")
    func searchStations() throws {
        let tCtx = TestSupport.makeTransitContext()
        TestSupport.seedStation(in: tCtx, sourceID: "s1", name: "Chatelet")
        TestSupport.seedStation(in: tCtx, sourceID: "s2", name: "Nation")
        try tCtx.save()

        let store = AppDataStore(transitContext: tCtx, userContext: TestSupport.makeUserContext())
        let vm = TravelFlowViewModel(dataStore: store)

        let results = vm.searchStations(query: "chat")
        #expect(results.count == 1)
        #expect(results[0].name == "Chatelet")
    }

    @Test("searchStations returns empty for empty query")
    func searchStationsEmptyQuery() {
        let store = AppDataStore(
            transitContext: TestSupport.makeTransitContext(),
            userContext: TestSupport.makeUserContext()
        )
        let vm = TravelFlowViewModel(dataStore: store)
        #expect(vm.searchStations(query: "").isEmpty)
    }

    // MARK: - linesForStation

    @Test("linesForStation returns lines serving the station")
    func linesForStation() throws {
        let tCtx = TestSupport.makeTransitContext()
        TestSupport.seedLine(in: tCtx, sourceID: "METRO:1", shortName: "1")
        TestSupport.seedLineStop(in: tCtx, lineSourceID: "METRO:1", stationSourceID: "s1",
                                 routeVariantSourceID: "v1", order: 0)
        try tCtx.save()

        let store = AppDataStore(transitContext: tCtx, userContext: TestSupport.makeUserContext())
        let vm = TravelFlowViewModel(dataStore: store)

        let lines = vm.linesForStation("s1")
        #expect(lines.count == 1)
        #expect(lines[0].sourceID == "METRO:1")
    }

    // MARK: - formatDistance

    @Test("formatDistance renders meters for short distances")
    func formatDistanceMeters() {
        let result = TravelFlowViewModel.formatDistance(300)
        #expect(result.contains("m"))
        #expect(result.contains("300"))
    }

    @Test("formatDistance renders kilometers for long distances")
    func formatDistanceKilometers() {
        let result = TravelFlowViewModel.formatDistance(1500)
        #expect(result.contains("km"))
        #expect(result.contains("1.5"))
    }

    // MARK: - Initial state

    @Test("initial state has empty path and no selections")
    func initialState() {
        let store = AppDataStore(
            transitContext: TestSupport.makeTransitContext(),
            userContext: TestSupport.makeUserContext()
        )
        let vm = TravelFlowViewModel(dataStore: store)

        #expect(vm.path.count == 0)
        #expect(vm.originStation == nil)
        #expect(vm.selectedLine == nil)
        #expect(vm.destinationStation == nil)
        #expect(vm.selectedVariant == nil)
        #expect(vm.recordedTravel == nil)
        #expect(!vm.showError)
        #expect(!vm.isProcessing)
    }

    // MARK: - confirmTravel

    /// Creates a VM with all preconditions set for `confirmTravel()`.
    /// Line has 5 stations (A–E), origin=A, destination=E, intermediate stops populated.
    private static func makeConfirmReadyVM() -> (
        vm: TravelFlowViewModel, store: AppDataStore,
        line: TransitLine, stations: [TransitStation]
    ) {
        let tCtx = TestSupport.makeTransitContext()
        let uCtx = TestSupport.makeUserContext()
        let (line, variant, stations) = TestSupport.seedCompleteLine(
            in: tCtx, lineSourceID: "METRO:1", stationNames: ["A", "B", "C", "D", "E"]
        )
        let store = AppDataStore(transitContext: tCtx, userContext: uCtx)
        let vm = TravelFlowViewModel(dataStore: store)

        vm.originStation = stations[0]
        vm.destinationStation = stations[4]
        vm.selectedLine = line
        vm.selectedVariant = variant
        vm.loadIntermediateStops()

        return (vm, store, line, stations)
    }

    @Test("confirmTravel records travel and navigates to success")
    func confirmTravelRecordsTravel() {
        let (vm, _, line, stations) = Self.makeConfirmReadyVM()

        vm.confirmTravel()

        #expect(vm.recordedTravel != nil)
        #expect(vm.recordedTravel?.lineSourceID == line.sourceID)
        #expect(vm.recordedTravel?.fromStationSourceID == stations[0].sourceID)
        #expect(vm.recordedTravel?.toStationSourceID == stations[4].sourceID)
        #expect(vm.path.count == 1)
        #expect(!vm.isProcessing)
        #expect(!vm.showError)
    }

    @Test("confirmTravel counts new stops correctly")
    func confirmTravelCountsNewStops() {
        let (vm, _, _, _) = Self.makeConfirmReadyVM()

        vm.confirmTravel()

        // 5 stations (A–E), all inclusive — all new on first travel
        #expect(vm.newStopsCompleted == 5)
    }

    @Test("confirmTravel with pre-existing stops counts only new ones")
    func confirmTravelCountsOnlyNewStops() throws {
        let (vm, store, _, stations) = Self.makeConfirmReadyVM()

        // Pre-record stops A, B, C on this line
        try store.userService.recordTravel(
            lineSourceID: "METRO:1",
            routeVariantSourceID: "METRO:1:v1",
            fromStationSourceID: stations[0].sourceID,
            toStationSourceID: stations[2].sourceID,
            intermediateStationSourceIDs: [
                stations[0].sourceID, stations[1].sourceID, stations[2].sourceID,
            ]
        )

        vm.confirmTravel()

        // Only D and E are new
        #expect(vm.newStopsCompleted == 2)
    }

    @Test("confirmTravel produces celebration event with XP")
    func confirmTravelProducesCelebration() {
        let (vm, _, _, _) = Self.makeConfirmReadyVM()

        vm.confirmTravel()

        #expect(vm.celebrationEvent != nil)
        #expect(vm.celebrationEvent!.xpGained > 0)
        let kinds = vm.celebrationEvent!.xpItems.map(\.kind)
        #expect(kinds.contains(.baseTravel))
        #expect(kinds.contains(.discoveryBonus))
    }

    @Test("confirmTravel increments userDataVersion")
    func confirmTravelIncrementsVersion() {
        let (vm, store, _, _) = Self.makeConfirmReadyVM()
        let before = store.userDataVersion

        vm.confirmTravel()

        #expect(store.userDataVersion == before + 1)
    }

    @Test("confirmTravel with missing preconditions does nothing")
    func confirmTravelMissingPreconditions() {
        let store = AppDataStore(
            transitContext: TestSupport.makeTransitContext(),
            userContext: TestSupport.makeUserContext()
        )
        let vm = TravelFlowViewModel(dataStore: store)

        vm.confirmTravel()

        #expect(vm.recordedTravel == nil)
        #expect(vm.path.count == 0)
        #expect(!vm.isProcessing)
    }

    // MARK: - Branching line destinations

    /// Seeds a Y-shaped line mimicking Line 13:
    ///
    ///     Branch A:  A0 ─ A1 ─ A2 ─┐
    ///                                Junction ─ Trunk1 ─ Trunk2 ─ Terminus
    ///     Branch B:  B0 ─ B1 ─ B2 ─┘
    ///
    /// Direction 0: short variant covering only branch A → Junction
    /// Direction 1: full variant covering Terminus → Trunk2 → Trunk1 → Junction → A2 → A1 → A0
    /// Direction 1: full variant covering Terminus → Trunk2 → Trunk1 → Junction → B2 → B1 → B0
    private static func makeBranchingLine(
        in context: ModelContext
    ) -> (line: TransitLine, branchAStations: [TransitStation], branchBStations: [TransitStation],
          trunkStations: [TransitStation])
    {
        let line = TestSupport.seedLine(in: context, sourceID: "METRO:13", shortName: "13")

        // Shared trunk stations
        let junction = TestSupport.seedStation(in: context, sourceID: "junction", name: "Junction")
        let trunk1 = TestSupport.seedStation(in: context, sourceID: "trunk1", name: "Trunk1")
        let trunk2 = TestSupport.seedStation(in: context, sourceID: "trunk2", name: "Trunk2")
        let terminus = TestSupport.seedStation(in: context, sourceID: "terminus", name: "Terminus")

        // Branch A stations
        let a0 = TestSupport.seedStation(in: context, sourceID: "a0", name: "A0")
        let a1 = TestSupport.seedStation(in: context, sourceID: "a1", name: "A1")
        let a2 = TestSupport.seedStation(in: context, sourceID: "a2", name: "A2")

        // Branch B stations
        let b0 = TestSupport.seedStation(in: context, sourceID: "b0", name: "B0")
        let b1 = TestSupport.seedStation(in: context, sourceID: "b1", name: "B1")
        let b2 = TestSupport.seedStation(in: context, sourceID: "b2", name: "B2")

        // Direction 0: short variant, branch A only → Junction
        let shortVariant = TestSupport.seedRouteVariant(
            in: context, sourceID: "METRO:13:0:junction", lineSourceID: "METRO:13",
            direction: 0, headsign: "Junction", stationCount: 4
        )
        for (order, sid) in ["a0", "a1", "a2", "junction"].enumerated() {
            TestSupport.seedLineStop(in: context, lineSourceID: "METRO:13", stationSourceID: sid,
                                     routeVariantSourceID: shortVariant.sourceID, order: order)
        }

        // Direction 1: full variant, Terminus → branch A
        let fullVariantA = TestSupport.seedRouteVariant(
            in: context, sourceID: "METRO:13:1:a0", lineSourceID: "METRO:13",
            direction: 1, headsign: "A0", stationCount: 7
        )
        for (order, sid) in ["terminus", "trunk2", "trunk1", "junction", "a2", "a1", "a0"].enumerated() {
            TestSupport.seedLineStop(in: context, lineSourceID: "METRO:13", stationSourceID: sid,
                                     routeVariantSourceID: fullVariantA.sourceID, order: order)
        }

        // Direction 1: full variant, Terminus → branch B
        let fullVariantB = TestSupport.seedRouteVariant(
            in: context, sourceID: "METRO:13:1:b0", lineSourceID: "METRO:13",
            direction: 1, headsign: "B0", stationCount: 7
        )
        for (order, sid) in ["terminus", "trunk2", "trunk1", "junction", "b2", "b1", "b0"].enumerated() {
            TestSupport.seedLineStop(in: context, lineSourceID: "METRO:13", stationSourceID: sid,
                                     routeVariantSourceID: fullVariantB.sourceID, order: order)
        }

        try! context.save()

        return (line, [a0, a1, a2], [b0, b1, b2], [junction, trunk1, trunk2, terminus])
    }

    @Test("loadDestinationOptions includes upstream trunk stations on branching line")
    func branchingLineIncludesUpstreamStations() throws {
        let tCtx = TestSupport.makeTransitContext()
        let (line, branchA, _, _) = Self.makeBranchingLine(in: tCtx)
        let store = AppDataStore(transitContext: tCtx, userContext: TestSupport.makeUserContext())
        let vm = TravelFlowViewModel(dataStore: store)

        // Origin is on branch A (like Mairie de Clichy)
        vm.originStation = branchA[1] // A1
        vm.selectedLine = line
        let options = try vm.loadDestinationOptions(for: line)
        let destinationIDs = Set(options.map(\.station.sourceID))

        // Should include branch A neighbors
        #expect(destinationIDs.contains("a0"))
        #expect(destinationIDs.contains("a2"))
        // Should include the junction
        #expect(destinationIDs.contains("junction"))
        // Should include trunk stations (upstream on full variant)
        #expect(destinationIDs.contains("trunk1"))
        #expect(destinationIDs.contains("trunk2"))
        #expect(destinationIDs.contains("terminus"))
        // Should NOT include branch B stations (A1 is not on that variant)
        #expect(!destinationIDs.contains("b0"))
        #expect(!destinationIDs.contains("b1"))
        #expect(!destinationIDs.contains("b2"))
    }

    @Test("loadDestinationOptions sorts by distance from origin")
    func branchingLineDistanceSorting() throws {
        let tCtx = TestSupport.makeTransitContext()
        let (line, branchA, _, _) = Self.makeBranchingLine(in: tCtx)
        let store = AppDataStore(transitContext: tCtx, userContext: TestSupport.makeUserContext())
        let vm = TravelFlowViewModel(dataStore: store)

        vm.originStation = branchA[1] // A1, order 5 on full variant (a0=6, a2=4, junction=3...)
        vm.selectedLine = line
        let options = try vm.loadDestinationOptions(for: line)

        // First destinations should be closest neighbors (distance 1)
        let firstTwo = Set(options.prefix(2).map(\.station.sourceID))
        #expect(firstTwo.contains("a0") || firstTwo.contains("a2"))
    }

    @Test("loadIntermediateStops works in reverse direction on branching line")
    func branchingLineReverseIntermediateStops() throws {
        let tCtx = TestSupport.makeTransitContext()
        let (line, branchA, _, trunkStations) = Self.makeBranchingLine(in: tCtx)
        let store = AppDataStore(transitContext: tCtx, userContext: TestSupport.makeUserContext())
        let vm = TravelFlowViewModel(dataStore: store)

        // Travel from A1 (branch) to Terminus (trunk) — reverse direction on the full variant
        vm.originStation = branchA[1]
        vm.destinationStation = trunkStations[3] // Terminus
        vm.selectedLine = line
        vm.selectedVariant = TransitRouteVariant(
            sourceID: "METRO:13:1:a0", lineSourceID: "METRO:13",
            direction: 1, headsign: "A0", stationCount: 7
        )
        // We need to use the variant from the context
        let variants = try store.transitService.routeVariants(forLineSourceID: "METRO:13")
        vm.selectedVariant = variants.first { $0.sourceID == "METRO:13:1:a0" }

        vm.loadIntermediateStops()

        let stopIDs = vm.intermediateStops.map(\.stationSourceID)
        // Should include all stops from A1 to Terminus: A1, A2, Junction, Trunk1, Trunk2, Terminus
        #expect(stopIDs.count == 6)
        // First stop should be origin (A1), last should be destination (Terminus)
        #expect(stopIDs.first == "a1")
        #expect(stopIDs.last == "terminus")
        // Intermediate order: A1 → A2 → Junction → Trunk1 → Trunk2 → Terminus
        #expect(stopIDs[1] == "a2")
        #expect(stopIDs[2] == "junction")
        #expect(stopIDs[3] == "trunk1")
        #expect(stopIDs[4] == "trunk2")
    }

    @Test("buildVariantPreview works in reverse direction")
    func branchingLineReverseVariantPreview() throws {
        let tCtx = TestSupport.makeTransitContext()
        let (line, branchA, _, trunkStations) = Self.makeBranchingLine(in: tCtx)
        let store = AppDataStore(transitContext: tCtx, userContext: TestSupport.makeUserContext())
        let vm = TravelFlowViewModel(dataStore: store)

        vm.originStation = branchA[1] // A1
        vm.destinationStation = trunkStations[3] // Terminus
        vm.selectedLine = line

        let variants = try store.transitService.routeVariants(forLineSourceID: "METRO:13")
        let fullVariant = variants.first { $0.sourceID == "METRO:13:1:a0" }!
        let preview = vm.buildVariantPreview(fullVariant)

        #expect(preview != nil)
        #expect(preview!.totalStops == 6)
        // Via stations should be A2, Junction, Trunk1, Trunk2 (between A1 and Terminus)
        #expect(preview!.viaStationNames.count == 4)
        #expect(preview!.viaStationNames[0] == "A2")
        #expect(preview!.viaStationNames[1] == "Junction")
        #expect(preview!.viaStationNames[2] == "Trunk1")
        #expect(preview!.viaStationNames[3] == "Trunk2")
    }
}
