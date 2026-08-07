import Foundation
import MapKit
import SwiftUI
import TransitModels

@MainActor
@Observable
final class TimelineViewModel {
    var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    var isLoading = true

    var dayTravels: [Travel] = []
    var travelLines: [String: TransitLine] = [:]
    var stationNames: [String: String] = [:]

    var daysWithTravels: Set<Date> = []
    var daySummary = DaySummary(travelCount: 0, totalStops: 0)

    // Map data
    var travelMapData: [TravelMapSegment] = []
    var dayMapRegion: MKCoordinateRegion?
    var highlightedTravelID: String?

    private var travelsByDay: [Date: [Travel]] = [:]
    private let dataStore: DataStore

    init(dataStore: DataStore) {
        self.dataStore = dataStore
    }

    func load() async {
        do {
            let allTravels = try dataStore.userService.allTravels()
            let calendar = Calendar.current

            var grouped: [Date: [Travel]] = [:]
            for travel in allTravels {
                let day = calendar.startOfDay(for: travel.createdAt)
                grouped[day, default: []].append(travel)
            }
            for key in grouped.keys {
                grouped[key]?.sort { $0.createdAt < $1.createdAt }
            }

            travelsByDay = grouped
            daysWithTravels = Set(grouped.keys)

            let today = Calendar.current.startOfDay(for: Date())
            if let lastDay = daysWithTravels.filter({ $0 <= today }).max() {
                selectDate(lastDay)
            } else {
                selectDate(today)
            }
        } catch {
            #if DEBUG
                print("Failed to load timeline: \(error)")
            #endif
        }
        isLoading = false
    }

    func selectDate(_ date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        selectedDate = day

        let travels = travelsByDay[day] ?? []
        dayTravels = travels

        guard !travels.isEmpty else {
            travelLines = [:]
            stationNames = [:]
            daySummary = DaySummary(travelCount: 0, totalStops: 0)
            travelMapData = []
            dayMapRegion = nil
            return
        }

        do {
            var lineMap: [String: TransitLine] = [:]
            var nameMap: [String: String] = [:]
            var neededLineIDs: Set<String> = []
            var neededStationIDs: Set<String> = []

            for travel in travels {
                neededLineIDs.insert(travel.lineSourceID)
                neededStationIDs.insert(travel.fromStationSourceID)
                neededStationIDs.insert(travel.toStationSourceID)
            }

            let lines = try dataStore.transitService.lines(bySourceIDs: Array(neededLineIDs))
            for line in lines {
                lineMap[line.sourceID] = line
            }

            let stations = try dataStore.transitService.stations(bySourceIDs: Array(neededStationIDs))
            var stationsById: [String: TransitStation] = [:]
            for station in stations {
                nameMap[station.sourceID] = station.name
                stationsById[station.sourceID] = station
            }

            for travel in travels {
                for id in [travel.fromStationSourceID, travel.toStationSourceID] where nameMap[id] == nil {
                    nameMap[id] = String(localized: "Unknown stop", comment: "Fallback name when stop cannot be resolved")
                }
            }

            travelLines = lineMap
            stationNames = nameMap

            let distance = (try? DistanceCalculator.totalDistance(
                for: travels,
                transitService: dataStore.transitService
            )) ?? 0

            daySummary = DaySummary(
                travelCount: travels.count,
                totalStops: travels.reduce(0) { $0 + $1.stopsCompleted },
                totalDistance: distance
            )

            // Build map data
            travelMapData = buildMapData(travels: travels, lineMap: lineMap, stationsById: &stationsById)
            dayMapRegion = computeRegion(for: travelMapData)
        } catch {
            #if DEBUG
                print("Failed to resolve timeline data: \(error)")
            #endif
        }
    }

    // MARK: - Date Navigation

    var canNavigatePrevious: Bool {
        daysWithTravels.contains(where: { $0 < selectedDate })
    }

