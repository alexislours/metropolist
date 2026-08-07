import CoreData
import Foundation
import SwiftData
import TransitModels
import WidgetKit

enum DataStoreError: LocalizedError {
    case appSupportUnavailable
    case transitStoreMissing
    case transitContainerFailed(underlying: Error)
    case appSupportDirCreationFailed(underlying: Error)
    case transitStoreCopyFailed(underlying: Error)
    case userContainerFailed(underlying: Error)
    case inMemoryContainerFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .appSupportUnavailable:
            String(
                localized: "Application storage directory is unavailable.",
                comment: "DataStore error: Application Support missing"
            )
        case .transitStoreMissing:
            String(
                localized: "Transit data is missing from the app bundle.",
                comment: "DataStore error: transit.store not in bundle"
            )
        case let .transitContainerFailed(error):
            String(
                localized: "Could not create transit database: \(error.localizedDescription)",
                comment: "DataStore error: transit container creation failed"
            )
        case let .appSupportDirCreationFailed(error):
            String(
                localized: "Could not create storage directory: \(error.localizedDescription)",
                comment: "DataStore error: cannot create App Support dir"
            )
        case let .transitStoreCopyFailed(error):
            String(
                localized: "Could not install transit data: \(error.localizedDescription)",
                comment: "DataStore error: transit.store copy failed"
            )
        case let .userContainerFailed(error):
            String(
                localized: "Could not create user database: \(error.localizedDescription)",
                comment: "DataStore error: user container creation failed"
            )
        case let .inMemoryContainerFailed(error):
            String(
                localized: "Could not create in-memory database: \(error.localizedDescription)",
                comment: "DataStore error: in-memory container failed"
            )
        }
    }
}

@MainActor
@Observable
final class DataStore {
    let userContext: ModelContext
    let transitService: TransitDataService
    let userService: UserDataService
    let locationService = LocationService()
    let transitDescriptor: TransitStoreDescriptor

    @ObservationIgnored lazy var transitUpdates: TransitUpdateModel =
        Self.makeTransitUpdateModel(descriptor: transitDescriptor)

    /// Bump to trigger view refreshes after user data changes.
    var userDataVersion = 0

    /// Set to trigger a pre-filled travel flow from line detail.
    var travelFlowPrefill: TravelFlowPrefill?

    /// Cached since transit data is read-only (pre-built store).
    private(set) var cachedStationCounts: [String: Int]?

    /// Cached line metadata map. Transit data is read-only, so this never needs invalidation.
    private(set) var cachedLineMetadata: [String: LineMetadata]?

    /// Cached station metadata map. Transit data is read-only, so this never needs invalidation.
    private(set) var cachedStationMetadata: [String: StationMetadata]?

    /// Cached modes-by-station map. Transit data is read-only, so this never needs invalidation.
    private(set) var cachedModesByStation: [String: Set<String>]?

    /// Cached sorted stations for search. Transit data is read-only, so this never needs invalidation.
    private var cachedSortedStations: [TransitStation]?

    @ObservationIgnored private var remoteChangeTask: Task<Void, Never>?
    @ObservationIgnored private var debounceTask: Task<Void, Never>?

    func stationCountsByLine() throws -> [String: Int] {
        if let cached = cachedStationCounts {
            return cached
        }
        let counts = try transitService.uniqueStationCountsByLine()
        cachedStationCounts = counts
        return counts
    }

    func modesByStation() throws -> [String: Set<String>] {
        if let cached = cachedModesByStation {
            return cached
        }
        let modes = try transitService.modesByStation()
        cachedModesByStation = modes
        return modes
    }

    func allStationMetadata() throws -> [String: StationMetadata] {
        if let cached = cachedStationMetadata {
            return cached
        }
        let allStations = try transitService.allStations()
        var meta: [String: StationMetadata] = [:]
        for station in allStations {
            meta[station.sourceID] = StationMetadata(
                name: station.name,
                postalCode: station.postalCode,
                fareZone: station.fareZone
            )
        }
        cachedStationMetadata = meta
        return meta
    }

