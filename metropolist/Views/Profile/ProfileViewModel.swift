import Foundation
import TransitModels

struct ModeBreakdownEntry: Identifiable {
    var id: TransitMode {
        mode
    }

    let mode: TransitMode
    let count: Int
    let percentage: Double
}

@MainActor
@Observable
final class ProfileViewModel {
    var snapshot: GamificationSnapshot = .empty
    var isLoading = true

    // Resolved data for display
    var lineMetadataMap: [String: LineMetadata] = [:]
    var linesByMode: [(mode: TransitMode, lines: [LineMetadata])] = []
    var travelLines: [String: TransitLine] = [:]
    var stationNames: [String: String] = [:]
    var recentTravels: [Travel] = []
    var modeBreakdown: [ModeBreakdownEntry] = []
    var travelSearchIndex: [String: String] = [:]

    private let dataStore: DataStore

    init(dataStore: DataStore) {
        self.dataStore = dataStore
    }

    func load() async {
        await Task.yield()
        do {
            let result = try GamificationSnapshot.build(from: dataStore)
            let metaMap = result.lineMetadata
            lineMetadataMap = metaMap
            snapshot = result.snapshot

            let travels = try dataStore.userService.allTravels()
            modeBreakdown = Self.buildModeBreakdown(travels: travels, metaMap: metaMap)

            // Group lines by mode for display
            let grouped = Dictionary(grouping: metaMap.values, by: \.mode)
            linesByMode = TransitMode.allCases.compactMap { mode in
                guard let modeLines = grouped[mode], !modeLines.isEmpty else { return nil }
                let sorted = modeLines.sorted { $0.shortName.localizedStandardCompare($1.shortName) == .orderedAscending }
                return (mode: mode, lines: sorted)
            }

            // Resolve travel display data
            recentTravels = travels
            var lineMap: [String: TransitLine] = [:]
            var nameMap: [String: String] = [:]
            var neededStationIDs: Set<String> = []
            for travel in recentTravels {
                if lineMap[travel.lineSourceID] == nil {
                    lineMap[travel.lineSourceID] = try dataStore.transitService.line(bySourceID: travel.lineSourceID)
                }
                neededStationIDs.insert(travel.fromStationSourceID)
                neededStationIDs.insert(travel.toStationSourceID)
            }
            let stations = try dataStore.transitService.stations(bySourceIDs: Array(neededStationIDs))
            for station in stations {
                nameMap[station.sourceID] = station.name
            }
            // Fill missing station names with fallback
            for travel in recentTravels {
                for id in [travel.fromStationSourceID, travel.toStationSourceID] where nameMap[id] == nil {
                    nameMap[id] = String(localized: "Unknown stop", comment: "Fallback name when stop cannot be resolved")
                }
            }
            travelLines = lineMap
            stationNames = nameMap

            // Build search index: one lowercased string per travel for fast filtering
            var searchIndex: [String: String] = [:]
            for travel in recentTravels {
                let lineName = lineMap[travel.lineSourceID]?.shortName ?? ""
                let fromName = nameMap[travel.fromStationSourceID] ?? ""
                let toName = nameMap[travel.toStationSourceID] ?? ""
                let mode = lineMap[travel.lineSourceID]
                    .flatMap { TransitMode(rawValue: $0.mode) }?.label ?? ""
                searchIndex[travel.id] = "\(lineName) \(fromName) \(toName) \(mode)".lowercased()
            }
            travelSearchIndex = searchIndex

        } catch {
            #if DEBUG
                print("Failed to load gamification data: \(error)")
            #endif
        }
        isLoading = false
    }

    private static func buildModeBreakdown(travels: [Travel], metaMap: [String: LineMetadata]) -> [ModeBreakdownEntry] {
        var counts: [TransitMode: Int] = [:]
        for travel in travels {
            if let meta = metaMap[travel.lineSourceID] {
                counts[meta.mode, default: 0] += 1
            }
        }
        let total = counts.values.reduce(0, +)
        guard total > 0 else { return [] }
        return counts
            .map { ModeBreakdownEntry(mode: $0.key, count: $0.value, percentage: Double($0.value) / Double(total)) }
            .sorted { $0.count > $1.count }
    }
}
