import Foundation
import TransitModels

extension GamificationSnapshot {
    /// Intermediate result that also exposes the `LineMetadata` map for callers that need it.
    struct BuildResult {
        let snapshot: GamificationSnapshot
        let lineMetadata: [String: LineMetadata]
        let travels: [Travel]
        let completedStops: [CompletedStop]
        let totalDistance: Double
    }

    /// Builds a snapshot from the data store.
    /// Also returns the intermediate `LineMetadata` map for callers that need it (ProfileViewModel).
    static func build(from dataStore: DataStore) throws -> BuildResult {
        let completedStops = try dataStore.userService.allCompletedStops()
        let travels = try dataStore.userService.allTravels()
        let metaMap = try dataStore.allLineMetadata()

        let stationMeta = try dataStore.allStationMetadata()

        let stopRecords = completedStops.map {
            CompletedStopRecord(
                lineSourceID: $0.lineSourceID,
                stationSourceID: $0.stationSourceID,
                completedAt: $0.completedAt
            )
        }
        let transitIdentity = dataStore.transitDescriptor.cacheIdentity
        var distanceCache = DistanceCache.load(transitIdentity: transitIdentity)
        let travelRecords = travels.map { travel in
            let dist: Double? = switch distanceCache.lookup(travelID: travel.id) {
            case let .hit(cached):
                cached
            case .miss:
                {
                    let computed = try? DistanceCalculator.distance(
                        for: travel,
                        transitService: dataStore.transitService
                    )
                    distanceCache.set(distance: computed, forTravelID: travel.id)
                    return computed
                }()
            }
            return TravelRecord(
                lineSourceID: travel.lineSourceID,
                createdAt: travel.createdAt,
                fromStationSourceID: travel.fromStationSourceID,
                toStationSourceID: travel.toStationSourceID,
                distance: dist
            )
        }
        distanceCache.persistIfNeeded(transitIdentity: transitIdentity)

        let input = GamificationInput(
            completedStops: stopRecords,
            travels: travelRecords,
            lineMetadata: metaMap,
            stationMetadata: stationMeta
        )

        let totalDistance = travelRecords.compactMap(\.distance).reduce(0, +)
        let snapshot = GamificationEngine.computeSnapshot(from: input)
        return BuildResult(
            snapshot: snapshot,
            lineMetadata: metaMap,
            travels: travels,
            completedStops: completedStops,
            totalDistance: totalDistance
        )
    }

    /// Computes the player level as it was at a specific point in time,
    /// by filtering all travels and completed stops to those recorded on or before the cutoff date.
    static func levelAtDate(_ cutoff: Date, from dataStore: DataStore) throws -> PlayerLevel {
        let completedStops = try dataStore.userService.completedStops(through: cutoff)
        let travels = try dataStore.userService.travels(through: cutoff)
        let metaMap = try dataStore.allLineMetadata()
        let stationMeta = try dataStore.allStationMetadata()

        let stopRecords = completedStops.map {
            CompletedStopRecord(
                lineSourceID: $0.lineSourceID,
                stationSourceID: $0.stationSourceID,
                completedAt: $0.completedAt
            )
        }
        let travelRecords = travels.map { travel in
            TravelRecord(
                lineSourceID: travel.lineSourceID,
                createdAt: travel.createdAt,
                fromStationSourceID: travel.fromStationSourceID,
                toStationSourceID: travel.toStationSourceID
            )
        }

        let input = GamificationInput(
            completedStops: stopRecords,
            travels: travelRecords,
            lineMetadata: metaMap,
            stationMetadata: stationMeta
        )

        let snapshot = GamificationEngine.computeSnapshot(from: input)
        return snapshot.level
    }
}
