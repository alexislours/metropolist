import CoreLocation
import Foundation
import TransitModels

@MainActor
@Observable
final class LineDetailViewModel {
    // Line info
    var line: TransitLine?
    var variants: [TransitRouteVariant] = []
    var variantStops: [String: [TransitLineStop]] = [:]
    var stationsMap: [String: TransitStation] = [:]
    var connectingLinesMap: [String: [TransitLine]] = [:]

    // Completion
    var completedStopIDs: Set<String> = []
    var totalStations = 0

    // Travel stats
    var travelCount = 0
    var lastTravelDate: Date?
    var recentTravels: [Travel] = []
    var travelLineMap: [String: TransitLine] = [:]
    var travelStationNames: [String: String] = [:]

    // Map data
    var segments: [[CLLocationCoordinate2D]] = []
    var stationAnnotations: [LineRouteMapView.StationAnnotation] = []

    /// Variant picker
    var selectedVariantIndex = 0 {
        didSet { updateMapForSelectedVariant() }
    }

    var selectedVariant: TransitRouteVariant? {
        guard !variants.isEmpty, selectedVariantIndex < variants.count else { return nil }
        return variants[selectedVariantIndex]
    }

    var currentStops: [TransitLineStop] {
        guard let variant = selectedVariant else { return [] }
        return variantStops[variant.sourceID] ?? []
    }

    private let lineSourceID: String
    private let dataStore: DataStore

    init(lineSourceID: String, dataStore: DataStore) {
        self.lineSourceID = lineSourceID
        self.dataStore = dataStore
    }

    func loadData() async {
        await Task.yield()
        do {
            line = try dataStore.transitService.line(bySourceID: lineSourceID)
            variants = try dataStore.transitService.routeVariants(forLineSourceID: lineSourceID)
            completedStopIDs = try dataStore.userService.completedStopIDs(forLineSourceID: lineSourceID)

            let allStationIDs = try dataStore.transitService.stationSourceIDs(forLineSourceID: lineSourceID)
            totalStations = allStationIDs.count

            // Load stops per variant + collect station IDs
            var stopsMap: [String: [TransitLineStop]] = [:]
            var allNeededStationIDs: Set<String> = []
            for variant in variants {
                let stops = try dataStore.transitService.lineStops(forRouteVariantSourceID: variant.sourceID)
                stopsMap[variant.sourceID] = stops
                for stop in stops {
                    allNeededStationIDs.insert(stop.stationSourceID)
                }
            }
            variantStops = stopsMap

            // Batch-load stations
            let stations = try dataStore.transitService.stations(bySourceIDs: Array(allNeededStationIDs))
            var sMap: [String: TransitStation] = [:]
            for station in stations {
                sMap[station.sourceID] = station
            }
            stationsMap = sMap

            // Batch-load connecting lines (excluding current line)
            connectingLinesMap = try dataStore.transitService.connectingLinesByStation(
                forStationSourceIDs: allNeededStationIDs,
                excludingLineSourceID: lineSourceID
            )

            // Travel stats
            travelCount = try dataStore.userService.travelCount(forLineSourceID: lineSourceID)
            lastTravelDate = try dataStore.userService.lastTravelDate(forLineSourceID: lineSourceID)

            // Recent travels (up to 5)
            let travels = try dataStore.userService.travels(forLineSourceID: lineSourceID)
            recentTravels = Array(travels.prefix(5))
            loadTravelMetadata()

            // Map for selected variant
            updateMapForSelectedVariant()
        } catch {
            #if DEBUG
                print("Failed to load line detail: \(error)")
            #endif
        }
    }

    func refresh() {
        do {
            completedStopIDs = try dataStore.userService.completedStopIDs(forLineSourceID: lineSourceID)
            travelCount = try dataStore.userService.travelCount(forLineSourceID: lineSourceID)
            lastTravelDate = try dataStore.userService.lastTravelDate(forLineSourceID: lineSourceID)
            let travels = try dataStore.userService.travels(forLineSourceID: lineSourceID)
            recentTravels = Array(travels.prefix(5))
            loadTravelMetadata()
        } catch {
            #if DEBUG
                print("Failed to refresh line detail: \(error)")
            #endif
        }
    }

    private func loadTravelMetadata() {
        // Collect all unique line/station IDs from travels
        var lineIDs: Set<String> = []
        var stationIDs: Set<String> = []
        for travel in recentTravels {
            lineIDs.insert(travel.lineSourceID)
            stationIDs.insert(travel.fromStationSourceID)
            stationIDs.insert(travel.toStationSourceID)
        }

        // Load lines
        if let currentLine = line {
            travelLineMap[currentLine.sourceID] = currentLine
        }

        // Load station names (use existing map + fetch any missing)
        var names: [String: String] = [:]
        var missingIDs: [String] = []
        for id in stationIDs {
            if let station = stationsMap[id] {
                names[id] = station.name
            } else {
                missingIDs.append(id)
            }
        }
        if !missingIDs.isEmpty, let extras = try? dataStore.transitService.stations(bySourceIDs: missingIDs) {
            for station in extras {
                names[station.sourceID] = station.name
            }
        }
        // Fill missing station names with fallback
        for travel in recentTravels {
            for id in [travel.fromStationSourceID, travel.toStationSourceID] where names[id] == nil {
                names[id] = String(localized: "Unknown stop", comment: "Fallback name when stop cannot be resolved")
            }
        }
        travelStationNames = names
    }

    private func updateMapForSelectedVariant() {
        guard let variant = selectedVariant,
              let stops = variantStops[variant.sourceID] else {
            segments = []
            stationAnnotations = []
            return
        }

        var coords: [CLLocationCoordinate2D] = []
        var annotations: [LineRouteMapView.StationAnnotation] = []
        for stop in stops {
            guard let station = stationsMap[stop.stationSourceID] else { continue }
            let coord = CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)
            coords.append(coord)
            annotations.append(LineRouteMapView.StationAnnotation(
                id: station.sourceID,
                coordinate: coord,
                isTerminus: stop.isTerminus
            ))
        }

        segments = coords.count >= 2 ? [coords] : []
        stationAnnotations = annotations
    }
}
