import Foundation
import TransitModels

// MARK: - Route Loading & Gamification

extension TravelFlowViewModel {
    func loadDestinationOptions(for line: TransitLine) throws -> [DestinationOption] {
        let variants = try dataStore.transitService.routeVariants(forLineSourceID: line.sourceID)

        var stationVariants: [String: [(variant: TransitRouteVariant, stop: TransitLineStop)]] = [:]
        var allStationIDs: Set<String> = []
        var originOrders: [String: Int] = [:]

        for variant in variants {
            let stops = try dataStore.transitService.lineStops(forRouteVariantSourceID: variant.sourceID)
            guard let origin = originStation,
                  let originOrder = stops.first(where: { $0.stationSourceID == origin.sourceID })?.order else {
                continue
            }

            originOrders[variant.sourceID] = originOrder
            let reachableStops = stops.filter { $0.stationSourceID != origin.sourceID }
            for stop in reachableStops {
                stationVariants[stop.stationSourceID, default: []].append((variant: variant, stop: stop))
                allStationIDs.insert(stop.stationSourceID)
            }
        }

        guard !allStationIDs.isEmpty else { return [] }

        let stations = try dataStore.transitService.stations(bySourceIDs: Array(allStationIDs))
        let stationMap = Dictionary(uniqueKeysWithValues: stations.map { ($0.sourceID, $0) })

        var options: [DestinationOption] = []
        for (stationID, variantPairs) in stationVariants {
            guard let station = stationMap[stationID] else { continue }
            let minDistance = variantPairs.compactMap { pair -> Int? in
                guard let originOrder = originOrders[pair.variant.sourceID] else { return nil }
                return abs(pair.stop.order - originOrder)
            }.min() ?? 0
            options.append(DestinationOption(station: station, variants: variantPairs, minStopDistance: minDistance))
        }

        if UserDefaults.standard.string(forKey: "destinationSort") == "alphabetical" {
            options.sort { $0.station.name.localizedStandardCompare($1.station.name) == .orderedAscending }
        } else {
            options.sort { $0.minStopDistance < $1.minStopDistance }
        }
        return options
    }

    /// Filters out variants where the destination is only reachable backward (behind the origin)
    /// when at least one variant reaches it forward. This prevents offering wrong-direction options
    /// when the correct direction is obvious from the chosen origin and destination.
    func filterVariantsByDirection(
        _ variants: [(variant: TransitRouteVariant, stop: TransitLineStop)]
    ) -> [(variant: TransitRouteVariant, stop: TransitLineStop)] {
        guard let origin = originStation, let destination = destinationStation else { return variants }

        var forwardIDs = Set<String>()
        var checked = Set<String>()

        for pair in variants where checked.insert(pair.variant.sourceID).inserted {
            let stops: [TransitLineStop]? = logged {
                try dataStore.transitService.lineStops(forRouteVariantSourceID: pair.variant.sourceID)
            }
            guard let stops,
                  let fromOrder = stops.order(of: origin.sourceID),
                  stops.order(of: destination.sourceID, after: fromOrder) != nil else { continue }
            forwardIDs.insert(pair.variant.sourceID)
        }

        guard !forwardIDs.isEmpty else { return variants }
        return variants.filter { forwardIDs.contains($0.variant.sourceID) }
    }

    func buildVariantPreview(_ variant: TransitRouteVariant) -> VariantPreview? {
        guard let origin = originStation, let destination = destinationStation else { return nil }
        do {
            let allStops = try dataStore.transitService.lineStops(forRouteVariantSourceID: variant.sourceID)
            guard let fromOrder = allStops.order(of: origin.sourceID) else {
                return VariantPreview(variants: [variant], viaStationIDs: [], viaStationNames: [], totalStops: 0)
            }
            let toOrder: Int? = if let forward = allStops.order(of: destination.sourceID, after: fromOrder) {
                forward
            } else {
                allStops.order(of: destination.sourceID, before: fromOrder)
            }
            guard let toOrder else {
                return VariantPreview(variants: [variant], viaStationIDs: [], viaStationNames: [], totalStops: 0)
            }
            let lower = min(fromOrder, toOrder)
            let upper = max(fromOrder, toOrder)
            var between = allStops
                .filter { $0.order > lower && $0.order < upper }
                .sorted { $0.order < $1.order }
            if fromOrder > toOrder { between.reverse() }
            let stationIDs = between.map(\.stationSourceID)
            let stations = try dataStore.transitService.stations(bySourceIDs: stationIDs)
            let nameMap = Dictionary(uniqueKeysWithValues: stations.map { ($0.sourceID, $0.name) })
            let names = stationIDs.compactMap { nameMap[$0] }
            return VariantPreview(
                variants: [variant], viaStationIDs: stationIDs,
                viaStationNames: names, totalStops: between.count + 2
            )
        } catch {
            return VariantPreview(variants: [variant], viaStationIDs: [], viaStationNames: [], totalStops: 0)
        }
    }

    func loadIntermediateStops() {
        guard let variant = selectedVariant,
              let origin = originStation,
              let destination = destinationStation else { return }
        do {
            let allStops = try dataStore.transitService.lineStops(forRouteVariantSourceID: variant.sourceID)
            guard let fromOrder = allStops.order(of: origin.sourceID) else { return }
            let toOrder: Int? = if let forward = allStops.order(of: destination.sourceID, after: fromOrder) {
                forward
            } else {
                allStops.order(of: destination.sourceID, before: fromOrder)
            }
            guard let toOrder else { return }
            let lower = min(fromOrder, toOrder)
            let upper = max(fromOrder, toOrder)
            intermediateStops = try dataStore.transitService.intermediateStops(
                routeVariantSourceID: variant.sourceID,
                fromOrder: lower,
                toOrder: upper
            )
            if fromOrder > toOrder { intermediateStops.reverse() }
            let stationIDs = intermediateStops.map(\.stationSourceID)
            let stations = try dataStore.transitService.stations(bySourceIDs: stationIDs)
            var names: [String: String] = [:]
            for station in stations {
                names[station.sourceID] = station.name
            }
            intermediateStationNames = names
        } catch {
            // Intermediate stops are presentational; continue without them
        }
    }

    func captureGamificationSnapshot(from dataStore: DataStore) -> GamificationSnapshot? {
        logged { try GamificationSnapshot.build(from: dataStore).snapshot }
    }
}
