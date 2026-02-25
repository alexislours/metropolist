import Foundation
import SwiftData

struct UserDataService {
    let context: ModelContext

    // MARK: - Completion queries

    func completedStopIDs(forLineSourceID lineSourceID: String) throws -> Set<String> {
        let descriptor = FetchDescriptor<CompletedStop>(
            predicate: #Predicate { $0.lineSourceID == lineSourceID }
        )
        let stops = try context.fetch(descriptor)
        return Set(stops.map(\.stationSourceID))
    }

    /// Bulk: completed stop counts grouped by line. Single fetch instead of N queries.
    func completedCountsByLine() throws -> [String: Int] {
        let descriptor = FetchDescriptor<CompletedStop>()
        let all = try context.fetch(descriptor)
        var counts: [String: Int] = [:]
        for stop in all {
            counts[stop.lineSourceID, default: 0] += 1
        }
        return counts
    }

    // MARK: - Line travel queries

    func travels(forLineSourceID lineSourceID: String) throws -> [Travel] {
        let descriptor = FetchDescriptor<Travel>(
            predicate: #Predicate { $0.lineSourceID == lineSourceID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func travelCount(forLineSourceID lineSourceID: String) throws -> Int {
        let descriptor = FetchDescriptor<Travel>(
            predicate: #Predicate { $0.lineSourceID == lineSourceID }
        )
        return try context.fetchCount(descriptor)
    }

    func lastTravelDate(forLineSourceID lineSourceID: String) throws -> Date? {
        var descriptor = FetchDescriptor<Travel>(
            predicate: #Predicate { $0.lineSourceID == lineSourceID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.createdAt
    }

    // MARK: - Station travel queries

    func travels(forRouteVariantSourceIDs variantIDs: [String]) throws -> [Travel] {
        let descriptor = FetchDescriptor<Travel>(
            predicate: #Predicate { variantIDs.contains($0.routeVariantSourceID) },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: - Travel recording

    @discardableResult
    func recordTravel(
        lineSourceID: String,
        routeVariantSourceID: String,
        fromStationSourceID: String,
        toStationSourceID: String,
        intermediateStationSourceIDs: [String]
    ) throws -> Travel {
        let travel = Travel(
            lineSourceID: lineSourceID,
            routeVariantSourceID: routeVariantSourceID,
            fromStationSourceID: fromStationSourceID,
            toStationSourceID: toStationSourceID,
            stopsCompleted: intermediateStationSourceIDs.count
        )
        context.insert(travel)

        // Idempotent: insert CompletedStop only if not already present
        for stationID in intermediateStationSourceIDs {
            let compositeID = "\(lineSourceID):\(stationID)"
            var check = FetchDescriptor<CompletedStop>(
                predicate: #Predicate { $0.id == compositeID }
            )
            check.fetchLimit = 1
            if try context.fetch(check).isEmpty {
                let completed = CompletedStop(
                    lineSourceID: lineSourceID,
                    stationSourceID: stationID,
                    travelID: travel.id
                )
                context.insert(completed)
            }
        }

        try context.save()
        return travel
    }

    // MARK: - Bulk queries for gamification

    func allCompletedStops() throws -> [CompletedStop] {
        let descriptor = FetchDescriptor<CompletedStop>()
        return try context.fetch(descriptor)
    }

    func travel(byID id: String) throws -> Travel? {
        var descriptor = FetchDescriptor<Travel>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func completedStops(forTravelID travelID: String) throws -> [CompletedStop] {
        let descriptor = FetchDescriptor<CompletedStop>(
            predicate: #Predicate { $0.travelID == travelID }
        )
        return try context.fetch(descriptor)
    }

    // MARK: - Favorites

    @discardableResult
    func toggleFavorite(kind: String, sourceID: String) throws -> Bool {
        let compositeID = "\(kind):\(sourceID)"
        var descriptor = FetchDescriptor<Favorite>(
            predicate: #Predicate { $0.id == compositeID }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
            return false
        } else {
            let favorite = Favorite(kind: kind, sourceID: sourceID)
            context.insert(favorite)
            try context.save()
            return true
        }
    }

    func isFavorite(kind: String, sourceID: String) throws -> Bool {
        let compositeID = "\(kind):\(sourceID)"
        var descriptor = FetchDescriptor<Favorite>(
            predicate: #Predicate { $0.id == compositeID }
        )
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }

    func favoriteSourceIDs(kind: String) throws -> Set<String> {
        let descriptor = FetchDescriptor<Favorite>(
            predicate: #Predicate { $0.kind == kind }
        )
        return try Set(context.fetch(descriptor).map(\.sourceID))
    }

    // MARK: - Travel history

    func allTravels() throws -> [Travel] {
        let descriptor = FetchDescriptor<Travel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
}
