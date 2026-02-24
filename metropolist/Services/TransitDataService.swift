import Foundation
import SwiftData
import TransitModels

struct TransitDataService {
    let context: ModelContext

    // MARK: - Lines

    func allLines() throws -> [TransitLine] {
        let descriptor = FetchDescriptor<TransitLine>(sortBy: [SortDescriptor(\.shortName)])
        return try context.fetch(descriptor)
    }

    func lines(bySourceIDs sourceIDs: [String]) throws -> [TransitLine] {
        let descriptor = FetchDescriptor<TransitLine>(
            predicate: #Predicate { sourceIDs.contains($0.sourceID) }
        )
        return try context.fetch(descriptor)
    }

    func line(bySourceID sourceID: String) throws -> TransitLine? {
        var descriptor = FetchDescriptor<TransitLine>(
            predicate: #Predicate { $0.sourceID == sourceID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Route Variants

    func routeVariants(forLineSourceID lineSourceID: String) throws -> [TransitRouteVariant] {
        let descriptor = FetchDescriptor<TransitRouteVariant>(
            predicate: #Predicate { $0.lineSourceID == lineSourceID },
            sortBy: [SortDescriptor(\.direction), SortDescriptor(\.headsign)]
        )
        return try context.fetch(descriptor)
    }

    func totalRouteVariantCount() throws -> Int {
        let descriptor = FetchDescriptor<TransitRouteVariant>()
        return try context.fetchCount(descriptor)
    }

    // MARK: - Line Stops

    func lineStops(forRouteVariantSourceID routeVariantSourceID: String) throws -> [TransitLineStop] {
        let descriptor = FetchDescriptor<TransitLineStop>(
            predicate: #Predicate { $0.routeVariantSourceID == routeVariantSourceID },
            sortBy: [SortDescriptor(\.order)]
        )
        return try context.fetch(descriptor)
    }

    func stationSourceIDs(forLineSourceID lineSourceID: String) throws -> Set<String> {
        let descriptor = FetchDescriptor<TransitLineStop>(
            predicate: #Predicate { $0.lineSourceID == lineSourceID }
        )
        let stops = try context.fetch(descriptor)
        return Set(stops.map(\.stationSourceID))
    }

    /// Bulk computation: for each line, how many unique stations does it serve?
    func uniqueStationCountsByLine() throws -> [String: Int] {
        let descriptor = FetchDescriptor<TransitLineStop>()
        let allStops = try context.fetch(descriptor)

        var lineStations: [String: Set<String>] = [:]
        for stop in allStops {
            lineStations[stop.lineSourceID, default: []].insert(stop.stationSourceID)
        }
        return lineStations.mapValues(\.count)
    }

    // MARK: - Stations

    func station(bySourceID sourceID: String) throws -> TransitStation? {
        var descriptor = FetchDescriptor<TransitStation>(
            predicate: #Predicate { $0.sourceID == sourceID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func stations(bySourceIDs sourceIDs: [String]) throws -> [TransitStation] {
        let descriptor = FetchDescriptor<TransitStation>(
            predicate: #Predicate { sourceIDs.contains($0.sourceID) }
        )
        return try context.fetch(descriptor)
    }

    func totalStationCount() throws -> Int {
        let descriptor = FetchDescriptor<TransitStation>()
        return try context.fetchCount(descriptor)
    }

    func searchStations(query: String) throws -> [TransitStation] {
        let descriptor = FetchDescriptor<TransitStation>(
            predicate: #Predicate { $0.name.localizedStandardContains(query) },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    func nearbyStations(latitude: Double, longitude: Double, radiusDegrees: Double = 0.005) throws -> [TransitStation] {
        let minLat = latitude - radiusDegrees
        let maxLat = latitude + radiusDegrees
        let minLon = longitude - radiusDegrees
        let maxLon = longitude + radiusDegrees
        let descriptor = FetchDescriptor<TransitStation>(
            predicate: #Predicate {
                $0.latitude >= minLat && $0.latitude <= maxLat &&
                    $0.longitude >= minLon && $0.longitude <= maxLon
            }
        )
        return try context.fetch(descriptor)
    }

    // MARK: - Metadata

    func metadata(forKey key: String) throws -> String? {
        var descriptor = FetchDescriptor<TransitMetadata>(
            predicate: #Predicate { $0.key == key }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.value
    }

    // MARK: - Batch connecting lines

    /// For a set of station IDs, returns a map of stationSourceID → [TransitLine] serving that station.
    /// Excludes `excludingLineSourceID` if provided.
    func connectingLinesByStation(
        forStationSourceIDs stationSourceIDs: Set<String>,
        excludingLineSourceID: String? = nil
    ) throws -> [String: [TransitLine]] {
        let stationArray = Array(stationSourceIDs)
        let stopsDescriptor = FetchDescriptor<TransitLineStop>(
            predicate: #Predicate { stationArray.contains($0.stationSourceID) }
        )
        let stops = try context.fetch(stopsDescriptor)

        // Group lineSourceIDs by station
        var lineIDsByStation: [String: Set<String>] = [:]
        for stop in stops {
            if let exclude = excludingLineSourceID, stop.lineSourceID == exclude { continue }
            lineIDsByStation[stop.stationSourceID, default: []].insert(stop.lineSourceID)
        }

        // Collect all unique line IDs
        let allLineIDs = Array(lineIDsByStation.values.reduce(into: Set<String>()) { $0.formUnion($1) })
        guard !allLineIDs.isEmpty else { return [:] }

        let lineDescriptor = FetchDescriptor<TransitLine>(
            predicate: #Predicate { allLineIDs.contains($0.sourceID) },
            sortBy: [SortDescriptor(\.shortName)]
        )
        let lines = try context.fetch(lineDescriptor)
        let lineMap = Dictionary(uniqueKeysWithValues: lines.map { ($0.sourceID, $0) })

        var result: [String: [TransitLine]] = [:]
        for (stationID, lineIDs) in lineIDsByStation {
            result[stationID] = lineIDs.compactMap { lineMap[$0] }.sorted { $0.shortName < $1.shortName }
        }
        return result
    }

    // MARK: - Station ↔ Line relationships

    func lines(forStationSourceID stationSourceID: String) throws -> [TransitLine] {
        let stopDescriptor = FetchDescriptor<TransitLineStop>(
            predicate: #Predicate { $0.stationSourceID == stationSourceID }
        )
        let stops = try context.fetch(stopDescriptor)
        let lineIDs = Array(Set(stops.map(\.lineSourceID)))

        let lineDescriptor = FetchDescriptor<TransitLine>(
            predicate: #Predicate { lineIDs.contains($0.sourceID) },
            sortBy: [SortDescriptor(\.shortName)]
        )
        return try context.fetch(lineDescriptor)
    }

    // MARK: - Route variant matching

    func matchingRouteVariants(
        lineSourceID: String,
        from fromStationSourceID: String,
        to toStationSourceID: String
    ) throws -> [TransitRouteVariant] {
        let variants = try routeVariants(forLineSourceID: lineSourceID)

        var matching: [TransitRouteVariant] = []
        for variant in variants {
            let stops = try lineStops(forRouteVariantSourceID: variant.sourceID)
            let fromOrder = stops.first { $0.stationSourceID == fromStationSourceID }?.order
            let toOrder = stops.first { $0.stationSourceID == toStationSourceID }?.order
            if let fromOrder, let toOrder, fromOrder < toOrder {
                matching.append(variant)
            }
        }
        return matching
    }

    func intermediateStops(routeVariantSourceID: String, fromOrder: Int, toOrder: Int) throws -> [TransitLineStop] {
        let descriptor = FetchDescriptor<TransitLineStop>(
            predicate: #Predicate {
                $0.routeVariantSourceID == routeVariantSourceID &&
                    $0.order >= fromOrder && $0.order <= toOrder
            },
            sortBy: [SortDescriptor(\.order)]
        )
        return try context.fetch(descriptor)
    }
}