    func searchStations(query: String) throws -> [TransitStation] {
        let normalizedQuery = query.replacing("-", with: " ")
        let stations = try cachedSortedStations ?? {
            let descriptor = FetchDescriptor<TransitStation>(sortBy: [SortDescriptor(\.name)])
            let fetched = try transitService.context.fetch(descriptor)
            cachedSortedStations = fetched
            return fetched
        }()
        return stations.filter {
            $0.name.replacing("-", with: " ").localizedStandardContains(normalizedQuery)
        }
    }

    func allLineMetadata() throws -> [String: LineMetadata] {
        if let cached = cachedLineMetadata {
            return cached
        }
        let lines = try transitService.allLines()
        let stationCounts = try stationCountsByLine()
        var metaMap: [String: LineMetadata] = [:]
        for line in lines {
            let mode = TransitMode(rawValue: line.mode) ?? .bus
            metaMap[line.sourceID] = LineMetadata(
                sourceID: line.sourceID,
                shortName: line.shortName,
                longName: line.longName,
                mode: mode,
                submode: line.submode,
                color: line.color,
                textColor: line.textColor,
                totalStations: stationCounts[line.sourceID] ?? 0
            )
        }
        cachedLineMetadata = metaMap
        return metaMap
    }

    // MARK: - Cascading Travel Deletion

    /// Deletes a travel and removes any CompletedStop records that are no longer
    /// covered by another travel on the same line.
    func deleteTravelCascading(id: String) throws {
        guard let travel = try userService.travel(byID: id) else { return }

        let linkedStops = try userService.completedStops(forTravelID: id)

        if !linkedStops.isEmpty {
            let otherTravels = try userService.travels(forLineSourceID: travel.lineSourceID)
                .filter { $0.id != id }

            // Pre-compute covered station IDs for each other travel
            var otherCoveredStations: [Set<String>] = []
            for otherTravel in otherTravels {
                let routeStops = try transitService.lineStops(
                    forRouteVariantSourceID: otherTravel.routeVariantSourceID
                )
                guard let fromOrder = routeStops.order(of: otherTravel.fromStationSourceID),
                      let toOrder = routeStops.order(of: otherTravel.toStationSourceID, after: fromOrder)
                else {
                    otherCoveredStations.append([])
                    continue
                }
                let covered = Set(
                    routeStops
                        .filter { $0.order >= fromOrder && $0.order <= toOrder }
                        .map(\.stationSourceID)
                )
                otherCoveredStations.append(covered)
            }

            for stop in linkedStops {
                var reassigned = false
                for (idx, covered) in otherCoveredStations.enumerated() where covered.contains(stop.stationSourceID) {
                    stop.travelID = otherTravels[idx].id
                    reassigned = true
                    break
                }
                if !reassigned {
                    userContext.delete(stop)
                }
            }
        }

        userContext.delete(travel)
        try userContext.save()
    }

    // MARK: - Cross-Store Queries

    /// Returns all travels that passed through a station — as origin, destination, or intermediate stop.
    func travelsPassingThrough(stationSourceID: String) throws -> [Travel] {
        // 1. Find all route variant appearances of this station and their orders
        let lineStops = try transitService.lineStops(forStationSourceID: stationSourceID)
        guard !lineStops.isEmpty else { return [] }

        // Map: routeVariantSourceID → station's order on that variant
        var stationOrderByVariant: [String: Int] = [:]
        for stop in lineStops {
            stationOrderByVariant[stop.routeVariantSourceID] = stop.order
        }

        // 2. Fetch all travels on those route variants
        let variantIDs = Array(stationOrderByVariant.keys)
        let candidateTravels = try userService.travels(forRouteVariantSourceIDs: variantIDs)
        guard !candidateTravels.isEmpty else { return [] }

        // 3. Build order lookup for from/to stations on each variant
        // Collect all station IDs we need orders for
        var neededLookups: Set<String> = [] // "variantID:stationID"
        for travel in candidateTravels {
            neededLookups.insert("\(travel.routeVariantSourceID):\(travel.fromStationSourceID)")
            neededLookups.insert("\(travel.routeVariantSourceID):\(travel.toStationSourceID)")
        }

        // Batch-fetch all stops for the relevant variants (already have some from step 1)
        let allVariantStops = try transitService.lineStops(forRouteVariantSourceIDs: variantIDs)
        var orderLookup: [String: Int] = [:] // "variantID:stationID" → order
        for stop in allVariantStops {
            orderLookup["\(stop.routeVariantSourceID):\(stop.stationSourceID)"] = stop.order
        }

        // 4. Filter: keep travels where stationOrder is between fromOrder and toOrder
        return candidateTravels.filter { travel in
            guard let stationOrder = stationOrderByVariant[travel.routeVariantSourceID],
                  let fromOrder = orderLookup["\(travel.routeVariantSourceID):\(travel.fromStationSourceID)"],
                  let toOrder = orderLookup["\(travel.routeVariantSourceID):\(travel.toStationSourceID)"]
            else { return false }
            let lowerBound = min(fromOrder, toOrder)
            let upperBound = max(fromOrder, toOrder)
            return stationOrder >= lowerBound && stationOrder <= upperBound
        }
    }

