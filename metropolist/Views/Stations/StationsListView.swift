import os
import SwiftUI
import TransitModels

struct StationsListView: View {
    @Environment(DataStore.self) private var dataStore
    let searchText: String

    @State private var isLoading = true
    @State private var visitedStations: [TransitStation] = []
    @State private var loadedLines: [String: [TransitLine]] = [:]
    @State private var favoriteStations: [TransitStation] = []
    @State private var favoriteSectionExpanded = true

    // Search state
    @State private var searchResults: [TransitStation] = []
    @State private var lastSearchedQuery = ""

    var body: some View {
        Group {
            if isLoading {
                TransitLoadingIndicator()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchText.isEmpty {
                visitedStationsContent
            } else {
                searchResultsContent
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(50))
            loadVisitedStations()
        }
        .onChange(of: dataStore.userDataVersion) {
            loadVisitedStations()
        }
        .task(id: searchText) {
            let query = searchText
            guard !query.isEmpty else {
                searchResults = []
                lastSearchedQuery = ""
                return
            }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                let results = try dataStore.transitService.searchStations(query: query)
                guard !Task.isCancelled else { return }
                searchResults = results
                lastSearchedQuery = query
            } catch {
                lastSearchedQuery = query
                fallbackLogger.error("searchStations: \(String(describing: error), privacy: .public)")
            }
        }
    }

    // MARK: - Visited Stations

    @ViewBuilder
    private var visitedStationsContent: some View {
        if visitedStations.isEmpty, favoriteStations.isEmpty {
            ContentUnavailableView(
                String(localized: "No visited stops yet", comment: "Stations list: empty state title"),
                systemImage: "mappin.slash",
                description: Text(String(
                    localized: "Stops you visit will appear here. Use search to find any stop.",
                    comment: "Stations list: empty state description"
                ))
            )
        } else {
            List {
                if !favoriteStations.isEmpty {
                    Section {
                        DisclosureGroup(isExpanded: $favoriteSectionExpanded) {
                            ForEach(favoriteStations) { station in
                                NavigationLink(value: StationDestination(stationSourceID: station.sourceID)) {
                                    stationRow(station)
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .font(.body)
                                    .foregroundStyle(.yellow)
                                    .frame(width: 24)
                                Text(String(localized: "Favorites", comment: "Stations: favorites section"))
                                    .font(.headline)
                                Text("\(favoriteStations.count)")
                                    .font(.caption.weight(.medium).monospacedDigit())
                                    .foregroundStyle(.yellow)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.yellow.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }

                ForEach(visitedStations) { station in
                    NavigationLink(value: StationDestination(stationSourceID: station.sourceID)) {
                        stationRow(station)
                    }
                }
            }
            .contentMargins(.bottom, 80)
            .listSectionSpacing(.compact)
        }
    }

    // MARK: - Search Results

    private var searchResultsContent: some View {
        List {
            Section {
                if searchResults.isEmpty {
                    if searchText == lastSearchedQuery {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        TransitLoadingIndicator()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    }
                } else {
                    ForEach(searchResults) { station in
                        NavigationLink(value: StationDestination(stationSourceID: station.sourceID)) {
                            stationRow(station)
                        }
                        .task(id: station.sourceID) {
                            guard loadedLines[station.sourceID] == nil else { return }
                            await Task.yield()
                            guard !Task.isCancelled else { return }
                            do {
                                loadedLines[station.sourceID] = try dataStore.transitService.lines(forStationSourceID: station.sourceID)
                            } catch {
                                loadedLines[station.sourceID] = []
                                fallbackLogger.error("lines(forStationSourceID:): \(String(describing: error), privacy: .public)")
                            }
                        }
                    }
                }
            } header: {
                HStack(spacing: 6) {
                    Text(String(localized: "Results (\(searchResults.count))", comment: "Stations list: search results count header"))
                    if searchText != lastSearchedQuery {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
        }
        .contentMargins(.bottom, 80)
        .listSectionSpacing(.compact)
    }

    // MARK: - Station Row

    private func stationRow(_ station: TransitStation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(station.name)
                .font(.subheadline)
                .foregroundStyle(.primary)

            if let town = station.town {
                Text(town)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let lines = loadedLines[station.sourceID], !lines.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(lines) { line in
                            LineBadge(line: line)
                        }
                    }
                }
            } else if loadedLines[station.sourceID] == nil {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Data Loading

    private func loadVisitedStations() {
        do {
            // Load favorites
            let favIDs = try dataStore.userService.favoriteSourceIDs(kind: FavoriteKind.station.rawValue)
            if !favIDs.isEmpty {
                favoriteStations = try dataStore.transitService.stations(bySourceIDs: Array(favIDs))
                    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                let favStationIDSet = Set(favoriteStations.map(\.sourceID))
                let favLines = try dataStore.transitService.connectingLinesByStation(forStationSourceIDs: favStationIDSet)
                for (id, lines) in favLines {
                    loadedLines[id] = lines
                }
            } else {
                favoriteStations = []
            }

            // Load visited stations
            let completedStops = try dataStore.userService.allCompletedStops()
            let uniqueIDs = Array(Set(completedStops.map(\.stationSourceID)))
            let stations = try dataStore.transitService.stations(bySourceIDs: uniqueIDs)
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            visitedStations = stations

            if !stations.isEmpty {
                let stationIDSet = Set(stations.map(\.sourceID))
                let visitedLines = try dataStore.transitService.connectingLinesByStation(forStationSourceIDs: stationIDSet)
                for (id, lines) in visitedLines {
                    loadedLines[id] = lines
                }
            }
        } catch {
            #if DEBUG
                print("Failed to load visited stations: \(error)")
            #endif
        }
        isLoading = false
    }
}
