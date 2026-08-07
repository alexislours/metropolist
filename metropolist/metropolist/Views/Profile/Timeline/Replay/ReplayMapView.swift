import MapKit
import SwiftUI

struct ReplayMapView: View {
    let viewModel: TravelReplayViewModel
    var topInset: CGFloat = 0
    var bottomInset: CGFloat = 0
    var mapHeight: CGFloat = 1

    @AppStorage("mapStyle") private var mapStyle: String = "standard"
    // periphery:ignore
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var cameraTrigger = false

    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                CompletedPolylinesContent(viewModel: viewModel)
            }
            .mapStyle(
                mapStyle == "satellite" ? .imagery : mapStyle == "hybrid" ? .hybrid : .standard
            )
            .onMapCameraChange(frequency: .continuous) {
                if !viewModel.isPlaying {
                    cameraTrigger.toggle()
                }
            }
            .overlay {
                ActivePolylineOverlay(viewModel: viewModel, proxy: proxy, cameraTrigger: cameraTrigger)
            }
            .overlay {
                StationDotsOverlay(viewModel: viewModel, proxy: proxy, cameraTrigger: cameraTrigger)
            }
            .overlay {
                ReplayCameraController(
                    viewModel: viewModel,
                    cameraPosition: $cameraPosition,
                    topInset: topInset,
                    bottomInset: bottomInset,
                    mapHeight: mapHeight
                )
            }
        }
    }
}

// MARK: - Completed Polylines (MapContent)

/// Static polylines for travel segments that have finished animating.
/// Uses native MapPolyline which handles projection internally.
private struct CompletedPolylinesContent: MapContent {
    let viewModel: TravelReplayViewModel

    var body: some MapContent {
        // completedBoundaries reads currentIndex (observed) via isFinished,
        // so this re-evaluates when keyframes advance.
        let isFinished = viewModel.isFinished

        ForEach(viewModel.completedBoundaries) { boundary in
            MapPolyline(coordinates: boundary.coordinates)
                .stroke(
                    boundary.lineColor.opacity(isFinished ? 1.0 : 0.65),
                    lineWidth: 3
                )
        }
    }
}

// MARK: - Active Polyline Overlay

/// Per-frame animated overlay for the polyline currently being drawn and the
/// moving dot. Uses proxy.convert() + Path for smooth 60fps updates.
private struct ActivePolylineOverlay: View {
    let viewModel: TravelReplayViewModel
    let proxy: MapProxy
    let cameraTrigger: Bool

