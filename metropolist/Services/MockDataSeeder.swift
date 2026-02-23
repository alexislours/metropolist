#if DEBUG
    import Foundation
    import SwiftData
    import TransitModels

    enum MockDataSeeder {
        private struct LineSelection {
            let line: TransitLine
            let completionFraction: Double
        }

        private struct LineTarget {
            let mode: String
            let name: String
            let fraction: Double
        }

        private static let lineTargets: [LineTarget] = [
            .init(mode: "metro", name: "1", fraction: 1.0),
            .init(mode: "metro", name: "6", fraction: 1.0),
            .init(mode: "metro", name: "4", fraction: 0.40),
            .init(mode: "metro", name: "14", fraction: 0.85),
            .init(mode: "rer", name: "A", fraction: 1.0),
            .init(mode: "rer", name: "B", fraction: 1.0),
            .init(mode: "rer", name: "C", fraction: 0.15),
            .init(mode: "bus", name: "95-19", fraction: 1.0),
            .init(mode: "bus", name: "62", fraction: 1.0),
            .init(mode: "tram", name: "T3a", fraction: 1.0),
            .init(mode: "tram", name: "T2", fraction: 1.0),
            .init(mode: "tram", name: "T1", fraction: 0.25),
        ]

        private static func selectLines(from allLines: [TransitLine]) -> [LineSelection] {
            lineTargets.compactMap { target in
                allLines
                    .first(where: { $0.mode == target.mode && $0.shortName == target.name })
                    .map { LineSelection(line: $0, completionFraction: target.fraction) }
            }
        }

        /// Seeds the in-memory user store with realistic travel data by querying the transit store
        /// for real line/station IDs. Call only when `--screenshots` is active.
        static func seed(dataStore: DataStore) {
            let transit = dataStore.transitService
            let user = dataStore.userService

            do {
                let selected = try selectLines(from: transit.allLines())
                var travelDayOffset = 0

                for entry in selected {
                    let line = entry.line

                    let variants = try transit.routeVariants(forLineSourceID: line.sourceID)
                    guard let variant = variants.first else { continue }

                    let stops = try transit.lineStops(forRouteVariantSourceID: variant.sourceID)
                    guard stops.count >= 2 else { continue }

                    let totalStops = stops.count
                    let targetCount = max(2, Int(Double(totalStops) * entry.completionFraction))

                    // Split into 2-3 "trips" for realism
                    let tripCount = targetCount > 10 ? 3 : 2
                    let stopsPerTrip = targetCount / tripCount
                    var usedStops = 0

                    for tripIndex in 0 ..< tripCount {
                        let startIdx = usedStops
                        let endIdx = min(startIdx + stopsPerTrip, totalStops - 1)
                        guard startIdx < endIdx else { break }

                        let fromStop = stops[startIdx]
                        let toStop = stops[endIdx]
                        let intermediateIDs = stops[startIdx ... endIdx].map(\.stationSourceID)

                        let travel = try user.recordTravel(
                            lineSourceID: line.sourceID,
                            routeVariantSourceID: variant.sourceID,
                            fromStationSourceID: fromStop.stationSourceID,
                            toStationSourceID: toStop.stationSourceID,
                            intermediateStationSourceIDs: intermediateIDs
                        )

                        // Spread travel dates across the past 2 weeks
                        let daysAgo = Double(14 - travelDayOffset - tripIndex * 2)
                        travel.createdAt = Date().addingTimeInterval(-daysAgo * 86400)

                        usedStops = endIdx
                    }

                    travelDayOffset += 1
                }

                try dataStore.userContext.save()

            } catch {
                print("MockDataSeeder: failed to seed data — \(error)")
            }
        }
    }
#endif