    var canNavigateNext: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return daysWithTravels.contains(where: { $0 > selectedDate && $0 <= today })
    }

    func navigateToPreviousDay() {
        if let previous = daysWithTravels.filter({ $0 < selectedDate }).max() {
            selectDate(previous)
        }
    }

    func navigateToNextDay() {
        let today = Calendar.current.startOfDay(for: Date())
        if let next = daysWithTravels.filter({ $0 > selectedDate && $0 <= today }).min() {
            selectDate(next)
        }
    }

    // MARK: - Highlight

    func highlightTravel(_ travelID: String) {
        highlightedTravelID = travelID
    }

    func clearHighlight() {
        highlightedTravelID = nil
    }

    func regionForTravel(_ travelID: String) -> MKCoordinateRegion? {
        guard let segment = travelMapData.first(where: { $0.id == travelID }) else { return nil }
        return computeRegion(for: [segment])
    }

    // MARK: - Map Data Building

    private func buildMapData(
        travels: [Travel],
        lineMap: [String: TransitLine],
        stationsById: inout [String: TransitStation]
    ) -> [TravelMapSegment] {
        // Batch-fetch all intermediate stops for the day's route variants
        let variantIDs = Array(Set(travels.map(\.routeVariantSourceID)))
        guard let allStopsForVariants = try? dataStore.transitService.lineStops(forRouteVariantSourceIDs: variantIDs) else {
            return buildSimpleMapData(travels: travels, lineMap: lineMap, stationsById: stationsById)
        }

        var stopsByVariant: [String: [TransitLineStop]] = [:]
        for stop in allStopsForVariants {
            stopsByVariant[stop.routeVariantSourceID, default: []].append(stop)
        }
        for key in stopsByVariant.keys {
            stopsByVariant[key]?.sort { $0.order < $1.order }
        }

        let (travelIntermediateStops, intermediateStationIDs) = resolveIntermediateStops(
            travels: travels,
            stopsByVariant: stopsByVariant
        )

        // Batch-fetch intermediate station coordinates
        let missingIDs = intermediateStationIDs.subtracting(stationsById.keys)
        if !missingIDs.isEmpty, let extraStations = try? dataStore.transitService.stations(bySourceIDs: Array(missingIDs)) {
            for station in extraStations {
                stationsById[station.sourceID] = station
            }
        }

        return buildSegments(
            travels: travels,
            lineMap: lineMap,
            stationsById: stationsById,
            travelIntermediateStops: travelIntermediateStops
        )
    }

    private func resolveIntermediateStops(
        travels: [Travel],
        stopsByVariant: [String: [TransitLineStop]]
    ) -> (stops: [String: [TransitLineStop]], stationIDs: Set<String>) {
        var travelStops: [String: [TransitLineStop]] = [:]
        var stationIDs: Set<String> = []

        for travel in travels {
            guard let variantStops = stopsByVariant[travel.routeVariantSourceID],
                  let fromOrder = variantStops.order(of: travel.fromStationSourceID) else { continue }
            let resolvedToOrder: Int? = if let forward = variantStops.order(of: travel.toStationSourceID, after: fromOrder) {
                forward
            } else {
                variantStops.order(of: travel.toStationSourceID, before: fromOrder)
            }
            guard let toOrder = resolvedToOrder else { continue }
            let lower = min(fromOrder, toOrder)
            let upper = max(fromOrder, toOrder)
            var stops = variantStops.filter { $0.order >= lower && $0.order <= upper }
            if fromOrder > toOrder {
                stops.reverse()
            }
            travelStops[travel.id] = stops
            for stop in stops {
                stationIDs.insert(stop.stationSourceID)
            }
        }

        return (travelStops, stationIDs)
    }

    private func buildSegments(
        travels: [Travel],
        lineMap: [String: TransitLine],
        stationsById: [String: TransitStation],
        travelIntermediateStops: [String: [TransitLineStop]]
    ) -> [TravelMapSegment] {
        var segments: [TravelMapSegment] = []
        for travel in travels {
            let lineColor = lineMap[travel.lineSourceID].map { Color(hex: $0.color) } ?? .secondary

            let stopIDs: [String] = if let intermediateStops = travelIntermediateStops[travel.id] {
                intermediateStops.map(\.stationSourceID)
            } else {
                [travel.fromStationSourceID, travel.toStationSourceID]
            }

            var coords: [CLLocationCoordinate2D] = []
            for id in stopIDs {
                guard let station = stationsById[id] else { continue }
                coords.append(CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude))
            }

            guard coords.count >= 2 else { continue }

            segments.append(TravelMapSegment(
                id: travel.id,
                coordinates: coords,
                lineColor: lineColor,
                originCoordinate: coords[0],
                destinationCoordinate: coords[coords.count - 1]
            ))
        }
        return segments
    }

    private func buildSimpleMapData(
        travels: [Travel],
        lineMap: [String: TransitLine],
        stationsById: [String: TransitStation]
    ) -> [TravelMapSegment] {
        var segments: [TravelMapSegment] = []
        for travel in travels {
            let lineColor = lineMap[travel.lineSourceID].map { Color(hex: $0.color) } ?? .secondary
            guard let fromStation = stationsById[travel.fromStationSourceID],
                  let toStation = stationsById[travel.toStationSourceID] else { continue }
            let fromCoord = CLLocationCoordinate2D(latitude: fromStation.latitude, longitude: fromStation.longitude)
            let toCoord = CLLocationCoordinate2D(latitude: toStation.latitude, longitude: toStation.longitude)
            segments.append(TravelMapSegment(
                id: travel.id,
                coordinates: [fromCoord, toCoord],
                lineColor: lineColor,
                originCoordinate: fromCoord,
                destinationCoordinate: toCoord
            ))
        }
        return segments
    }

    private func computeRegion(for segments: [TravelMapSegment]) -> MKCoordinateRegion? {
        let allCoords = segments.flatMap(\.coordinates)
        guard let first = allCoords.first else { return nil }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for coord in allCoords {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.3, 0.005),
            longitudeDelta: max((maxLon - minLon) * 1.3, 0.005)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Types

    struct DaySummary {
        let travelCount: Int
        let totalStops: Int
        var totalDistance: Double = 0
    }

    struct TravelMapSegment: Identifiable {
        let id: String
        let coordinates: [CLLocationCoordinate2D]
        let lineColor: Color
        let originCoordinate: CLLocationCoordinate2D
        let destinationCoordinate: CLLocationCoordinate2D
    }
}
