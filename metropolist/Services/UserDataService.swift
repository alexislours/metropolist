import Foundation
import SwiftData

struct UserDataService {
    let context: ModelContext

    // MARK: - Completion queries

    func isStopCompleted(lineSourceID: String, stationSourceID: String) throws -> Bool {
        let compositeID = "\(lineSourceID):\(stationSourceID)"
        var descriptor = FetchDescriptor<CompletedStop>(
            predicate: #Predicate { $0.id == compositeID }
        )
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }

    func completedStopIDs(forLineSourceID lineSourceID: String) throws -> Set<String> {
        let descriptor = FetchDescriptor<CompletedStop>(
            predicate: #Predicate { $0.lineSourceID == lineSourceID }
        )
        let stops = try context.fetch(descriptor)
        return Set(stops.map(\.stationSourceID))
    }

    func completedStopCount(forLineSourceID lineSourceID: String) throws -> Int {
        let descriptor = FetchDescriptor<CompletedStop>(
            predicate: #Predicate { $0.lineSourceID == lineSourceID }
        )
        return try context.fetchCount(descriptor)
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

    func totalCompletedStops() throws -> Int {
        let descriptor = FetchDescriptor<CompletedStop>()
        return try context.fetchCount(descriptor)
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

    func travels(forStationSourceID stationSourceID: String) throws -> [Travel] {
        let descriptor = FetchDescriptor<Travel>(
            predicate: #Predicate {
                $0.fromStationSourceID == stationSourceID || $0.toStationSourceID == stationSourceID
            },
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

    // MARK: - Travel history

    func allTravels() throws -> [Travel] {
        let descriptor = FetchDescriptor<Travel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
}
