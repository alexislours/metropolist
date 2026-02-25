import Foundation
import SwiftData

struct ImportResult {
    let stopsImported: Int
    let travelsImported: Int
    let favoritesImported: Int
}

// MARK: - Codable DTOs

struct CompletedStopDTO: Codable {
    let id: String
    let lineSourceID: String
    let stationSourceID: String
    let completedAt: Date
    let travelID: String?
}

struct TravelDTO: Codable {
    let id: String
    let lineSourceID: String
    let routeVariantSourceID: String
    let fromStationSourceID: String
    let toStationSourceID: String
    let stopsCompleted: Int
    let createdAt: Date
}

struct FavoriteDTO: Codable {
    let id: String
    let kind: String
    let sourceID: String
    let createdAt: Date
}

struct UserDataExport: Codable {
    let version: Int
    let exportedAt: Date
    let completedStops: [CompletedStopDTO]
    let travels: [TravelDTO]
    let favorites: [FavoriteDTO]?
}

// MARK: - Transfer Service

enum UserDataTransferService {
    static func exportJSON(context: ModelContext) throws -> Data {
        let stops = try context.fetch(FetchDescriptor<CompletedStop>())
        let travels = try context.fetch(FetchDescriptor<Travel>())
        let favorites = try context.fetch(FetchDescriptor<Favorite>())

        let export = UserDataExport(
            version: 2,
            exportedAt: Date(),
            completedStops: stops.map {
                CompletedStopDTO(
                    id: $0.id,
                    lineSourceID: $0.lineSourceID,
                    stationSourceID: $0.stationSourceID,
                    completedAt: $0.completedAt,
                    travelID: $0.travelID
                )
            },
            travels: travels.map {
                TravelDTO(
                    id: $0.id,
                    lineSourceID: $0.lineSourceID,
                    routeVariantSourceID: $0.routeVariantSourceID,
                    fromStationSourceID: $0.fromStationSourceID,
                    toStationSourceID: $0.toStationSourceID,
                    stopsCompleted: $0.stopsCompleted,
                    createdAt: $0.createdAt
                )
            },
            favorites: favorites.map {
                FavoriteDTO(
                    id: $0.id,
                    kind: $0.kind,
                    sourceID: $0.sourceID,
                    createdAt: $0.createdAt
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    static func importJSON(data: Data, context: ModelContext) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(UserDataExport.self, from: data)

        var stopsImported = 0
        for dto in export.completedStops {
            let dtoID = dto.id
            var descriptor = FetchDescriptor<CompletedStop>(
                predicate: #Predicate { $0.id == dtoID }
            )
            descriptor.fetchLimit = 1
            if try context.fetch(descriptor).isEmpty {
                let stop = CompletedStop(lineSourceID: dto.lineSourceID, stationSourceID: dto.stationSourceID, travelID: dto.travelID)
                stop.completedAt = dto.completedAt
                context.insert(stop)
                stopsImported += 1
            }
        }

        var travelsImported = 0
        for dto in export.travels {
            let dtoID = dto.id
            var descriptor = FetchDescriptor<Travel>(
                predicate: #Predicate { $0.id == dtoID }
            )
            descriptor.fetchLimit = 1
            if try context.fetch(descriptor).isEmpty {
                let travel = Travel(
                    lineSourceID: dto.lineSourceID,
                    routeVariantSourceID: dto.routeVariantSourceID,
                    fromStationSourceID: dto.fromStationSourceID,
                    toStationSourceID: dto.toStationSourceID,
                    stopsCompleted: dto.stopsCompleted
                )
                travel.id = dto.id
                travel.createdAt = dto.createdAt
                context.insert(travel)
                travelsImported += 1
            }
        }

        var favoritesImported = 0
        for dto in export.favorites ?? [] {
            let dtoID = dto.id
            var descriptor = FetchDescriptor<Favorite>(
                predicate: #Predicate { $0.id == dtoID }
            )
            descriptor.fetchLimit = 1
            if try context.fetch(descriptor).isEmpty {
                let favorite = Favorite(kind: dto.kind, sourceID: dto.sourceID)
                favorite.createdAt = dto.createdAt
                context.insert(favorite)
                favoritesImported += 1
            }
        }

        try context.save()
        return ImportResult(
            stopsImported: stopsImported,
            travelsImported: travelsImported,
            favoritesImported: favoritesImported
        )
    }
}
