import Testing
import SwiftData
import TransitModels
@testable import metropolist

@Suite("TransitDataService", .tags(.services))
@MainActor
struct TransitDataServiceTests {
    private func makeSUT() -> (service: TransitDataService, context: ModelContext) {
        let ctx = TestSupport.makeTransitContext()
        return (TransitDataService(context: ctx), ctx)
    }

    // MARK: - allLines

    @Test("allLines returns lines sorted by shortName")
    func allLinesSorted() throws {
        let (sut, ctx) = makeSUT()
        TestSupport.seedLine(in: ctx, sourceID: "METRO:4", shortName: "4")
        TestSupport.seedLine(in: ctx, sourceID: "METRO:1", shortName: "1")
        TestSupport.seedLine(in: ctx, sourceID: "METRO:12", shortName: "12")
        try ctx.save()

        let lines = try sut.allLines()
        #expect(lines.count == 3)
        #expect(lines[0].shortName == "1")
    }

    // MARK: - line(bySourceID:)

    @Test("line(bySourceID:) fetches matching line")
    func lineBySourceID() throws {
        let (sut, ctx) = makeSUT()
        TestSupport.seedLine(in: ctx, sourceID: "METRO:7", shortName: "7")
        try ctx.save()

        let line = try sut.line(bySourceID: "METRO:7")
        #expect(line?.shortName == "7")
    }

    @Test("line(bySourceID:) returns nil for unknown ID")
    func lineBySourceIDNotFound() throws {
        let (sut, _) = makeSUT()
        #expect(try sut.line(bySourceID: "UNKNOWN") == nil)
    }

    // MARK: - routeVariants

    @Test("routeVariants returns variants for a line")
    func routeVariantsForLine() throws {
        let (sut, ctx) = makeSUT()
        TestSupport.seedRouteVariant(in: ctx, sourceID: "v1", lineSourceID: "METRO:1",
                                     direction: 0, headsign: "La Defense")
        TestSupport.seedRouteVariant(in: ctx, sourceID: "v2", lineSourceID: "METRO:1",
                                     direction: 1, headsign: "Vincennes")
        TestSupport.seedRouteVariant(in: ctx, sourceID: "v3", lineSourceID: "METRO:2",
                                     direction: 0, headsign: "Nation")
        try ctx.save()

        let variants = try sut.routeVariants(forLineSourceID: "METRO:1")
        #expect(variants.count == 2)
    }

    // MARK: - lineStops ordering

    @Test("lineStops returns stops sorted by order")
    func lineStopsSorted() throws {
        let (sut, ctx) = makeSUT()
        TestSupport.seedLineStop(in: ctx, lineSourceID: "METRO:1", stationSourceID: "s2",
                                 routeVariantSourceID: "v1", order: 2)
        TestSupport.seedLineStop(in: ctx, lineSourceID: "METRO:1", stationSourceID: "s0",
                                 routeVariantSourceID: "v1", order: 0)
        TestSupport.seedLineStop(in: ctx, lineSourceID: "METRO:1", stationSourceID: "s1",
                                 routeVariantSourceID: "v1", order: 1)
        try ctx.save()

        let stops = try sut.lineStops(forRouteVariantSourceID: "v1")
        #expect(stops.count == 3)
        #expect(stops[0].order == 0)
        #expect(stops[1].order == 1)
        #expect(stops[2].order == 2)
    }

    // MARK: - uniqueStationCountsByLine

    @Test("uniqueStationCountsByLine deduplicates stations across variants")
    func uniqueStationCounts() throws {
        let (sut, ctx) = makeSUT()
        // Two variants share station s1
        TestSupport.seedLineStop(in: ctx, lineSourceID: "METRO:1", stationSourceID: "s0",
                                 routeVariantSourceID: "v1", order: 0)
        TestSupport.seedLineStop(in: ctx, lineSourceID: "METRO:1", stationSourceID: "s1",
                                 routeVariantSourceID: "v1", order: 1)
        TestSupport.seedLineStop(in: ctx, lineSourceID: "METRO:1", stationSourceID: "s1",
                                 routeVariantSourceID: "v2", order: 0)
        TestSupport.seedLineStop(in: ctx, lineSourceID: "METRO:1", stationSourceID: "s2",
                                 routeVariantSourceID: "v2", order: 1)
        try ctx.save()

        let counts = try sut.uniqueStationCountsByLine()
        #expect(counts["METRO:1"] == 3) // s0, s1, s2
    }

    // MARK: - station

    @Test("station(bySourceID:) returns matching station")
    func stationBySourceID() throws {
        let (sut, ctx) = makeSUT()
        TestSupport.seedStation(in: ctx, sourceID: "st-1", name: "Chatelet")
        try ctx.save()

        let station = try sut.station(bySourceID: "st-1")
        #expect(station?.name == "Chatelet")
    }

    @Test("station(bySourceID:) returns nil for unknown ID")
    func stationBySourceIDNotFound() throws {
        let (sut, _) = makeSUT()
        #expect(try sut.station(bySourceID: "UNKNOWN") == nil)
    }

    // MARK: - searchStations

