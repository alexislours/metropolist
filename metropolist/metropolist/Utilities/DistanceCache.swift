import Foundation

/// Caches computed travel distances to avoid redundant SwiftData fetches
/// against the transit database on every `GamificationSnapshot.build()` call.
///
/// The cache is local-only (not synced via iCloud) and keyed by travel ID.
/// It invalidates automatically when the bundled transit database is updated.
struct DistanceCache {
    enum Lookup {
        case hit(Double?)
        case miss
    }

    private var distances: [String: Double] = [:]
    private var unresolved: Set<String> = []
    private var dirty = false

    /// Loads the cache from disk, returning an empty cache if the file
    /// is missing, corrupt, or stale (transit data version mismatch).
    static func load(transitIdentity: String, directory: URL? = nil) -> DistanceCache {
        var cache = DistanceCache()
        guard let url = fileURL(in: directory), let data = try? Data(contentsOf: url) else { return cache }
        guard let stored = try? JSONDecoder().decode(StoredData.self, from: data) else { return cache }
        guard stored.transitVersion == transitIdentity else { return cache }

        cache.distances = stored.distances
        cache.unresolved = stored.unresolved
        return cache
    }

    func lookup(travelID: String) -> Lookup {
        if let dist = distances[travelID] {
            return .hit(dist)
        }
        if unresolved.contains(travelID) {
            return .hit(nil)
        }
        return .miss
    }

    mutating func set(distance: Double?, forTravelID id: String) {
        if let distance {
            distances[id] = distance
        } else {
            unresolved.insert(id)
        }
        dirty = true
    }

    func persistIfNeeded(transitIdentity: String, directory: URL? = nil) {
        guard dirty else { return }
        let stored = StoredData(
            distances: distances,
            unresolved: unresolved,
            transitVersion: transitIdentity
        )
        guard let url = Self.fileURL(in: directory), let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: url, options: .atomic)

        var target = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? target.setResourceValues(values)
    }

    // MARK: - Private

    private static func fileURL(in directory: URL?) -> URL? {
        let root = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first
        return root?.appendingPathComponent("distance-cache.json")
    }

    private struct StoredData: Codable {
        let distances: [String: Double]
        let unresolved: Set<String>
        let transitVersion: String
    }
}
