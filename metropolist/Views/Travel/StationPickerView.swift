import SwiftUI
import TransitModels

struct StationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: TravelFlowViewModel

    @State private var searchText = ""
    @State private var searchResults: [TransitStation] = []
    @State private var loadedLines: [String: [TransitLine]] = [:]
    @State private var searchTask: Task<Void, Never>?
    @State private var lastSearchedQuery = ""

    private var hasLinePrefill: Bool {
        viewModel.prefill?.lineSourceID != nil
    }

    var body: some View {
        List {
            if searchText.isEmpty {
                if hasLinePrefill {
                    lineStopsSection
                } else if viewModel.isLoadingNearby {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(String(localized: "Finding nearby stops...", comment: "Stop picker: nearby stops loading"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                    }
                } else if !viewModel.nearbyStations.isEmpty {
                    Section(String(localized: "Nearby", comment: "Stop picker: nearby stops section header")) {
                        ForEach(viewModel.nearbyStations) { nearby in
                            Button {
                                viewModel.selectOrigin(nearby.station)
                            } label: {
                                nearbyStationRow(nearby)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        String(localized: "Search for a stop", comment: "Stop picker: empty state title"),
                        systemImage: "magnifyingglass",
                        description: Text(String(
                            localized: "Type a stop name to get started",
                            comment: "Stop picker: empty state description"
                        ))
                    )
                }
            } else {
                Section {
                    if searchResults.isEmpty {
                        if searchText == lastSearchedQuery {
                            ContentUnavailableView.search(text: searchText)
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        }
                    } else {
                        ForEach(searchResults) { station in
                            Button {
                                viewModel.selectOrigin(station)
                            } label: {
                                searchResultRow(station)
                            }
                            .task(id: station.sourceID) {
                                guard loadedLines[station.sourceID] == nil else { return }
                                await Task.yield()
                                guard !Task.isCancelled else { return }
                                loadedLines[station.sourceID] = viewModel.linesForStation(station.sourceID)
                            }
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text(String(localized: "Results (\(searchResults.count))", comment: "Station picker: search results count header"))
                        if searchText != lastSearchedQuery {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .navigationTitle(String(localized: "Departure", comment: "Station picker: navigation title"))
        .searchable(text: $searchText, prompt: String(localized: "Stop name", comment: "Stop picker: search field prompt"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
            }
            if !hasLinePrefill {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.refreshNearbyStations()
                    } label: {
                        Image(systemName: "location.magnifyingglass")
                    }
                    .disabled(viewModel.isLoadingNearby)
                }
            }
        }
        .onChange(of: searchText) {
            performSearch()
        }
        .task {
            if viewModel.prefill?.stationSourceID != nil {
                viewModel.autoSelectOriginFromPrefill()
            } else if hasLinePrefill {
                await viewModel.loadLineStations()
            } else {
                viewModel.loadNearbyStations()
            }
        }
    }

    // MARK: - Line Stops Section

    @ViewBuilder
    private var lineStopsSection: some View {
        if viewModel.isLoadingLineStations {
            Section {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(String(localized: "Loading stops...", comment: "Station picker: loading line stops indicator"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            }
        } else if !viewModel.prefillLineStations.isEmpty {
            Section {
                ForEach(viewModel.prefillLineStations) { station in
                    Button {
                        viewModel.selectOrigin(station)
                    } label: {
                        lineStopRow(station)
                    }
                }
            } header: {
                if let line = viewModel.prefillLine {
                    HStack(spacing: 8) {
                        LineBadge(line: line)
                        Text(String(localized: "Stops", comment: "Station picker: line stops section header"))
                    }
                }
            }
        }
    }

    // MARK: - Row Views

    private func lineStopRow(_ station: TransitStation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(station.name)
                .font(.body)
                .foregroundStyle(.primary)
            if let town = station.town {
                Text(town)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func nearbyStationRow(_ nearby: TravelFlowViewModel.NearbyStation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(nearby.station.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Text(TravelFlowViewModel.formatDistance(nearby.distance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let town = nearby.station.town {
                Text(town)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !nearby.lines.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(nearby.lines) { line in
                            LineBadge(line: line)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func searchResultRow(_ station: TransitStation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(station.name)
                .font(.body)
                .foregroundStyle(.primary)
            if let town = station.town {
                Text(town)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let lines = loadedLines[station.sourceID] {
                if !lines.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(lines) { line in
                                LineBadge(line: line)
                            }
                        }
                    }
                }
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func performSearch() {
        searchTask?.cancel()
        let query = searchText
        guard !query.isEmpty else {
            searchResults = []
            lastSearchedQuery = ""
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let results = viewModel.searchStations(query: query)
            guard !Task.isCancelled else { return }
            searchResults = results
            lastSearchedQuery = query
        }
    }
}
