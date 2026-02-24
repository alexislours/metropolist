import SwiftUI
import TransitModels

struct TravelHistoryDetailView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss

    let source: TravelHistorySource

    @State private var travels: [Travel] = []
    @State private var travelLines: [String: TransitLine] = [:]
    @State private var stationNames: [String: String] = [:]
    @State private var searchIndex: [String: String] = [:]

    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedIDs: Set<String> = []
    @State private var editMode: EditMode = .inactive
    @State private var showDeleteConfirmation = false
    @State private var shouldDismissWhenEmpty = false

    private var filteredTravels: [Travel] {
        guard !debouncedSearch.isEmpty else { return travels }
        let query = debouncedSearch.lowercased()
        return travels.filter {
            searchIndex[$0.id]?.contains(query) == true
        }
    }

    var body: some View {
        List(selection: $selectedIDs) {
            ForEach(filteredTravels, id: \.id) { travel in
                NavigationLink(value: GamificationDestination.travelDetail(travel.id)) {
                    TravelHistoryRow(
                        travel: travel,
                        line: travelLines[travel.lineSourceID],
                        fromName: stationNames[travel.fromStationSourceID] ?? travel.fromStationSourceID,
                        toName: stationNames[travel.toStationSourceID] ?? travel.toStationSourceID
                    )
                }
            }
        }
        .contentMargins(.bottom, 80)
        .searchable(text: $searchText, prompt: String(localized: "Search travels", comment: "Travel history: search field prompt"))
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                debouncedSearch = newValue
            }
        }
        .navigationTitle(String(localized: "History", comment: "Travel history: navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if editMode == .active {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(selectedIDs.isEmpty)

                    Button(String(localized: "Done", comment: "Travel history: exit selection mode")) {
                        selectedIDs.removeAll()
                        editMode = .inactive
                    }
                    .fontWeight(.semibold)
                } else {
                    Button(String(localized: "Select", comment: "Travel history: enter selection mode")) {
                        editMode = .active
                    }
                    .disabled(travels.isEmpty)
                }
            }
        }
        .alert(
            String(
                localized: "Delete \(selectedIDs.count) travel\(selectedIDs.count == 1 ? "" : "s")?",
                comment: "Travel history: delete confirmation title"
            ),
            isPresented: $showDeleteConfirmation
        ) {
            Button(String(localized: "Delete", comment: "Travel history: confirm delete button"), role: .destructive) {
                deleteSelected()
            }
            Button(String(localized: "Cancel", comment: "Travel history: cancel delete button"), role: .cancel) {}
        } message: {
            Text(String(localized: "This action cannot be undone.", comment: "Travel history: delete warning message"))
        }
        .onChange(of: travels.isEmpty) { _, isEmpty in
            guard isEmpty, shouldDismissWhenEmpty else { return }
            // Delay so the confirmation alert finishes dismissing before we pop.
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                dismiss()
            }
        }
        .task {
            loadData()
        }
        .onChange(of: dataStore.userDataVersion) {
            loadData()
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        do {
            switch source {
            case .all:
                travels = try dataStore.userService.allTravels()
            case let .line(lineSourceID):
                travels = try dataStore.userService.travels(forLineSourceID: lineSourceID)
            case let .station(stationSourceID):
                travels = try dataStore.travelsPassingThrough(stationSourceID: stationSourceID)
            }

            var lineMap: [String: TransitLine] = [:]
            var nameMap: [String: String] = [:]
            var neededStationIDs: Set<String> = []

            for travel in travels {
                if lineMap[travel.lineSourceID] == nil {
                    lineMap[travel.lineSourceID] = try dataStore.transitService.line(bySourceID: travel.lineSourceID)
                }
                neededStationIDs.insert(travel.fromStationSourceID)
                neededStationIDs.insert(travel.toStationSourceID)
            }

            if !neededStationIDs.isEmpty {
                let stations = try dataStore.transitService.stations(bySourceIDs: Array(neededStationIDs))
                for station in stations {
                    nameMap[station.sourceID] = station.name
                }
            }

            for travel in travels {
                for id in [travel.fromStationSourceID, travel.toStationSourceID] where nameMap[id] == nil {
                    nameMap[id] = String(localized: "Unknown stop", comment: "Fallback name when stop cannot be resolved")
                }
            }

            travelLines = lineMap
            stationNames = nameMap
            searchIndex = buildSearchIndex(travels: travels, lineMap: lineMap, nameMap: nameMap)
        } catch {
            #if DEBUG
                print("Failed to load travel history: \(error)")
            #endif
        }
    }

    private func buildSearchIndex(
        travels: [Travel], lineMap: [String: TransitLine], nameMap: [String: String]
    ) -> [String: String] {
        var index: [String: String] = [:]
        for travel in travels {
            let lineName = lineMap[travel.lineSourceID]?.shortName ?? ""
            let fromName = nameMap[travel.fromStationSourceID] ?? ""
            let toName = nameMap[travel.toStationSourceID] ?? ""
            let mode = lineMap[travel.lineSourceID]
                .flatMap { TransitMode(rawValue: $0.mode) }?.label ?? ""
            index[travel.id] = "\(lineName) \(fromName) \(toName) \(mode)".lowercased()
        }
        return index
    }

    // MARK: - Deletion

    private func deleteSelected() {
        for id in selectedIDs {
            do {
                try dataStore.deleteTravelCascading(id: id)
            } catch {
                #if DEBUG
                    print("Failed to delete travel: \(error)")
                #endif
            }
        }
        travels.removeAll { selectedIDs.contains($0.id) }
        selectedIDs.removeAll()
        editMode = .inactive
        dataStore.userDataVersion += 1
        shouldDismissWhenEmpty = true
    }
}
