import CoreLocation
import SwiftUI
import TransitModels
import UIKit

@MainActor
@Observable
final class TravelFlowViewModel {
    enum Step: Hashable {
        case pickLine
        case pickDestination
        case pickVariant
        case confirm
        case success
    }

    struct NearbyStation: Identifiable {
        var id: String {
            station.sourceID
        }

        let station: TransitStation
        let distance: CLLocationDistance
        let lines: [TransitLine]
    }

    struct DestinationOption: Identifiable {
        var id: String {
            station.sourceID
        }

        let station: TransitStation
        /// The variants that serve this station downstream from origin
        let variants: [(variant: TransitRouteVariant, stop: TransitLineStop)]
        /// Minimum stop distance from origin across all variants (for proximity sorting)
        let minStopDistance: Int
    }

    struct VariantPreview: Identifiable {
        let id: String
        /// All route variants that share the same intermediate stations path
        let variants: [TransitRouteVariant]
        /// Station source IDs between origin and destination (used for grouping)
        let viaStationIDs: [String]
        /// Station names between origin and destination (used for display)
        let viaStationNames: [String]
        let totalStops: Int

        init(variants: [TransitRouteVariant], viaStationIDs: [String], viaStationNames: [String], totalStops: Int) {
            id = variants.map(\.sourceID).sorted().joined(separator: "-")
            self.variants = variants
            self.viaStationIDs = viaStationIDs
            self.viaStationNames = viaStationNames
            self.totalStops = totalStops
        }
    }

    var path = NavigationPath()

    // Step 1: Station picker
    var isLoadingNearby = false
    var nearbyStations: [NearbyStation] = []
    var originStation: TransitStation?
    // Step 2: Line picker
    var stationLines: [TransitLine] = []
    var selectedLine: TransitLine?
    var isLoadingDestinations = false
    // Step 3: Destination picker
    var destinationOptions: [DestinationOption] = []
    var destinationStation: TransitStation?
    var selectedVariant: TransitRouteVariant?
    /// Step 3b: Variant disambiguation
    var variantPreviews: [VariantPreview] = []
    // Step 4: Confirm
    var travelDate = Date()
    var intermediateStops: [TransitLineStop] = []
    var intermediateStationNames: [String: String] = [:]
    var completedStopIDsForLine: Set<String> = []
    // Step 5: Success
    var recordedTravel: Travel?
    var newStopsCompleted: Int = 0
    var isProcessing = false
    var celebrationEvent: CelebrationEvent?
    // Errors
    var errorMessage: String?
    var showError = false
    // Prefill
    var prefillLine: TransitLine?
    var prefillLineStations: [TransitStation] = []
    var isLoadingLineStations = false
    /// Cached stops per variant, populated by loadDestinationOptions, consumed by filterVariantsByDirection/buildVariantPreview.
    var cachedStopsByVariant: [String: [TransitLineStop]] = [:]

    let dataStore: DataStore
    let prefill: TravelFlowPrefill?

    init(dataStore: DataStore, prefill: TravelFlowPrefill? = nil) {
        self.dataStore = dataStore
        self.prefill = prefill
    }

    // MARK: - Haptics

    @ObservationIgnored private lazy var selectionGenerator = UISelectionFeedbackGenerator()
    @ObservationIgnored private lazy var notificationGenerator = UINotificationFeedbackGenerator()

    private func selectionHaptic() {
        selectionGenerator.selectionChanged()
    }

    private func successHaptic() {
        notificationGenerator.notificationOccurred(.success)
    }

    // MARK: - Step 1 → 2: Select origin

    func selectOrigin(_ station: TransitStation) {
        selectionHaptic()
        originStation = station
        do {
            stationLines = try dataStore.transitService.lines(forStationSourceID: station.sourceID)
            if stationLines.isEmpty {
                errorMessage = String(localized: "No lines serve this stop.", comment: "Travel flow: error when stop has no lines")
                showError = true
                originStation = nil
                return
            }

            // Auto-select prefilled line if this station serves it
            if let prefill, let prefilled = stationLines.first(where: { $0.sourceID == prefill.lineSourceID }) {
                selectLine(prefilled)
                return
            }

            if stationLines.count == 1 {
                selectLine(stationLines[0])
            } else {
                path.append(Step.pickLine)
            }
        } catch {
            errorMessage = String(localized: "Failed to load lines.", comment: "Travel flow: error loading lines for stop")
            showError = true
            originStation = nil
        }
    }

    // MARK: - Step 2 → 3: Select line

