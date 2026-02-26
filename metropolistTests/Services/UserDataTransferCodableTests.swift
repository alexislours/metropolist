import Foundation
import Testing
@testable import metropolist

@Suite("User Data Transfer Codable", .tags(.codable))
@MainActor
struct UserDataTransferCodableTests {
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - CompletedStopDTO

    @Test("CompletedStopDTO round-trips through JSON")
    func completedStopRoundTrip() throws {
        let dto = CompletedStopDTO(
            id: "stop-1",
            lineSourceID: "METRO:1",
            stationSourceID: "station-A",
            completedAt: TestFixtures.referenceDate,
            travelID: "travel-1"
        )
        let data = try encoder.encode(dto)
        let decoded = try decoder.decode(CompletedStopDTO.self, from: data)

        #expect(decoded.id == dto.id)
        #expect(decoded.lineSourceID == dto.lineSourceID)
        #expect(decoded.stationSourceID == dto.stationSourceID)
        #expect(decoded.completedAt == dto.completedAt)
        #expect(decoded.travelID == dto.travelID)
    }

    @Test("CompletedStopDTO with nil travelID round-trips")
    func completedStopNilTravelID() throws {
        let dto = CompletedStopDTO(
            id: "stop-2",
            lineSourceID: "BUS:42",
            stationSourceID: "station-B",
            completedAt: TestFixtures.referenceDate,
            travelID: nil
        )
        let data = try encoder.encode(dto)
        let decoded = try decoder.decode(CompletedStopDTO.self, from: data)

        #expect(decoded.travelID == nil)
    }

    // MARK: - TravelDTO

    @Test("TravelDTO round-trips through JSON")
    func travelRoundTrip() throws {
        let dto = TravelDTO(
            id: "travel-1",
            lineSourceID: "RER:A",
            routeVariantSourceID: "variant-1",
            fromStationSourceID: "from-station",
            toStationSourceID: "to-station",
            stopsCompleted: 5,
            createdAt: TestFixtures.referenceDate
        )
        let data = try encoder.encode(dto)
        let decoded = try decoder.decode(TravelDTO.self, from: data)

        #expect(decoded.id == dto.id)
        #expect(decoded.lineSourceID == dto.lineSourceID)
        #expect(decoded.routeVariantSourceID == dto.routeVariantSourceID)
        #expect(decoded.fromStationSourceID == dto.fromStationSourceID)
        #expect(decoded.toStationSourceID == dto.toStationSourceID)
        #expect(decoded.stopsCompleted == dto.stopsCompleted)
        #expect(decoded.createdAt == dto.createdAt)
    }

    // MARK: - FavoriteDTO

    @Test("FavoriteDTO round-trips through JSON")
    func favoriteRoundTrip() throws {
        let dto = FavoriteDTO(
            id: "fav-1",
            kind: "station",
            sourceID: "station-X",
            createdAt: TestFixtures.referenceDate
        )
        let data = try encoder.encode(dto)
        let decoded = try decoder.decode(FavoriteDTO.self, from: data)

        #expect(decoded.id == dto.id)
        #expect(decoded.kind == dto.kind)
        #expect(decoded.sourceID == dto.sourceID)
        #expect(decoded.createdAt == dto.createdAt)
    }

    // MARK: - UserDataExport

    @Test("UserDataExport round-trips with all fields populated")
    func fullExportRoundTrip() throws {
        let export = UserDataExport(
            version: 2,
            exportedAt: TestFixtures.referenceDate,
            completedStops: [
                CompletedStopDTO(
                    id: "s1", lineSourceID: "METRO:1", stationSourceID: "st-A",
                    completedAt: TestFixtures.referenceDate, travelID: "t1"
                ),
            ],
            travels: [
                TravelDTO(
                    id: "t1", lineSourceID: "METRO:1", routeVariantSourceID: "v1",
                    fromStationSourceID: "st-A", toStationSourceID: "st-B",
                    stopsCompleted: 3, createdAt: TestFixtures.referenceDate
                ),
            ],
            favorites: [
                FavoriteDTO(
                    id: "f1", kind: "line", sourceID: "METRO:1",
                    createdAt: TestFixtures.referenceDate
                ),
            ]
        )
        let data = try encoder.encode(export)
        let decoded = try decoder.decode(UserDataExport.self, from: data)

        #expect(decoded.version == 2)
        #expect(decoded.completedStops.count == 1)
        #expect(decoded.travels.count == 1)
        #expect(decoded.favorites?.count == 1)
    }

    @Test("UserDataExport with nil favorites round-trips")
    func nilFavoritesRoundTrip() throws {
        let export = UserDataExport(
            version: 1,
            exportedAt: TestFixtures.referenceDate,
            completedStops: [],
            travels: [],
            favorites: nil
        )
        let data = try encoder.encode(export)
        let decoded = try decoder.decode(UserDataExport.self, from: data)

        #expect(decoded.favorites == nil)
    }

    // MARK: - Backward Compatibility

    @Test("JSON missing 'favorites' key decodes with nil favorites")
    func backwardCompatMissingFavorites() throws {
        let json = """
        {
            "version": 1,
            "exportedAt": "2025-01-15T10:00:00Z",
            "completedStops": [],
            "travels": []
        }
        """
        let data = try #require(json.data(using: .utf8))
        let decoded = try decoder.decode(UserDataExport.self, from: data)

        #expect(decoded.version == 1)
        #expect(decoded.completedStops.isEmpty)
        #expect(decoded.travels.isEmpty)
        #expect(decoded.favorites == nil)
    }
}