    @Test("searchStations returns matching stations")
    func searchStations() throws {
        let (sut, ctx) = makeSUT()
        TestSupport.seedStation(in: ctx, sourceID: "st-1", name: "Chatelet")
        TestSupport.seedStation(in: ctx, sourceID: "st-2", name: "Nation")
        TestSupport.seedStation(in: ctx, sourceID: "st-3", name: "Chatillon")
        try ctx.save()

        let results = try sut.searchStations(query: "chat")
        #expect(results.count == 2)
    }

    // MARK: - nearbyStations

    @Test("nearbyStations filters by geographic bounding box")
    func nearbyStations() throws {
        let (sut, ctx) = makeSUT()
        TestSupport.seedStation(in: ctx, sourceID: "near", name: "Near",
                                latitude: 48.860, longitude: 2.350)
        TestSupport.seedStation(in: ctx, sourceID: "far", name: "Far",
                                latitude: 49.000, longitude: 3.000)
        try ctx.save()

        let results = try sut.nearbyStations(
            latitude: 48.860, longitude: 2.350,
            latRadius: 0.01, lonRadius: 0.01
        )
        #expect(results.count == 1)
        #expect(results[0].sourceID == "near")
    }

    // MARK: - lines(forStationSourceID:)

    @Test("lines(forStationSourceID:) returns all lines serving a station")
    func linesForStation() throws {
        let (sut, ctx) = makeSUT()
        TestSupport.seedLine(in: ctx, sourceID: "METRO:1", shortName: "1")
        TestSupport.seedLine(in: ctx, sourceID: "METRO:4", shortName: "4")
        TestSupport.seedLineStop(in: ctx, lineSourceID: "METRO:1", stationSourceID: "chatelet",
                                 routeVariantSourceID: "v1", order: 5)
        TestSupport.seedLineStop(in: ctx, lineSourceID: "METRO:4", stationSourceID: "chatelet",
                                 routeVariantSourceID: "v4", order: 3)
        try ctx.save()

        let lines = try sut.lines(forStationSourceID: "chatelet")
        #expect(lines.count == 2)
    }

    // MARK: - intermediateStops

    @Test("intermediateStops returns stops in order range")
    func intermediateStops() throws {
        let (sut, ctx) = makeSUT()
        for i in 0 ... 5 {
            TestSupport.seedLineStop(in: ctx, lineSourceID: "METRO:1", stationSourceID: "s\(i)",
                                     routeVariantSourceID: "v1", order: i)
        }
        try ctx.save()

        let stops = try sut.intermediateStops(routeVariantSourceID: "v1", fromOrder: 1, toOrder: 4)
        #expect(stops.count == 4) // orders 1, 2, 3, 4
        #expect(stops.first?.order == 1)
        #expect(stops.last?.order == 4)
    }

    // MARK: - connectingLinesByStation

    @Test("connectingLinesByStation excludes specified line")
    func connectingLinesExcluding() throws {
        let (sut, ctx) = makeSUT()
        TestSupport.seedLine(in: ctx, sourceID: "METRO:1", shortName: "1")
        TestSupport.seedLine(in: ctx, sourceID: "METRO:4", shortName: "4")
        TestSupport.seedLineStop(in: ctx, lineSourceID: "METRO:1", stationSourceID: "chatelet",
                                 routeVariantSourceID: "v1", order: 5)
        TestSupport.seedLineStop(in: ctx, lineSourceID: "METRO:4", stationSourceID: "chatelet",
                                 routeVariantSourceID: "v4", order: 3)
        try ctx.save()

        let map = try sut.connectingLinesByStation(
            forStationSourceIDs: Set(["chatelet"]),
            excludingLineSourceID: "METRO:1"
        )
        let connecting = try #require(map["chatelet"])
        #expect(connecting.count == 1)
        #expect(connecting[0].sourceID == "METRO:4")
    }

    @Test("connectingLinesByStation returns empty for station with no other lines")
    func connectingLinesEmpty() throws {
        let (sut, ctx) = makeSUT()
        TestSupport.seedLine(in: ctx, sourceID: "METRO:1", shortName: "1")
        TestSupport.seedLineStop(in: ctx, lineSourceID: "METRO:1", stationSourceID: "isolated",
                                 routeVariantSourceID: "v1", order: 0)
        try ctx.save()

        let map = try sut.connectingLinesByStation(
            forStationSourceIDs: Set(["isolated"]),
            excludingLineSourceID: "METRO:1"
        )
        #expect(map["isolated"] == nil)
    }

    // MARK: - stationSourceIDs

    @Test("stationSourceIDs returns unique stations for a line")
    func stationSourceIDsForLine() throws {
        let (sut, ctx) = makeSUT()
        TestSupport.seedLineStop(in: ctx, lineSourceID: "METRO:1", stationSourceID: "s0",
                                 routeVariantSourceID: "v1", order: 0)
        TestSupport.seedLineStop(in: ctx, lineSourceID: "METRO:1", stationSourceID: "s1",
                                 routeVariantSourceID: "v1", order: 1)
        TestSupport.seedLineStop(in: ctx, lineSourceID: "METRO:1", stationSourceID: "s0",
                                 routeVariantSourceID: "v2", order: 0)
        try ctx.save()

        let ids = try sut.stationSourceIDs(forLineSourceID: "METRO:1")
        #expect(ids == Set(["s0", "s1"]))
    }
}