    func selectLine(_ line: TransitLine) {
        selectionHaptic()
        selectedLine = line
        isLoadingDestinations = true
        path.append(Step.pickDestination)

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let options = try loadDestinationOptions(for: line)

                guard !options.isEmpty else {
                    errorMessage = String(
                        localized: "No destinations found from this stop on this line.",
                        comment: "Travel flow: error when no downstream stops exist"
                    )
                    showError = true
                    selectedLine = nil
                    path.removeLast()
                    isLoadingDestinations = false
                    return
                }

                destinationOptions = options
            } catch {
                errorMessage = String(
                    localized: "Failed to load destinations.",
                    comment: "Travel flow: error loading destination stops"
                )
                showError = true
                selectedLine = nil
                path.removeLast()
            }
            isLoadingDestinations = false
        }
    }

    // MARK: - Step 3 → 4: Select destination

    func selectDestination(_ option: DestinationOption) {
        selectionHaptic()
        destinationStation = option.station

        // Filter out wrong-direction variants when forward direction is available
        let directionFiltered = filterVariantsByDirection(option.variants)

        // Dedup by variant sourceID (a variant can appear multiple times if the station repeats)
        var seenVariantIDs = Set<String>()
        let allPreviews = directionFiltered.compactMap { pair -> VariantPreview? in
            guard seenVariantIDs.insert(pair.variant.sourceID).inserted else { return nil }
            return buildVariantPreview(pair.variant)
        }

        // Group variants sharing identical intermediate stations
        var grouped: [VariantPreview] = []
        var keyIndex: [String: Int] = [:]
        for preview in allPreviews {
            let key = preview.viaStationIDs.joined(separator: "|")
            if let idx = keyIndex[key] {
                let newVariants = preview.variants.filter { variant in
                    !grouped[idx].variants.contains { $0.sourceID == variant.sourceID }
                }
                guard !newVariants.isEmpty else { continue }
                grouped[idx] = VariantPreview(
                    variants: grouped[idx].variants + newVariants,
                    viaStationIDs: grouped[idx].viaStationIDs,
                    viaStationNames: grouped[idx].viaStationNames,
                    totalStops: grouped[idx].totalStops
                )
            } else {
                keyIndex[key] = grouped.count
                grouped.append(preview)
            }
        }

        let totalVariants = grouped.reduce(0) { $0 + $1.variants.count }

        if totalVariants <= 1 {
            // Unambiguous — go straight to confirm
            selectedVariant = grouped.first?.variants.first ?? option.variants[0].variant
            loadIntermediateStops()
            path.append(Step.confirm)
        } else {
            variantPreviews = grouped
            path.append(Step.pickVariant)
        }
    }

    func selectVariant(_ variant: TransitRouteVariant) {
        selectionHaptic()
        selectedVariant = variant
        loadIntermediateStops()
        path.append(Step.confirm)
    }

    // MARK: - Step 4: Confirm

    func confirmTravel() {
        guard let line = selectedLine,
              let variant = selectedVariant,
              let origin = originStation,
              let destination = destinationStation else { return }

        isProcessing = true
        do {
            let stationIDs = intermediateStops.map(\.stationSourceID)
            let existingCompletions = try dataStore.userService.completedStopIDs(forLineSourceID: line.sourceID)
            let newCompletions = stationIDs.filter { !existingCompletions.contains($0) }.count

            let allCompletedStationIDs = try Set(dataStore.userService.allCompletedStops().map(\.stationSourceID))
            let newGlobalStations = stationIDs.filter { !allCompletedStationIDs.contains($0) }.count

            // Detect first travel on this line
            let lineTravelCount = logged { try dataStore.userService.travelCount(forLineSourceID: line.sourceID) } ?? 0
            let isFirstTravelOnLine = lineTravelCount == 0

            // Capture before snapshot for celebration diff
            let beforeSnapshot = captureGamificationSnapshot(from: dataStore)

            let travel = try dataStore.userService.recordTravel(
                lineSourceID: line.sourceID,
                routeVariantSourceID: variant.sourceID,
                fromStationSourceID: origin.sourceID,
                toStationSourceID: destination.sourceID,
                intermediateStationSourceIDs: stationIDs,
                createdAt: travelDate
            )
            recordedTravel = travel
            newStopsCompleted = newCompletions
            dataStore.userDataVersion += 1

            // Capture after snapshot and compute celebration
            if let before = beforeSnapshot {
                let after = captureGamificationSnapshot(from: dataStore)
                if let after {
                    let diffContext = DiffContext(
                        lineSourceID: line.sourceID,
                        lineShortName: line.shortName,
                        lineMode: TransitMode(rawValue: line.mode) ?? .bus,
                        newStopsCount: newGlobalStations,
                        isFirstTravelOnLine: isFirstTravelOnLine,
                        afterLineProgress: after.lineProgress[line.sourceID]
                    )
                    celebrationEvent = GamificationDiffEngine.diff(
                        before: before,
                        after: after,
                        context: diffContext
                    )
                    WidgetDataBridge.updateWidget(from: after)
                }
            }

            isProcessing = false
            successHaptic()
            path.append(Step.success)
        } catch {
            errorMessage = String(
                localized: "Failed to record travel. Please try again.",
                comment: "Travel flow: error saving travel record"
            )
            showError = true
            isProcessing = false
        }
    }
}
