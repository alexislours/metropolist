import SwiftUI
import TransitModels

struct TravelHistoryDetailView: View {
    @Environment(DataStore.self) private var dataStore
    var viewModel: ProfileViewModel

    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedIDs: Set<String> = []
    @State private var editMode: EditMode = .inactive
    @State private var showDeleteConfirmation = false

    private var filteredTravels: [Travel] {
        guard !debouncedSearch.isEmpty else { return viewModel.recentTravels }
        let query = debouncedSearch.lowercased()
        return viewModel.recentTravels.filter {
            viewModel.travelSearchIndex[$0.id]?.contains(query) == true
        }
    }

    var body: some View {
        List(selection: $selectedIDs) {
            ForEach(filteredTravels, id: \.id) { travel in
                NavigationLink(value: GamificationDestination.travelDetail(travel.id)) {
                    TravelHistoryRow(
                        travel: travel,
                        line: viewModel.travelLines[travel.lineSourceID],
                        fromName: viewModel.stationNames[travel.fromStationSourceID] ?? travel.fromStationSourceID,
                        toName: viewModel.stationNames[travel.toStationSourceID] ?? travel.toStationSourceID
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
        .navigationTitle(String(localized: "Travel History", comment: "Travel history: navigation title"))
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
                    .disabled(viewModel.recentTravels.isEmpty)
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
    }

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
        selectedIDs.removeAll()
        editMode = .inactive
        dataStore.userDataVersion += 1
    }
}
