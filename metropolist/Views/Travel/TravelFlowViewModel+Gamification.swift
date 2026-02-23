import TransitModels

// MARK: - Route Loading & Gamification

extension TravelFlowViewModel {
    func loadDestinationOptions(for line: TransitLine) throws -> [DestinationOption] {
        let variants = try dataStore.transitService.routeVariants(forLineSourceID: line.sourceID)

        var stationVariants: [String: [(variant: TransitRouteVariant, stop: TransitLineStop)]] = [:]
        var allStationIDs: Set<String> = []

        for variant in variants {
            let stops = try dataStore.transitService.lineStops(forRouteVariantSourceID: variant.sourceID)
            guard let origin = originStation,
                  let originOrder = stops.first(where: { $0.stationSourceID == origin.sourceID })?.order else {
                continue
            }

            let downstreamStops = stops.filter { $0.order > originOrder }
            for stop in downstreamStops {
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
            let minOrder = variantPairs.map(\.stop.order).min() ?? 0
            options.append(DestinationOption(station: station, variants: variantPairs, minStopOrder: minOrder))
        }

        options.sort { $0.minStopOrder < $1.minStopOrder }
        return options
    }

    func buildVariantPreview(_ variant: TransitRouteVariant) -> VariantPreview? {
        guard let origin = originStation, let destination = destinationStation else { return nil }
        do {
            let allStops = try dataStore.transitService.lineStops(forRouteVariantSourceID: variant.sourceID)
            guard let fromOrder = allStops.order(of: origin.sourceID),
                  let toOrder = allStops.order(of: destination.sourceID, after: fromOrder) else {
                return VariantPreview(variant: variant, viaStationNames: [], totalStops: 0)
            }
            let between = allStops
                .filter { $0.order > fromOrder && $0.order < toOrder }
                .sorted { $0.order < $1.order }
            let stationIDs = between.map(\.stationSourceID)
            let stations = try dataStore.transitService.stations(bySourceIDs: stationIDs)
            let nameMap = Dictionary(uniqueKeysWithValues: stations.map { ($0.sourceID, $0.name) })
            let names = stationIDs.compactMap { nameMap[$0] }
            return VariantPreview(variant: variant, viaStationNames: names, totalStops: between.count + 2)
        } catch {
            return VariantPreview(variant: variant, viaStationNames: [], totalStops: 0)
        }
    }

    func loadIntermediateStops() {
        guard let variant = selectedVariant,
              let origin = originStation,
              let destination = destinationStation else { return }
        do {
            let allStops = try dataStore.transitService.lineStops(forRouteVariantSourceID: variant.sourceID)
            guard let fromOrder = allStops.order(of: origin.sourceID),
                  let toOrder = allStops.order(of: destination.sourceID, after: fromOrder) else {
                return
            }
            intermediateStops = try dataStore.transitService.intermediateStops(
                routeVariantSourceID: variant.sourceID,
                fromOrder: fromOrder,
                toOrder: toOrder
            )
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
        try? GamificationSnapshot.build(from: dataStore).snapshot
    }
}
