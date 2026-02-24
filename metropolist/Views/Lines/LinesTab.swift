import SwiftUI
import TransitModels

struct LinesTab: View {
    @Environment(DataStore.self) private var dataStore
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var lines: [TransitLine] = []
    @State private var stationCounts: [String: Int] = [:]
    @State private var completedCounts: [String: Int] = [:]
    @State private var expandedModes: Set<TransitMode> = []
    @State private var inProgressExpanded = true
    @State private var completedExpanded = false
    @State private var filtered = FilteredResult()

    private struct FilteredResult {
        var inProgress: [TransitLine] = []
        var completed: [TransitLine] = []
        var grouped: [(mode: TransitMode, lines: [TransitLine])] = []
    }

    private func refilter() {
        let base = if searchText.isEmpty {
            lines
        } else {
            lines.filter {
                $0.shortName.localizedStandardContains(searchText) ||
                    $0.longName.localizedStandardContains(searchText)
            }
        }

        var inProgress: [TransitLine] = []
        var completed: [TransitLine] = []
        var byMode: [TransitMode: [TransitLine]] = [:]

        for line in base {
            let comp = completedCounts[line.sourceID] ?? 0
            let total = stationCounts[line.sourceID] ?? 0

            if comp > 0, comp < total {
                inProgress.append(line)
            } else if total > 0, comp >= total {
                completed.append(line)
            }

            let mode = TransitMode(rawValue: line.mode) ?? .bus
            byMode[mode, default: []].append(line)
        }

        inProgress.sort { lhs, rhs in
            let totalL = stationCounts[lhs.sourceID] ?? 0
            let compL = completedCounts[lhs.sourceID] ?? 0
            let fracA = totalL > 0 ? Double(compL) / Double(totalL) : 0

            let totalR = stationCounts[rhs.sourceID] ?? 0
            let compR = completedCounts[rhs.sourceID] ?? 0
            let fracB = totalR > 0 ? Double(compR) / Double(totalR) : 0

            if fracA != fracB { return fracA > fracB }
            return lhs.shortName.localizedStandardCompare(rhs.shortName) == .orderedAscending
        }

        completed.sort { lhs, rhs in
            lhs.shortName.localizedStandardCompare(rhs.shortName) == .orderedAscending
        }

        let grouped = TransitMode.allCases.compactMap { mode -> (mode: TransitMode, lines: [TransitLine])? in
            guard let modeLines = byMode[mode], !modeLines.isEmpty else { return nil }
            return (mode: mode, lines: modeLines)
        }

        filtered = FilteredResult(inProgress: inProgress, completed: completed, grouped: grouped)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if !filtered.inProgress.isEmpty {
                            modeSection(
                                title: String(localized: "In Progress", comment: "Lines: in-progress lines section"),
                                icon: "play.circle.fill",
                                tint: .blue,
                                lines: filtered.inProgress,
                                isExpanded: $inProgressExpanded
                            )
                        }

                        if !filtered.completed.isEmpty {
                            modeSection(
                                title: String(localized: "Completed", comment: "Lines: completed lines section"),
                                icon: "checkmark.circle.fill",
                                tint: .green,
                                lines: filtered.completed,
                                isExpanded: $completedExpanded
                            )
                        }

                        if !filtered.inProgress.isEmpty || !filtered.completed.isEmpty {
                            Section {
                                Text(String(localized: "All Lines", comment: "Lines: all lines divider label"))
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }

                        ForEach(filtered.grouped, id: \.mode) { group in
                            modeSection(for: group.mode, lines: group.lines)
                        }
                    }
                    .contentMargins(.bottom, 80)
                    .listSectionSpacing(.compact)
                    .searchable(text: $searchText, prompt: String(localized: "Search lines", comment: "Lines: search field prompt"))
                    .refreshable {
                        loadData()
                    }
                }
            }
            .navigationTitle(String(localized: "Lines", comment: "Lines: navigation title"))
            .navigationDestination(for: String.self) { lineSourceID in
                LineDetailView(lineSourceID: lineSourceID)
            }
            .navigationDestination(for: StationDestination.self) { dest in
                StationDetailView(stationSourceID: dest.stationSourceID)
            }
            .navigationDestination(for: GamificationDestination.self) { dest in
                switch dest {
                case let .travelDetail(travelID):
                    TravelDetailView(travelID: travelID)
                case let .travelHistory(source):
                    TravelHistoryDetailView(source: source)
                default:
                    EmptyView()
                }
            }
            .task {
                loadData()
            }
            .onChange(of: dataStore.userDataVersion) {
                loadData()
            }
            .onChange(of: searchText) {
                refilter()
            }
        }
    }

    // MARK: - Mode Section

    @ViewBuilder
    private func modeSection(for mode: TransitMode, lines: [TransitLine]) -> some View {
        let isExpanded = Binding(
            get: { expandedModes.contains(mode) },
            set: { newValue in
                if newValue {
                    expandedModes.insert(mode)
                } else {
                    expandedModes.remove(mode)
                }
            }
        )

        modeSection(
            title: mode.label,
            icon: mode.systemImage,
            tint: mode.tintColor,
            lines: lines,
            isExpanded: isExpanded,
            count: lines.count
        )
    }

    private func modeSection(
        title: String,
        icon: String,
        tint: Color,
        lines: [TransitLine],
        isExpanded: Binding<Bool>,
        count: Int? = nil
    ) -> some View {
        Section {
            DisclosureGroup(isExpanded: isExpanded) {
                lineRows(lines)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(tint)
                        .frame(width: 24)

                    Text(title)
                        .font(.headline)

                    if let count {
                        Text("\(count)")
                            .font(.caption.weight(.medium).monospacedDigit())
                            .foregroundStyle(tint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(tint.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Line Rows

    private func lineRows(_ rowLines: [TransitLine]) -> some View {
        ForEach(rowLines) { line in
            NavigationLink(value: line.sourceID) {
                HStack {
                    LineBadge(line: line)

                    Text(line.longName)
                        .font(.subheadline)
                        .lineLimit(1)

                    Spacer()

                    let total = stationCounts[line.sourceID] ?? 0
                    let completed = completedCounts[line.sourceID] ?? 0
                    if total > 0, completed > 0 {
                        HStack(spacing: 6) {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("\(Int(Double(completed) / Double(total) * 100))%")
                                    .font(.caption2.weight(.semibold).monospacedDigit())
                                Text("\(completed)/\(total)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            CompletionRing(completed: completed, total: total)
                        }
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
            .accessibilityIdentifier("line-\(line.shortName)")
        }
    }

    private func loadData() {
        do {
            lines = try dataStore.transitService.allLines()
            stationCounts = try dataStore.stationCountsByLine()
            completedCounts = try dataStore.userService.completedCountsByLine()
        } catch {
            #if DEBUG
                print("Failed to load lines: \(error)")
            #endif
        }
        refilter()
        isLoading = false
    }
}
