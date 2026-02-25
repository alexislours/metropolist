import CoreData
import Foundation
import SwiftData
import TransitModels

@MainActor
@Observable
final class DataStore {
    let userContext: ModelContext
    let transitService: TransitDataService
    let userService: UserDataService
    let locationService = LocationService()

    /// Bump to trigger view refreshes after user data changes.
    var userDataVersion = 0

    /// Set to trigger a pre-filled travel flow from line detail.
    var travelFlowPrefill: TravelFlowPrefill?

    /// Cached since transit data is read-only (pre-built store).
    private(set) var cachedStationCounts: [String: Int]?

    /// Cached line metadata map. Transit data is read-only, so this never needs invalidation.
    private(set) var cachedLineMetadata: [String: LineMetadata]?

    @ObservationIgnored private var remoteChangeTask: Task<Void, Never>?
    @ObservationIgnored private var debounceTask: Task<Void, Never>?

    func stationCountsByLine() throws -> [String: Int] {
        if let cached = cachedStationCounts { return cached }
        let counts = try transitService.uniqueStationCountsByLine()
        cachedStationCounts = counts
        return counts
    }

    func allLineMetadata() throws -> [String: LineMetadata] {
        if let cached = cachedLineMetadata { return cached }
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

    init() {
        let transitContainer = Self.makeTransitContainer()
        let tCtx = ModelContext(transitContainer)
        tCtx.autosaveEnabled = false
        transitService = TransitDataService(context: tCtx)

        let userContainer = Self.makeUserContainer()
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
                    self?.userDataVersion += 1
                }
            }
        }
    }

    deinit {
        remoteChangeTask?.cancel()
        debounceTask?.cancel()
    }

    // MARK: - Transit Container

    private static func makeTransitContainer() -> ModelContainer {
        let schema = Schema([
            TransitLine.self,
            TransitStation.self,
            TransitRouteVariant.self,
            TransitLineStop.self,
            TransitTransfer.self,
            TransitMetadata.self,
        ])

        let storeURL = transitStoreURL()
        copyTransitStoreIfNeeded(to: storeURL)

        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create transit ModelContainer: \(error)")
        }
    }

    private static func transitStoreURL() -> URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory unavailable")
        }
        return appSupport.appendingPathComponent("transit.store")
    }

    private static func copyTransitStoreIfNeeded(to destination: URL) {
        guard let bundledURL = Bundle.main.url(forResource: "transit", withExtension: "store") else {
            fatalError("Could not find transit.store in app bundle")
        }

        let fileManager = FileManager.default
        let appSupport = destination.deletingLastPathComponent()

        let bundledModDate = (try? fileManager.attributesOfItem(atPath: bundledURL.path)[.modificationDate] as? Date)
            .map { String($0.timeIntervalSince1970) } ?? ""
        let dateKey = "transitStoreModDate"
        let installedModDate = UserDefaults.standard.string(forKey: dateKey) ?? ""

        let needsCopy = !fileManager.fileExists(atPath: destination.path) || installedModDate != bundledModDate

        if needsCopy {
            do {
                try fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
            } catch {
                fatalError("Could not create Application Support directory: \(error)")
            }
            // Remove existing store files if upgrading
            if fileManager.fileExists(atPath: destination.path) {
                try? fileManager.removeItem(at: destination)
                // Also clean up WAL/SHM sidecars
                try? fileManager.removeItem(at: destination.appendingPathExtension("wal"))
                try? fileManager.removeItem(at: destination.appendingPathExtension("shm"))
            }
            do {
                try fileManager.copyItem(at: bundledURL, to: destination)
            } catch {
                fatalError("Could not copy transit.store to Application Support: \(error)")
            }
            UserDefaults.standard.set(bundledModDate, forKey: dateKey)
        }
    }

    // MARK: - User Container

    private static func makeUserContainer() -> ModelContainer {
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
                    fatalError("Could not create in-memory user ModelContainer: \(error)")
                }
            }
        #endif

        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory unavailable")
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
            fatalError("Could not create user ModelContainer: \(error)")
        }
    }
}
