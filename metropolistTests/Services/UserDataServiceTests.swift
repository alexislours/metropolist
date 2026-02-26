import Testing
import SwiftData
@testable import metropolist

@Suite("UserDataService", .tags(.services))
@MainActor
struct UserDataServiceTests {
    private func makeSUT() -> UserDataService {
        UserDataService(context: TestSupport.makeUserContext())
    }

    // MARK: - recordTravel

    @Test("recordTravel creates Travel and CompletedStops")
    func recordTravelCreatesRecords() throws {
        let sut = makeSUT()
        let travel = try sut.recordTravel(
            lineSourceID: "METRO:1",
            routeVariantSourceID: "v1",
            fromStationSourceID: "s0",
            toStationSourceID: "s4",
            intermediateStationSourceIDs: ["s0", "s1", "s2", "s3", "s4"]
        )
        #expect(travel.lineSourceID == "METRO:1")
        #expect(travel.routeVariantSourceID == "v1")
        #expect(travel.fromStationSourceID == "s0")
        #expect(travel.toStationSourceID == "s4")
        #expect(travel.stopsCompleted == 5)

        let stops = try sut.completedStopIDs(forLineSourceID: "METRO:1")
        #expect(stops.count == 5)
        #expect(stops.contains("s2"))
    }

    @Test("recordTravel is idempotent for CompletedStops")
    func recordTravelIdempotentStops() throws {
        let sut = makeSUT()
        try sut.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: "v1",
            fromStationSourceID: "s0", toStationSourceID: "s2",
            intermediateStationSourceIDs: ["s0", "s1", "s2"]
        )
        try sut.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: "v1",
            fromStationSourceID: "s1", toStationSourceID: "s3",
            intermediateStationSourceIDs: ["s1", "s2", "s3"]
        )
        // s1 and s2 should not be duplicated
        let stops = try sut.completedStopIDs(forLineSourceID: "METRO:1")
        #expect(stops == Set(["s0", "s1", "s2", "s3"]))
    }

    // MARK: - completedStopIDs

    @Test("completedStopIDs returns correct set filtered by line")
    func completedStopIDsForLine() throws {
        let sut = makeSUT()
        try sut.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: "v1",
            fromStationSourceID: "s0", toStationSourceID: "s1",
            intermediateStationSourceIDs: ["s0", "s1"]
        )
        try sut.recordTravel(
            lineSourceID: "METRO:2", routeVariantSourceID: "v2",
            fromStationSourceID: "x0", toStationSourceID: "x1",
            intermediateStationSourceIDs: ["x0"]
        )
        #expect(try sut.completedStopIDs(forLineSourceID: "METRO:1") == Set(["s0", "s1"]))
        #expect(try sut.completedStopIDs(forLineSourceID: "METRO:2") == Set(["x0"]))
    }

    // MARK: - completedCountsByLine

    @Test("completedCountsByLine returns correct counts across lines")
    func completedCountsByLine() throws {
        let sut = makeSUT()
        try sut.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: "v1",
            fromStationSourceID: "s0", toStationSourceID: "s2",
            intermediateStationSourceIDs: ["s0", "s1", "s2"]
        )
        try sut.recordTravel(
            lineSourceID: "METRO:2", routeVariantSourceID: "v2",
            fromStationSourceID: "x0", toStationSourceID: "x1",
            intermediateStationSourceIDs: ["x0"]
        )
        let counts = try sut.completedCountsByLine()
        #expect(counts["METRO:1"] == 3)
        #expect(counts["METRO:2"] == 1)
    }

    // MARK: - Favorites

    @Test("toggleFavorite adds and removes")
    func toggleFavorite() throws {
        let sut = makeSUT()
        let added = try sut.toggleFavorite(kind: "station", sourceID: "s1")
        #expect(added == true)
        #expect(try sut.isFavorite(kind: "station", sourceID: "s1") == true)

        let removed = try sut.toggleFavorite(kind: "station", sourceID: "s1")
        #expect(removed == false)
        #expect(try sut.isFavorite(kind: "station", sourceID: "s1") == false)
    }

    @Test("isFavorite returns false for non-existent favorite")
    func isFavoriteNonExistent() throws {
        let sut = makeSUT()
        #expect(try sut.isFavorite(kind: "line", sourceID: "METRO:99") == false)
    }

    @Test("favoriteSourceIDs returns correct set filtered by kind")
    func favoriteSourceIDs() throws {
        let sut = makeSUT()
        try sut.toggleFavorite(kind: "line", sourceID: "METRO:1")
        try sut.toggleFavorite(kind: "line", sourceID: "METRO:4")
        try sut.toggleFavorite(kind: "station", sourceID: "s1")

        let lineIDs = try sut.favoriteSourceIDs(kind: "line")
        #expect(lineIDs == Set(["METRO:1", "METRO:4"]))
        let stationIDs = try sut.favoriteSourceIDs(kind: "station")
        #expect(stationIDs == Set(["s1"]))
    }

    // MARK: - Travel queries

    @Test("travels filtered by line returns only matching")
    func travelsForLine() throws {
        let sut = makeSUT()
        try sut.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: "v1",
            fromStationSourceID: "s0", toStationSourceID: "s1",
            intermediateStationSourceIDs: []
        )
        try sut.recordTravel(
            lineSourceID: "METRO:2", routeVariantSourceID: "v2",
            fromStationSourceID: "x0", toStationSourceID: "x1",
            intermediateStationSourceIDs: []
        )
        let m1 = try sut.travels(forLineSourceID: "METRO:1")
        #expect(m1.count == 1)
        #expect(m1[0].lineSourceID == "METRO:1")
    }

    @Test("travelCount returns correct count per line")
    func travelCountPerLine() throws {
        let sut = makeSUT()
        try sut.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: "v1",
            fromStationSourceID: "s0", toStationSourceID: "s1",
            intermediateStationSourceIDs: []
        )
        try sut.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: "v1",
            fromStationSourceID: "s1", toStationSourceID: "s2",
            intermediateStationSourceIDs: []
        )
        #expect(try sut.travelCount(forLineSourceID: "METRO:1") == 2)
        #expect(try sut.travelCount(forLineSourceID: "METRO:2") == 0)
    }

    @Test("lastTravelDate returns most recent date")
    func lastTravelDate() throws {
        let sut = makeSUT()
        try sut.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: "v1",
            fromStationSourceID: "s0", toStationSourceID: "s1",
            intermediateStationSourceIDs: []
        )
        let t2 = try sut.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: "v1",
            fromStationSourceID: "s1", toStationSourceID: "s2",
            intermediateStationSourceIDs: []
        )
        let date = try sut.lastTravelDate(forLineSourceID: "METRO:1")
        #expect(date == t2.createdAt)
    }

    @Test("lastTravelDate returns nil for line with no travels")
    func lastTravelDateNil() throws {
        let sut = makeSUT()
        #expect(try sut.lastTravelDate(forLineSourceID: "METRO:99") == nil)
    }

    @Test("allTravels returns reverse chronological order")
    func allTravelsOrdering() throws {
        let sut = makeSUT()
        let t1 = try sut.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: "v1",
            fromStationSourceID: "s0", toStationSourceID: "s1",
            intermediateStationSourceIDs: []
        )
        let t2 = try sut.recordTravel(
            lineSourceID: "METRO:2", routeVariantSourceID: "v2",
            fromStationSourceID: "x0", toStationSourceID: "x1",
            intermediateStationSourceIDs: []
        )
        let all = try sut.allTravels()
        #expect(all.count == 2)
        // Most recent first
        #expect(all[0].id == t2.id)
        #expect(all[1].id == t1.id)
    }

    @Test("travel(byID:) returns matching travel")
    func travelByID() throws {
        let sut = makeSUT()
        let t = try sut.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: "v1",
            fromStationSourceID: "s0", toStationSourceID: "s1",
            intermediateStationSourceIDs: []
        )
        let found = try sut.travel(byID: t.id)
        #expect(found?.id == t.id)
    }

    @Test("travel(byID:) returns nil for unknown ID")
    func travelByIDNotFound() throws {
        let sut = makeSUT()
        #expect(try sut.travel(byID: "nonexistent") == nil)
    }

    // MARK: - completedStops(forTravelID:)

    @Test("completedStops returns stops linked to a travel")
    func completedStopsForTravel() throws {
        let sut = makeSUT()
        let travel = try sut.recordTravel(
            lineSourceID: "METRO:1", routeVariantSourceID: "v1",
            fromStationSourceID: "s0", toStationSourceID: "s2",
            intermediateStationSourceIDs: ["s0", "s1", "s2"]
        )
        let stops = try sut.completedStops(forTravelID: travel.id)
        #expect(stops.count == 3)
    }
}
