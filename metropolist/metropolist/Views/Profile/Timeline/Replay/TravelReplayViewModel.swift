import CoreLocation
import QuartzCore
import SwiftUI
import TransitModels

// MARK: - View Model

@MainActor
@Observable
final class TravelReplayViewModel {
    // MARK: - Types

    struct ReplayKeyframe {
        let coordinate: CLLocationCoordinate2D
        let travelID: String
        let stationName: String
        let lineColor: Color
        let lineSourceID: String
        let isTransfer: Bool
        let isEndpoint: Bool
        let distanceToNext: Double // meters; 0 for last keyframe in a travel
        let speedMultiplier: Double // 2.0 for trains (RER, Transilien, TER), 1.0 otherwise
    }

    enum ReplaySpeed: Double, CaseIterable {
        case normal = 1.0
        case fast = 2.0
        case veryFast = 4.0

        var label: String {
            switch self {
            case .normal: "1\u{00D7}"
            case .fast: "2\u{00D7}"
            case .veryFast: "4\u{00D7}"
            }
        }
    }

    struct TravelBoundary: Identifiable {
        var id: String {
            travelID
        }

        let travelID: String
        let startIndex: Int
        let endIndex: Int
        let lineColor: Color
        let coordinates: [CLLocationCoordinate2D]
        let segmentDistance: Double // total geographic distance in meters
    }

    // MARK: - State

    private(set) var keyframes: [ReplayKeyframe] = []
    private(set) var currentIndex = 0
    private(set) var interpolationProgress = 0.0
    private(set) var isPlaying = false
    var speed: ReplaySpeed = .normal
    private(set) var revealedStationIndices: Set<Int> = []
    private(set) var sortedRevealedIndices: [Int] = []
    private(set) var animatedStationIndices: Set<Int> = []

    // MARK: - Private

    @ObservationIgnored private let lines: [String: TransitLine]
    @ObservationIgnored private let displayLinkProxy = DisplayLinkProxy()
    @ObservationIgnored private var transferPauseRemaining = 0.0
    @ObservationIgnored private var wasPlayingBeforeScrub = false
    @ObservationIgnored var travelBoundaries: [TravelBoundary] = []

    @ObservationIgnored private let metersPerSecond = 333.0 // ~1.5s per typical 500m station gap at 1x
    @ObservationIgnored private let transferPauseDuration = 0.5
    @ObservationIgnored private(set) var cumulativeDistances: [Double] = []
    @ObservationIgnored private(set) var totalDistance = 1.0
    @ObservationIgnored private var stationInfoByIndex: [StationInfo?] = []
    @ObservationIgnored private var completedBoundaryCount = 0

    // MARK: - Init