    init() throws {
        let (transitContainer, descriptor) = try Self.makeTransitContainer()
        transitDescriptor = descriptor
        let tCtx = ModelContext(transitContainer)
        tCtx.autosaveEnabled = false
        transitService = TransitDataService(context: tCtx)

        let userContainer = try Self.makeUserContainer()
        let uCtx = ModelContext(userContainer)
        userContext = uCtx
        userService = UserDataService(context: uCtx)

        remoteChangeTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
                guard let self else { break }
                debounceTask?.cancel()
                debounceTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    guard let self else { return }
                    userDataVersion += 1
                    if let snapshot = (logged { try GamificationSnapshot.build(from: self).snapshot }) {
                        WidgetDataBridge.updateWidget(from: snapshot)
                    }
                }
            }
        }
    }

    /// Internal init for testing with in-memory contexts.
    init(transitContext: ModelContext, userContext: ModelContext) {
        transitDescriptor = TransitStoreDescriptor(
            source: .bundle, schemaVersion: TransitSchema.version, dataVersion: 0,
            generatedAt: "", sha256: "", byteSize: 0, installedAt: Date()
        )
        transitService = TransitDataService(context: transitContext)
        self.userContext = userContext
        userService = UserDataService(context: userContext)
    }

    deinit {
        remoteChangeTask?.cancel()
        debounceTask?.cancel()
    }

    // MARK: - Transit Container

    static func transitSupportRoot() throws -> URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw DataStoreError.appSupportUnavailable
        }
        return appSupport
    }

    private static func makeTransitContainer() throws -> (ModelContainer, TransitStoreDescriptor) {
        let schema = Schema(TransitSchema.models)
        let root = try transitSupportRoot()
        let bundleStore = try TransitStoreInstaller.bundledStoreURL()
        let bundleInfo = TransitStoreInstaller.bundledInfo(storeURL: bundleStore)

        let descriptor = try TransitStoreInstaller.prepareStore(
            in: root, bundleStore: bundleStore, bundleInfo: bundleInfo
        )
        let storeURL = TransitStoreInstaller.Layout(root: root).store
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)

        do {
            return try (ModelContainer(for: schema, configurations: [config]), descriptor)
        } catch {
            let recovered = try TransitStoreInstaller.recoverFromBundle(
                in: root, bundleStore: bundleStore, bundleInfo: bundleInfo, rejecting: descriptor
            )
            do {
                return try (ModelContainer(for: schema, configurations: [config]), recovered)
            } catch {
                throw DataStoreError.transitContainerFailed(underlying: error)
            }
        }
    }

    // MARK: - User Container

    private static func makeUserContainer() throws -> ModelContainer {
        let schema = Schema([
            CompletedStop.self,
            Travel.self,
            Favorite.self,
        ])

        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--screenshots") {
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                do {
                    return try ModelContainer(for: schema, configurations: [config])
                } catch {
                    throw DataStoreError.inMemoryContainerFailed(underlying: error)
                }
            }
        #endif

        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw DataStoreError.appSupportUnavailable
        }
        let storeURL = appSupport.appendingPathComponent("user.store")

        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .private("iCloud.com.alexislours.metropolist")
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            throw DataStoreError.userContainerFailed(underlying: error)
        }
    }
}
