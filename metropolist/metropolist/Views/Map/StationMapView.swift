import MapKit
import SwiftUI

// MARK: - UIKit Map View

struct StationMapView: UIViewRepresentable {
    let spatialIndex: SpatialIndex
    let visitedStationIDs: Set<String>
    let filteredStationIDs: Set<String>?
    let stationNames: [String: String]
    let stationCoordinates: [String: CLLocationCoordinate2D]
    let filterVersion: Int
    let mapStyle: String
    let initialRegion: MKCoordinateRegion?
    let heatmapOverlay: HeatmapOverlay?
    @Binding var fitRegion: MKCoordinateRegion?
    var fitEdgePadding: UIEdgeInsets = .zero
    @Binding var selectedStation: MapStationSelection?
    var onMapTapped: (() -> Void)?
    var onMapControls: ((MKCompassButton, MKUserTrackingButton) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = false
        mapView.register(
            StationAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: StationAnnotationView.reuseID
        )
        mapView.register(
            ClusterAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: ClusterAnnotationView.reuseID
        )

        let compass = MKCompassButton(mapView: mapView)
        compass.compassVisibility = .adaptive
        let tracking = MKUserTrackingButton(mapView: mapView)
        onMapControls?(compass, tracking)

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMapTap(_:))
        )
        tapGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(tapGesture)

        if let region = initialRegion {
            let rect = Self.mapRect(from: region)
            mapView.setVisibleMapRect(rect, edgePadding: fitEdgePadding, animated: false)
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        applyMapStyle(mapView)
        context.coordinator.updateHeatmapOverlay(on: mapView)
        _ = context.coordinator.applyFilterChangeIfNeeded(on: mapView)
        context.coordinator.updateAnnotations(on: mapView)
        context.coordinator.syncSelectionState(on: mapView)

        if let region = fitRegion {
            DispatchQueue.main.async {
                fitRegion = nil
            }
            let rect = Self.mapRect(from: region)
            mapView.setVisibleMapRect(rect, edgePadding: fitEdgePadding, animated: true)
        }
    }

    private static func mapRect(from region: MKCoordinateRegion) -> MKMapRect {
        let topLeft = MKMapPoint(CLLocationCoordinate2D(
            latitude: region.center.latitude + region.span.latitudeDelta / 2,
            longitude: region.center.longitude - region.span.longitudeDelta / 2
        ))
        let bottomRight = MKMapPoint(CLLocationCoordinate2D(
            latitude: region.center.latitude - region.span.latitudeDelta / 2,
            longitude: region.center.longitude + region.span.longitudeDelta / 2
        ))
        return MKMapRect(
            x: topLeft.x, y: topLeft.y,
            width: bottomRight.x - topLeft.x,
            height: bottomRight.y - topLeft.y
        )
    }

    private func applyMapStyle(_ mapView: MKMapView) {
        let config: MKMapConfiguration = switch mapStyle {
        case "satellite":
            MKImageryMapConfiguration()
        case "hybrid":
            MKHybridMapConfiguration()
        default:
            MKStandardMapConfiguration()
        }
        mapView.preferredConfiguration = config
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: StationMapView
        private var currentAnnotationIDs: Set<String> = []
        private var debounceWorkItem: DispatchWorkItem?
        private var lastFilterVersion = -1
        private var lastZoom = -1
        private var lastCenter = CLLocationCoordinate2D()
        private var lastSpan = MKCoordinateSpan()
        private weak var selectedAnnotationView: StationAnnotationView?
        private var currentHeatmapOverlay: HeatmapOverlay?

        init(parent: StationMapView) {
            self.parent = parent
        }

        func syncSelectionState(on _: MKMapView) {
            if parent.selectedStation == nil, selectedAnnotationView != nil {
                selectedAnnotationView?.updateForSelection(false, animated: false)
                selectedAnnotationView = nil
            }
        }

        /// Returns true if a filter change was detected and annotations were cleared.
        func applyFilterChangeIfNeeded(on mapView: MKMapView) -> Bool {
            guard parent.filterVersion != lastFilterVersion else { return false }
            lastFilterVersion = parent.filterVersion
            let existing = mapView.annotations.compactMap { $0 as? StationAnnotation }
            mapView.removeAnnotations(existing)
            currentAnnotationIDs = []
            return true
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            debounceWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.updateAnnotationsIfNeeded(on: mapView)
            }
            debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
        }

        private func updateAnnotationsIfNeeded(on mapView: MKMapView) {
            let region = mapView.region
            let zoom = zoomLevel(for: mapView)

            let centerMoved = abs(region.center.latitude - lastCenter.latitude) > 0.0005
                || abs(region.center.longitude - lastCenter.longitude) > 0.0005
            let spanChanged = abs(region.span.latitudeDelta - lastSpan.latitudeDelta) > 0.0005
            let zoomChanged = zoom != lastZoom

            guard centerMoved || spanChanged || zoomChanged || currentAnnotationIDs.isEmpty else { return }

            lastCenter = region.center
            lastSpan = region.span
            lastZoom = zoom

            updateAnnotations(on: mapView)
        }

        func updateAnnotations(on mapView: MKMapView) {
            guard parent.heatmapOverlay == nil else { return }
            let region = mapView.region
            let zoom = zoomLevel(for: mapView)
            let clusters = parent.spatialIndex.getClusters(region: region, zoom: zoom)

            // Build new annotation set, applying filter
            var newAnnotationsByID: [String: StationAnnotation] = [:]
            for cluster in clusters {
                let effectiveCluster = filterCluster(cluster)
                guard let effectiveCluster else { continue }
                let annotation = StationAnnotation(cluster: effectiveCluster, visitedStationIDs: parent.visitedStationIDs)
                newAnnotationsByID[effectiveCluster.id] = annotation
            }

            let newIDs = Set(newAnnotationsByID.keys)

            // Diff against current
            let toRemoveIDs = currentAnnotationIDs.subtracting(newIDs)
            let toAddIDs = newIDs.subtracting(currentAnnotationIDs)

            if toRemoveIDs.isEmpty, toAddIDs.isEmpty {
                return
            }

            let existingAnnotations = mapView.annotations.compactMap { $0 as? StationAnnotation }
            let toRemove = existingAnnotations.filter { toRemoveIDs.contains($0.identifier) }

            let toAdd = toAddIDs.compactMap { newAnnotationsByID[$0] }

            if !toRemove.isEmpty {
                mapView.removeAnnotations(toRemove)
            }
            if !toAdd.isEmpty {
                mapView.addAnnotations(toAdd)
            }

            currentAnnotationIDs = newIDs
        }

        func mapView(_: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            if let heatmap = overlay as? HeatmapOverlay {
                return HeatmapRenderer(overlay: heatmap)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func updateHeatmapOverlay(on mapView: MKMapView) {
            let newOverlay = parent.heatmapOverlay

            if let existing = currentHeatmapOverlay, existing !== newOverlay {
                mapView.removeOverlay(existing)
                currentHeatmapOverlay = nil
            }

            if let newOverlay, currentHeatmapOverlay == nil {
                mapView.addOverlay(newOverlay, level: .aboveRoads)
                currentHeatmapOverlay = newOverlay
            }

            if newOverlay != nil {
                let existing = mapView.annotations.compactMap { $0 as? StationAnnotation }
                if !existing.isEmpty {
                    mapView.removeAnnotations(existing)
                    currentAnnotationIDs = []
                }
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            guard let stationAnnotation = annotation as? StationAnnotation else { return nil }

            if stationAnnotation.pointCount > 1 {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: ClusterAnnotationView.reuseID,
                    for: annotation
                ) as? ClusterAnnotationView
                view?.configure(count: stationAnnotation.pointCount, visitedRatio: stationAnnotation.visitedRatio)
                return view
            }

            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: StationAnnotationView.reuseID,
                for: annotation
            ) as? StationAnnotationView
            view?.configure(isVisited: stationAnnotation.isVisited)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: any MKAnnotation) {
            mapView.deselectAnnotation(annotation, animated: false)
            guard let stationAnnotation = annotation as? StationAnnotation else {
                // Tapped something else (user location, etc.) — dismiss selection
                deselectCurrentPin()
                return
            }

            if stationAnnotation.pointCount > 1 {
                deselectCurrentPin()
                // Zoom into cluster
                let span = mapView.region.span
                let newRegion = MKCoordinateRegion(
                    center: stationAnnotation.coordinate,
                    span: MKCoordinateSpan(
                        latitudeDelta: span.latitudeDelta * 0.4,
                        longitudeDelta: span.longitudeDelta * 0.4
                    )
                )
                mapView.setRegion(newRegion, animated: true)
            } else {
                // Deselect previous
                deselectCurrentPin()

                // Show pin on selected annotation
                let view = mapView.view(for: stationAnnotation) as? StationAnnotationView
                view?.updateForSelection(true, animated: true)
                selectedAnnotationView = view

                // Center on station and select it
                mapView.setCenter(stationAnnotation.coordinate, animated: true)
                withAnimation(.spring(duration: 0.3)) {
                    parent.selectedStation = MapStationSelection(
                        sourceID: stationAnnotation.identifier,
                        name: stationAnnotation.stationName
                    )
                }
            }
        }

        private func deselectCurrentPin() {
            selectedAnnotationView?.updateForSelection(false, animated: false)
            selectedAnnotationView = nil
            if parent.selectedStation != nil {
                withAnimation(.spring(duration: 0.3)) {
                    parent.selectedStation = nil
                }
            }
        }

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }

            let point = gesture.location(in: mapView)
            // Only dismiss if tap was not on an annotation
            for annotation in mapView.annotations {
                guard let view = mapView.view(for: annotation) else { continue }
                if view.frame.contains(mapView.convert(point, to: view.superview ?? mapView)) {
                    return
                }
            }
            deselectCurrentPin()
            parent.onMapTapped?()
        }

        func gestureRecognizer(
            _: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
        ) -> Bool {
            true
        }

        private func filterCluster(_ cluster: MapCluster) -> MapCluster? {
            guard let filterIDs = parent.filteredStationIDs else { return cluster }

            let matching = cluster.sourceIDs.filter { filterIDs.contains($0) }
            guard !matching.isEmpty else { return nil }

            if matching.count == cluster.sourceIDs.count {
                return cluster
            }

            if matching.count == 1 {
                let sid = matching[0]
                return MapCluster(
                    id: sid,
                    coordinate: parent.stationCoordinates[sid] ?? cluster.coordinate,
                    pointCount: 1,
                    stationSourceID: sid,
                    name: parent.stationNames[sid] ?? "",
                    sourceIDs: matching
                )
            }

            return MapCluster(
                id: cluster.id,
                coordinate: cluster.coordinate,
                pointCount: matching.count,
                stationSourceID: nil,
                name: "",
                sourceIDs: matching
            )
        }

        private func zoomLevel(for mapView: MKMapView) -> Int {
            let longitudeDelta = mapView.region.span.longitudeDelta
            let zoom = log2(360.0 / max(longitudeDelta, 0.0001))
            return max(2, min(Int(zoom), 20))
        }
    }
}