    init(
        travels: [Travel],
        segments: [TimelineViewModel.TravelMapSegment],
        lines: [String: TransitLine],
        stationNames: [String: String]
    ) {
        let (keyframes, boundaries) = Self.buildKeyframes(
            travels: travels,
            segments: segments,
            lines: lines,
            stationNames: stationNames
        )
        self.lines = lines
        self.keyframes = keyframes
        travelBoundaries = boundaries

        var cumulative: [Double] = []
        var running = 0.0
        for keyframe in keyframes {
            cumulative.append(running)
            running += keyframe.distanceToNext
        }
        cumulativeDistances = cumulative
        totalDistance = max(running, 1.0)
        stationInfoByIndex = Self.buildStationInfoLookup(keyframes: keyframes)

        if !keyframes.isEmpty {
            revealedStationIndices.insert(0)
            sortedRevealedIndices = [0]
            animatedStationIndices.insert(0)
        }

        displayLinkProxy.onFrame = { [weak self] delta in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.tick(deltaTime: delta)
            }
        }
    }

    deinit {
        MainActor.assumeIsolated {
            displayLinkProxy.stop()
        }
    }

    // MARK: - Computed Properties

    var currentPosition: CLLocationCoordinate2D {
        guard !keyframes.isEmpty else { return CLLocationCoordinate2D() }
        let current = keyframes[currentIndex]
        guard currentIndex + 1 < keyframes.count,
              interpolationProgress > 0,
              !keyframes[currentIndex + 1].isTransfer
        else {
            return current.coordinate
        }
        let next = keyframes[currentIndex + 1]
        return CLLocationCoordinate2D(
            latitude: current.coordinate.latitude
                + (next.coordinate.latitude - current.coordinate.latitude) * interpolationProgress,
            longitude: current.coordinate.longitude
                + (next.coordinate.longitude - current.coordinate.longitude) * interpolationProgress
        )
    }

    var currentLineColor: Color {
        guard !keyframes.isEmpty else { return .secondary }
        return keyframes[currentIndex].lineColor
    }

    var currentLine: TransitLine? {
        guard !keyframes.isEmpty else { return nil }
        return lines[keyframes[currentIndex].lineSourceID]
    }

    struct StationInfo: Equatable {
        let name: String
        let destination: String
    }

    var currentStationInfo: StationInfo? {
        guard currentIndex < stationInfoByIndex.count else { return nil }
        return stationInfoByIndex[currentIndex]
    }

    var currentDistance: Double {
        guard !keyframes.isEmpty else { return 0 }
        return cumulativeDistances[currentIndex] + keyframes[currentIndex].distanceToNext * interpolationProgress
    }

    var overallProgress: Double {
        guard keyframes.count > 1 else { return 0 }
        return currentDistance / totalDistance
    }

    var isFinished: Bool {
        keyframes.isEmpty || currentIndex >= keyframes.count - 1
    }

    var completedBoundaries: ArraySlice<TravelBoundary> {
        if isFinished {
            return travelBoundaries[...]
        }
        return travelBoundaries.prefix(completedBoundaryCount)
    }

    struct LivePolylineState {
        let coordinates: ArraySlice<CLLocationCoordinate2D>
        let interpolatedTip: CLLocationCoordinate2D?
    }

    /// Coordinates of the active travel from its origin up to the interpolated dot position.
    /// Returns a slice (no copy) plus an optional interpolated tip coordinate.
    var liveActivePolyline: LivePolylineState? {
        guard !keyframes.isEmpty else { return nil }
        let activeTravelID = keyframes[currentIndex].travelID
        guard let boundary = travelBoundaries.first(where: { $0.travelID == activeTravelID })
        else { return nil }
        let localIndex = currentIndex - boundary.startIndex
        let slice = boundary.coordinates.prefix(localIndex + 1)
        let tip: CLLocationCoordinate2D? = if interpolationProgress > 0,
                                              currentIndex + 1 < keyframes.count,
                                              !keyframes[currentIndex + 1].isTransfer {
            currentPosition
        } else {
            nil
        }
        return LivePolylineState(coordinates: slice, interpolatedTip: tip)
    }

    // MARK: - Playback Control

    func play() {
        guard !keyframes.isEmpty, !isFinished else { return }
        isPlaying = true
        displayLinkProxy.start()
    }

    func pause() {
        isPlaying = false
        displayLinkProxy.stop()
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else if isFinished {
            currentIndex = 0
            interpolationProgress = 0
            revealedStationIndices = [0]
            sortedRevealedIndices = [0]
            animatedStationIndices = [0]
            completedBoundaryCount = 0
            play()
        } else {
            play()
        }
    }

    func markStationAnimated(_ index: Int) {
        animatedStationIndices.insert(index)
    }

    func setSpeed(_ newSpeed: ReplaySpeed) {
        speed = newSpeed
    }

    func seek(to progress: Double) {
        guard !keyframes.isEmpty else { return }
        let clamped = min(max(progress, 0), 1)
        let targetDistance = clamped * totalDistance

        // Binary search for the last keyframe whose cumulative distance <= targetDistance
        var low = 0
        var high = keyframes.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if cumulativeDistances[mid] <= targetDistance {
                low = mid
            } else {
                high = mid - 1
            }
        }

        currentIndex = low

        if currentIndex >= keyframes.count - 1 {
            interpolationProgress = 0
        } else {
            let segmentDistance = keyframes[currentIndex].distanceToNext
            if segmentDistance > 0 {
                interpolationProgress = (targetDistance - cumulativeDistances[currentIndex]) / segmentDistance
            } else {
                interpolationProgress = 0
            }
        }

        // Don't interpolate across transfers
        if currentIndex + 1 < keyframes.count, keyframes[currentIndex + 1].isTransfer {
            interpolationProgress = 0
        }

        // Reveal exactly the stations up to current position (skip animations on seek)
        revealedStationIndices = Set(0 ... currentIndex)
        sortedRevealedIndices = Array(0 ... currentIndex)
        animatedStationIndices = revealedStationIndices

        // Recompute completed boundary count for the new position
        completedBoundaryCount = travelBoundaries.prefix(while: { $0.endIndex < currentIndex }).count

        transferPauseRemaining = 0
    }

    func beginSeeking() {
        wasPlayingBeforeScrub = isPlaying
        if isPlaying {
            pause()
        }
    }

    func endSeeking() {
        if wasPlayingBeforeScrub, !isFinished {
            play()
        }
        wasPlayingBeforeScrub = false
    }

    // MARK: - Animation

    private func tick(deltaTime: TimeInterval) {
        guard isPlaying, !isFinished else {
            if isFinished {
                pause()
            }
            return
        }

        // Handle transfer pause
        if transferPauseRemaining > 0 {
            transferPauseRemaining -= deltaTime
            if transferPauseRemaining <= 0 {
                transferPauseRemaining = 0
                advanceToNextKeyframe()
            }
            return
        }

        let keyframe = keyframes[currentIndex]
        if keyframe.distanceToNext > 0 {
            interpolationProgress += deltaTime * speed.rawValue * metersPerSecond
                * keyframe.speedMultiplier / keyframe.distanceToNext
        } else {
            interpolationProgress = 1.0
        }

        while interpolationProgress >= 1.0 {
            interpolationProgress -= 1.0
            advanceToNextKeyframe()

            if isFinished || transferPauseRemaining > 0 {
                break
            }
        }
    }

    private func advanceToNextKeyframe() {
        let nextIndex = currentIndex + 1
        guard nextIndex < keyframes.count else {
            currentIndex = keyframes.count - 1
            interpolationProgress = 0
            pause()
            return
        }

        currentIndex = nextIndex
        revealedStationIndices.insert(currentIndex)
        if sortedRevealedIndices.last ?? -1 < currentIndex {
            sortedRevealedIndices.append(currentIndex)
        }

        if currentIndex >= keyframes.count - 1 {
            interpolationProgress = 0
            pause()
            return
        }

        // Pause before crossing into the next travel
        if keyframes[currentIndex + 1].isTransfer {
            transferPauseRemaining = transferPauseDuration
            interpolationProgress = 0
            // The boundary that just ended is now completed
            if completedBoundaryCount < travelBoundaries.count,
               travelBoundaries[completedBoundaryCount].endIndex <= currentIndex {
                completedBoundaryCount += 1
            }
        }
    }
}
