@testable import metropolist
import SwiftData
import Testing
import TransitModels

// MARK: - CompletedStop Model Tests

struct CompletedStopTests {
    @Test func compositeIDFormat() {
        let stop = CompletedStop(lineSourceID: "LINE:1", stationSourceID: "STOP:42")
        #expect(stop.id == "LINE:1:STOP:42")
    }

    @Test func differentLinesProduceDifferentIDs() {
        let stop1 = CompletedStop(lineSourceID: "LINE:1", stationSourceID: "STOP:42")
        let stop2 = CompletedStop(lineSourceID: "LINE:5", stationSourceID: "STOP:42")
        #expect(stop1.id != stop2.id)
    }
}

// MARK: - UserDataService Tests

@MainActor
struct UserDataServiceTests {
    private func makeUserContext() throws -> ModelContext {
        let schema = Schema([CompletedStop.self, Travel.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @Test func recordTravelCreatesCompletedStops() throws {
        let context = try makeUserContext()
        let service = UserDataService(context: context)

        let travel = try service.recordTravel(
            lineSourceID: "LINE:1",
            routeVariantSourceID: "RV:1",
            fromStationSourceID: "STOP:A",
            toStationSourceID: "STOP:C",
            intermediateStationSourceIDs: ["STOP:A", "STOP:B", "STOP:C"]
        )

        #expect(travel.stopsCompleted == 3)
        #expect(try service.totalCompletedStops() == 3)
        #expect(try service.completedStopCount(forLineSourceID: "LINE:1") == 3)
    }

    @Test func idempotentCompletionInsert() throws {
        let context = try makeUserContext()
        let service = UserDataService(context: context)

        // Record first travel
        try service.recordTravel(
            lineSourceID: "LINE:1",
            routeVariantSourceID: "RV:1",
            fromStationSourceID: "STOP:A",
            toStationSourceID: "STOP:B",
            intermediateStationSourceIDs: ["STOP:A", "STOP:B"]
        )

        // Record overlapping travel — STOP:B should not be duplicated
        try service.recordTravel(
            lineSourceID: "LINE:1",
            routeVariantSourceID: "RV:1",
            fromStationSourceID: "STOP:B",
            toStationSourceID: "STOP:C",
            intermediateStationSourceIDs: ["STOP:B", "STOP:C"]
        )

        #expect(try service.completedStopCount(forLineSourceID: "LINE:1") == 3)
    }

    @Test func completedStopIDs() throws {
        let context = try makeUserContext()
        let service = UserDataService(context: context)

        try service.recordTravel(
            lineSourceID: "LINE:1",
            routeVariantSourceID: "RV:1",
            fromStationSourceID: "STOP:A",
            toStationSourceID: "STOP:B",
            intermediateStationSourceIDs: ["STOP:A", "STOP:B"]
        )

        let ids = try service.completedStopIDs(forLineSourceID: "LINE:1")
        #expect(ids == Set(["STOP:A", "STOP:B"]))
    }

    @Test func isStopCompleted() throws {
        let context = try makeUserContext()
        let service = UserDataService(context: context)

        try service.recordTravel(
            lineSourceID: "LINE:1",
            routeVariantSourceID: "RV:1",
            fromStationSourceID: "STOP:A",
            toStationSourceID: "STOP:B",
            intermediateStationSourceIDs: ["STOP:A"]
        )

        #expect(try service.isStopCompleted(lineSourceID: "LINE:1", stationSourceID: "STOP:A") == true)
        #expect(try service.isStopCompleted(lineSourceID: "LINE:1", stationSourceID: "STOP:Z") == false)
        // Same station on a different line is not completed
        #expect(try service.isStopCompleted(lineSourceID: "LINE:2", stationSourceID: "STOP:A") == false)
    }

    @Test func allTravelsSortedByDate() throws {
        let context = try makeUserContext()
        let service = UserDataService(context: context)

        try service.recordTravel(
            lineSourceID: "LINE:1",
            routeVariantSourceID: "RV:1",
            fromStationSourceID: "STOP:A",
            toStationSourceID: "STOP:B",
            intermediateStationSourceIDs: ["STOP:A", "STOP:B"]
        )

        try service.recordTravel(
            lineSourceID: "LINE:2",
            routeVariantSourceID: "RV:2",
            fromStationSourceID: "STOP:X",
            toStationSourceID: "STOP:Y",
            intermediateStationSourceIDs: ["STOP:X", "STOP:Y"]
        )

        let travels = try service.allTravels()
        #expect(travels.count == 2)
        // Most recent first
        #expect(travels[0].lineSourceID == "LINE:2")
    }
}

// MARK: - TransitDataService Tests

@MainActor
struct TransitDataServiceTests {
    private func makeTransitContext() throws -> ModelContext {
        let schema = Schema([
            TransitLine.self,
            TransitStation.self,
            TransitRouteVariant.self,
            TransitLineStop.self,
            TransitTransfer.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        // Seed test data
        let line1 = TransitLine(
            sourceID: "LINE:M1", shortName: "1", longName: "La Défense - Château de Vincennes",
            mode: "metro", submode: nil, color: "FFCD00", textColor: "000000",
            operatorName: "RATP", networkName: nil, status: "active",
            isAccessible: true, groupID: nil, groupName: nil
        )
        let line2 = TransitLine(
            sourceID: "LINE:M5", shortName: "5", longName: "Bobigny - Place d'Italie",
            mode: "metro", submode: nil, color: "FF7E2E", textColor: "000000",
            operatorName: "RATP", networkName: nil, status: "active",
            isAccessible: false, groupID: nil, groupName: nil
        )
        context.insert(line1)
        context.insert(line2)

        let bastille = TransitStation(
            sourceID: "STOP:BASTILLE", name: "Bastille", latitude: 48.853, longitude: 2.369,
            fareZone: "1", town: "Paris", postalCode: "75004",
            isAccessible: true, hasAudibleSignals: false, hasVisualSigns: false
        )
        let nation = TransitStation(
            sourceID: "STOP:NATION", name: "Nation", latitude: 48.848, longitude: 2.395,
            fareZone: "1", town: "Paris", postalCode: "75012",
            isAccessible: true, hasAudibleSignals: false, hasVisualSigns: false
        )
        let gareDelyon = TransitStation(
            sourceID: "STOP:GDLYON", name: "Gare de Lyon", latitude: 48.844, longitude: 2.374,
            fareZone: "1", town: "Paris", postalCode: "75012",
            isAccessible: true, hasAudibleSignals: false, hasVisualSigns: false
        )
        context.insert(bastille)
        context.insert(nation)
        context.insert(gareDelyon)

        let rv1 = TransitRouteVariant(
            sourceID: "RV:M1-E", lineSourceID: "LINE:M1",
            direction: 0, headsign: "Château de Vincennes", stationCount: 3
        )
        context.insert(rv1)

        // M1 stops: Bastille(0) → Gare de Lyon(1) → Nation(2)
        context.insert(TransitLineStop(
            lineSourceID: "LINE:M1", stationSourceID: "STOP:BASTILLE",
            routeVariantSourceID: "RV:M1-E", order: 0, isTerminus: true
        ))
        context.insert(TransitLineStop(
            lineSourceID: "LINE:M1", stationSourceID: "STOP:GDLYON",
            routeVariantSourceID: "RV:M1-E", order: 1, isTerminus: false
        ))
        context.insert(TransitLineStop(
            lineSourceID: "LINE:M1", stationSourceID: "STOP:NATION",
            routeVariantSourceID: "RV:M1-E", order: 2, isTerminus: true
        ))

        // M5 also serves Bastille
        let rv5 = TransitRouteVariant(
            sourceID: "RV:M5-S", lineSourceID: "LINE:M5",
            direction: 1, headsign: "Place d'Italie", stationCount: 2
        )
        context.insert(rv5)
        context.insert(TransitLineStop(
            lineSourceID: "LINE:M5", stationSourceID: "STOP:BASTILLE",
            routeVariantSourceID: "RV:M5-S", order: 0, isTerminus: true
        ))
        context.insert(TransitLineStop(
            lineSourceID: "LINE:M5", stationSourceID: "STOP:GDLYON",
            routeVariantSourceID: "RV:M5-S", order: 1, isTerminus: true
        ))

        try context.save()
        return context
    }

    @Test func searchStations() throws {
        let context = try makeTransitContext()
        let service = TransitDataService(context: context)

        let results = try service.searchStations(query: "Bast")
        #expect(results.count == 1)
        #expect(results[0].name == "Bastille")
    }

    @Test func linesForStation() throws {
        let context = try makeTransitContext()
        let service = TransitDataService(context: context)

        let lines = try service.lines(forStationSourceID: "STOP:BASTILLE")
        #expect(lines.count == 2)
    }

    @Test func stationSourceIDsForLine() throws {
        let context = try makeTransitContext()
        let service = TransitDataService(context: context)

        let ids = try service.stationSourceIDs(forLineSourceID: "LINE:M1")
        #expect(ids == Set(["STOP:BASTILLE", "STOP:GDLYON", "STOP:NATION"]))
    }

    @Test func matchingRouteVariants() throws {
        let context = try makeTransitContext()
        let service = TransitDataService(context: context)

        let variants = try service.matchingRouteVariants(
            lineSourceID: "LINE:M1",
            from: "STOP:BASTILLE",
            to: "STOP:NATION"
        )
        #expect(variants.count == 1)
        #expect(variants[0].sourceID == "RV:M1-E")
    }

    @Test func matchingRouteVariantsWrongDirection() throws {
        let context = try makeTransitContext()
        let service = TransitDataService(context: context)

        // Nation → Bastille is reverse direction on RV:M1-E
        let variants = try service.matchingRouteVariants(
            lineSourceID: "LINE:M1",
            from: "STOP:NATION",
            to: "STOP:BASTILLE"
        )
        #expect(variants.isEmpty)
    }

    @Test func intermediateStops() throws {
        let context = try makeTransitContext()
        let service = TransitDataService(context: context)

        let stops = try service.intermediateStops(
            routeVariantSourceID: "RV:M1-E",
            fromOrder: 0,
            toOrder: 2
        )
        #expect(stops.count == 3)
        #expect(stops[0].stationSourceID == "STOP:BASTILLE")
        #expect(stops[1].stationSourceID == "STOP:GDLYON")
        #expect(stops[2].stationSourceID == "STOP:NATION")
    }

    @Test func nearbyStations() throws {
        let context = try makeTransitContext()
        let service = TransitDataService(context: context)

        // Near Bastille coordinates
        let stations = try service.nearbyStations(latitude: 48.853, longitude: 2.369, radiusDegrees: 0.01)
        #expect(stations.count >= 1)
        #expect(stations.contains { $0.sourceID == "STOP:BASTILLE" })
    }

    @Test func uniqueStationCountsByLine() throws {
        let context = try makeTransitContext()
        let service = TransitDataService(context: context)

        let counts = try service.uniqueStationCountsByLine()
        #expect(counts["LINE:M1"] == 3)
        #expect(counts["LINE:M5"] == 2)
    }
}

// MARK: - TransitMode Tests

@MainActor
struct TransitModeTests {
    @Test func allModesHaveSortOrder() {
        let sorted = TransitMode.allCases.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted.first == .metro)
        #expect(sorted.last == .railShuttle)
    }

    @Test func rawValueMapping() {
        #expect(TransitMode(rawValue: "metro") == .metro)
        #expect(TransitMode(rawValue: "bus") == .bus)
        #expect(TransitMode(rawValue: "nonexistent") == nil)
    }
}
