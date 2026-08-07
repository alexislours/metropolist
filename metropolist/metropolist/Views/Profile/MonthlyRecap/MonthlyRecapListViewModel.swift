import SwiftUI

// MARK: - Recap Kind

enum RecapKind: Equatable, Hashable {
    case monthly(DateComponents)
    case yearly(Int)
}

// MARK: - Recap Summary

struct RecapSummary: Identifiable {
    let kind: RecapKind
    let formattedTitle: String
    let abbreviatedLabel: String
    let travelCount: Int
    let discoveryCount: Int
    let activeDays: Int
    let dominantMode: TransitMode?
    let topLineColor: Color?
    let topModeColors: [Color]

    var id: String {
        switch kind {
        case let .monthly(month):
            "m-\(month.year ?? 0)-\(month.month ?? 0)"
        case let .yearly(year):
            "y-\(year)"
        }
    }

    var dominantModeColor: Color {
        topLineColor ?? dominantMode?.tintColor ?? .metroSignature
    }

    var isYearly: Bool {
        if case .yearly = kind {
            return true
        }
        return false
    }

    var year: Int {
        switch kind {
        case let .monthly(month): month.year ?? 0
        case let .yearly(year): year
        }
    }
}

// MARK: - Year Group

struct YearGroup {
    let year: Int
    let summaries: [RecapSummary]
}

// MARK: - View Model

@MainActor
@Observable
final class RecapListViewModel {
    var isLoading = true
    var isEmpty = false
    var error: Error?
    var recapSummaries: [RecapSummary] = []

    var groupedByYear: [YearGroup] {
        let grouped = Dictionary(grouping: recapSummaries) { $0.year }
        return grouped.keys.sorted(by: >).map { year in
            YearGroup(year: year, summaries: grouped[year] ?? [])
        }
    }

    private let dataStore: DataStore

    init(dataStore: DataStore) {
        self.dataStore = dataStore
    }

    func load() async {
        do {
            let travels = try dataStore.userService.allTravels()
            let completedStops = try dataStore.userService.allCompletedStops()
            let metaMap = try dataStore.allLineMetadata()

            let summaries = RecapSummaryBuilder.buildSummaries(
                travels: travels,
                completedStops: completedStops,
                metaMap: metaMap
            )

            guard !summaries.isEmpty else {
                isEmpty = true
                isLoading = false
                return
            }

            recapSummaries = summaries
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
