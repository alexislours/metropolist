import Foundation
import SwiftData
import TransitModels
@testable import metropolist

/// Disambiguate from SwiftData.DataStore (macOS 15+).
typealias AppDataStore = metropolist.DataStore

enum TestSupport {
    // MARK: - In-Memory User Context

    static func makeUserContext() -> ModelContext {
        let schema = Schema([CompletedStop.self, Travel.self, Favorite.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: - In-Memory Transit Context

    static func makeTransitContext() -> ModelContext {
        let schema = Schema([
            TransitLine.self,
            TransitStation.self,
            TransitRouteVariant.self,
            TransitLineStop.self,
            TransitTransfer.self,
            TransitMetadata.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: - Transit Data Seeding

    @discardableResult
    static func seedLine(
        in context: ModelContext,
        sourceID: String = "METRO:1",
        shortName: String = "1",
        longName: String = "Ligne 1",
        mode: String = "metro"
    ) -> TransitLine {
        let line = TransitLine(
            sourceID: sourceID, shortName: shortName, longName: longName,
            mode: mode, submode: nil, color: "#FFCD00", textColor: "#000000",
            operatorName: "RATP", networkName: nil, status: "active",
            isAccessible: true, groupID: nil, groupName: nil
        )
        context.insert(line)
        return line
    }

    @discardableResult
    static func seedStation(
        in context: ModelContext,
        sourceID: String,
        name: String,
        latitude: Double = 48.86,
        longitude: Double = 2.35
    ) -> TransitStation {
        let station = TransitStation(
            sourceID: sourceID, name: name,
            latitude: latitude, longitude: longitude,
            fareZone: "1", town: "Paris", postalCode: "75001",
            isAccessible: true, hasAudibleSignals: false, hasVisualSigns: false
        )
        context.insert(station)
        return station
    }

    @discardableResult
    static func seedRouteVariant(
        in context: ModelContext,
        sourceID: String,
        lineSourceID: String,
        direction: Int = 0,
        headsign: String = "Terminus",
        stationCount: Int = 5
    ) -> TransitRouteVariant {
        let variant = TransitRouteVariant(
            sourceID: sourceID, lineSourceID: lineSourceID,
            direction: direction, headsign: headsign, stationCount: stationCount
        )
        context.insert(variant)
        return variant
    }

    @discardableResult
    static func seedLineStop(
        in context: ModelContext,
        lineSourceID: String,
        stationSourceID: String,
        routeVariantSourceID: String,
        order: Int,
        isTerminus: Bool = false
    ) -> TransitLineStop {
        let stop = TransitLineStop(
            lineSourceID: lineSourceID, stationSourceID: stationSourceID,
            routeVariantSourceID: routeVariantSourceID, order: order,
            isTerminus: isTerminus
        )
        context.insert(stop)
        return stop
    }

    /// Seeds a complete line with stations, a route variant, and line stops.
    @discardableResult
    static func seedCompleteLine(
        in context: ModelContext,
        lineSourceID: String = "METRO:1",
        shortName: String = "1",
        mode: String = "metro",
        stationNames: [String] = ["Chateau de Vincennes", "Berault", "Saint-Mande",
                                   "Bel-Air", "Nation"]
    ) -> (line: TransitLine, variant: TransitRouteVariant, stations: [TransitStation]) {
        let line = seedLine(in: context, sourceID: lineSourceID, shortName: shortName,
                            longName: "Ligne \(shortName)", mode: mode)
        let variant = seedRouteVariant(
            in: context, sourceID: "\(lineSourceID):v1",
            lineSourceID: lineSourceID, stationCount: stationNames.count
        )
        var stations: [TransitStation] = []
        for (i, name) in stationNames.enumerated() {
            let stationID = "\(lineSourceID):s\(i)"
            let station = seedStation(in: context, sourceID: stationID, name: name,
                                      latitude: 48.84 + Double(i) * 0.002,
                                      longitude: 2.39 + Double(i) * 0.003)
            stations.append(station)
            seedLineStop(in: context, lineSourceID: lineSourceID,
                         stationSourceID: stationID,
                         routeVariantSourceID: variant.sourceID,
                         order: i, isTerminus: i == 0 || i == stationNames.count - 1)
        }
        try! context.save()
        return (line, variant, stations)
    }
}