    var body: some View {
        TimelineView(.animation(paused: !viewModel.isPlaying)) { context in
            ZStack {
                activePolylinePath()
                movingDotView(date: context.date)
            }
        }
        .id(cameraTrigger)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func activePolylinePath() -> some View {
        if !viewModel.isFinished, let state = viewModel.liveActivePolyline {
            let points = state.coordinates.compactMap { proxy.convert($0, to: .local) }
            let tipPoint = state.interpolatedTip.flatMap { proxy.convert($0, to: .local) }
            let color = viewModel.currentLineColor
            let totalCount = points.count + (tipPoint != nil ? 1 : 0)
            if totalCount >= 2 {
                Path { path in
                    path.move(to: points[0])
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    if let tip = tipPoint {
                        path.addLine(to: tip)
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
    }

    @ViewBuilder
    private func movingDotView(date: Date) -> some View {
        if !viewModel.isFinished, !viewModel.keyframes.isEmpty,
           let point = proxy.convert(viewModel.currentPosition, to: .local) {
            let phase = sin(date.timeIntervalSinceReferenceDate * 2 * .pi / 1.2)
            let scale = 1.0 + phase * 0.05
            let glowRadius = 8.0 + phase * 3.0
            let glowOpacity = 0.45 + phase * 0.15
            Circle()
                .fill(viewModel.currentLineColor)
                .frame(width: 14, height: 14)
                .scaleEffect(scale)
                .shadow(color: viewModel.currentLineColor.opacity(glowOpacity), radius: glowRadius)
                .position(point)
        }
    }
}

// MARK: - Station Dots Overlay

/// Station dots rendered as an overlay above the active polyline so lines
/// never draw over the dots. Uses proxy.convert() for geo-positioning.
private struct StationDotsOverlay: View {
    let viewModel: TravelReplayViewModel
    let proxy: MapProxy
    let cameraTrigger: Bool

    var body: some View {
        TimelineView(.animation(paused: !viewModel.isPlaying)) { _ in
            stationDots()
        }
        .id(cameraTrigger)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func stationDots() -> some View {
        let animated = viewModel.animatedStationIndices
        let isFinished = viewModel.isFinished
        let activeTravelID = currentTravelID

        ZStack {
            ForEach(viewModel.sortedRevealedIndices, id: \.self) { index in
                let keyframe = viewModel.keyframes[index]
                if let point = proxy.convert(keyframe.coordinate, to: .local) {
                    let isCompleted = keyframe.travelID != activeTravelID
                    let dotOpacity = isFinished ? 1.0 : (isCompleted ? 0.65 : 1.0)
                    let shouldAnimate = !animated.contains(index)

                    StationDotAnimatedView(
                        lineColor: keyframe.lineColor,
                        isEndpoint: keyframe.isEndpoint,
                        opacity: dotOpacity,
                        shouldAnimate: shouldAnimate
                    )
                    .position(point)
                    .onAppear {
                        viewModel.markStationAnimated(index)
                    }
                }
            }
        }
    }

    private var currentTravelID: String? {
        guard !viewModel.keyframes.isEmpty,
              viewModel.currentIndex < viewModel.keyframes.count
        else { return nil }
        return viewModel.keyframes[viewModel.currentIndex].travelID
    }
}

// MARK: - Camera Controller

/// Isolated view that observes `currentIndex` and drives `cameraPosition`.
private struct ReplayCameraController: View {
    let viewModel: TravelReplayViewModel
    @Binding var cameraPosition: MapCameraPosition
    let topInset: CGFloat
    let bottomInset: CGFloat
    let mapHeight: CGFloat

    @State private var trackedTravelID: String?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .onAppear { frameCurrentTravel() }
            .onChange(of: viewModel.currentIndex) { _, _ in updateCameraIfNeeded() }
    }

    private func frameCurrentTravel() {
        guard let travelID = currentTravelID,
              let region = regionForTravel(travelID)
        else { return }
        trackedTravelID = travelID
        cameraPosition = .region(region)
    }

    private func updateCameraIfNeeded() {
        guard let travelID = currentTravelID,
              travelID != trackedTravelID,
              let region = regionForTravel(travelID)
        else { return }
        trackedTravelID = travelID
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(region)
        }
    }

    private var currentTravelID: String? {
        guard !viewModel.keyframes.isEmpty,
              viewModel.currentIndex < viewModel.keyframes.count
        else { return nil }
        return viewModel.keyframes[viewModel.currentIndex].travelID
    }

    private func regionForTravel(_ travelID: String) -> MKCoordinateRegion? {
        guard let boundary = viewModel.travelBoundaries.first(where: { $0.travelID == travelID })
        else { return nil }
        let coords = boundary.coordinates
        guard let first = coords.first else { return nil }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for coord in coords {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let basePadding = 1.3
        let routeLatSpan = (maxLat - minLat) * basePadding
        let routeLonSpan = (maxLon - minLon) * basePadding

        let visibleFraction = max((mapHeight - topInset - bottomInset) / mapHeight, 0.3)
        let adjustedLatSpan = routeLatSpan / visibleFraction
        let centerLatOffset = (topInset - bottomInset) / (2 * mapHeight) * adjustedLatSpan

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2 + centerLatOffset,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(adjustedLatSpan, 0.005),
            longitudeDelta: max(routeLonSpan, 0.005)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Station Dot

private struct StationDotAnimatedView: View {
    let lineColor: Color
    let isEndpoint: Bool
    let opacity: Double
    let shouldAnimate: Bool

    @State private var appeared = false
    @State private var rippleSize: CGFloat = 6
    @State private var rippleOpacity: Double = 0
    @State private var hapticTrigger = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineColor.opacity(rippleOpacity), lineWidth: 2)
                .frame(width: rippleSize, height: rippleSize)

            if isEndpoint {
                Circle()
                    .fill(.white)
                    .stroke(lineColor.opacity(opacity), lineWidth: 2)
                    .frame(width: 10, height: 10)
            } else {
                Circle()
                    .fill(lineColor.opacity(opacity))
                    .frame(width: 6, height: 6)
            }
        }
        .scaleEffect(appeared ? 1.0 : 0.01)
        .sensoryFeedback(
            isEndpoint ? .impact(weight: .medium, intensity: 0.7) : .impact(weight: .light, intensity: 0.5),
            trigger: hapticTrigger
        )
        .onAppear {
            guard shouldAnimate else {
                appeared = true
                return
            }
            withAnimation(.spring(duration: 0.45, bounce: 0.65).delay(0.2)) {
                appeared = true
            }
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                hapticTrigger.toggle()
            }
            rippleOpacity = 0.5
            withAnimation(.easeOut(duration: 0.55).delay(0.25)) {
                rippleSize = 36
                rippleOpacity = 0
            }
        }
    }
}
