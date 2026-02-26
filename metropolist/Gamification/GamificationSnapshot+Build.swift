extension GamificationSnapshot {
    /// Intermediate result that also exposes the `LineMetadata` map for callers that need it.
    struct BuildResult {
        let snapshot: GamificationSnapshot
        let lineMetadata: [String: LineMetadata]
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
        let travelRecords = travels.map {
            TravelRecord(
                lineSourceID: $0.lineSourceID,
                createdAt: $0.createdAt,
                fromStationSourceID: $0.fromStationSourceID,
                toStationSourceID: $0.toStationSourceID
            )
        }

        let input = GamificationInput(
            completedStops: stopRecords,
            travels: travelRecords,
            lineMetadata: metaMap,
            stationMetadata: stationMeta
        )

        let snapshot = GamificationEngine.computeSnapshot(from: input)
        return BuildResult(snapshot: snapshot, lineMetadata: metaMap)
    }
}
