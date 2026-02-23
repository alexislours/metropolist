import SwiftUI
import TransitModels

struct TravelCreationFlow: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss

    var prefill: TravelFlowPrefill?

    @State private var viewModel: TravelFlowViewModel?

    var body: some View {
        Group {
            if let viewModel {
                flowContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = TravelFlowViewModel(dataStore: dataStore, prefill: prefill)
            }
        }
    }

    @ViewBuilder
    private func flowContent(_ viewModel: TravelFlowViewModel) -> some View {
        @Bindable var viewModel = viewModel
        NavigationStack(path: $viewModel.path) {
            StationPickerView(viewModel: viewModel)
                .navigationDestination(for: TravelFlowViewModel.Step.self) { step in
                    switch step {
                    case .pickLine:
                        linePickerList(viewModel)

                    case .pickDestination:
                        destinationPickerList(viewModel)

                    case .pickVariant:
                        variantPickerList(viewModel)

                    case .confirm:
                        TravelConfirmView(viewModel: viewModel)

                    case .success:
                        TravelSuccessView(viewModel: viewModel) {
                            dismiss()
                        }
                    }
                }
        }
        .alert(String(localized: "Error", comment: "Travel flow: error alert title"), isPresented: $viewModel.showError) {
            Button(String(localized: "OK", comment: "Travel flow: dismiss error button")) {}
        } message: {
            Text(viewModel.errorMessage ?? String(localized: "An error occurred.", comment: "Travel flow: generic error message"))
        }
    }

    // MARK: - Inline pickers

    private var groupedStationLines: [(mode: TransitMode, lines: [TransitLine])] {
        guard let viewModel else { return [] }
        let grouped = Dictionary(grouping: viewModel.stationLines) { TransitMode(rawValue: $0.mode) ?? .bus }
        return TransitMode.allCases.compactMap { mode in
            guard let modeLines = grouped[mode], !modeLines.isEmpty else { return nil }
            return (mode: mode, lines: modeLines)
        }
    }

    private func linePickerList(_ viewModel: TravelFlowViewModel) -> some View {
        List {
            ForEach(groupedStationLines, id: \.mode) { group in
                Section {
                    ForEach(group.lines) { line in
                        Button {
                            viewModel.selectLine(line)
                        } label: {
                            HStack(spacing: 12) {
                                LineBadge(line: line)
                                Text(line.longName)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                    }
                } header: {
                    Label(group.mode.label, systemImage: group.mode.systemImage)
                }
            }
        }
        .buttonStyle(.plain)
        .navigationTitle(String(localized: "Pick a line", comment: "Travel flow: pick line navigation title"))
    }

    private func destinationPickerList(_ viewModel: TravelFlowViewModel) -> some View {
        List {
            if viewModel.isLoadingDestinations {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(String(localized: "Loading destinations...", comment: "Travel flow: loading destinations indicator"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            } else {
                ForEach(viewModel.destinationOptions) { option in
                    Button {
                        viewModel.selectDestination(option)
                    } label: {
                        HStack {
                            Text(option.station.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            if let town = option.station.town {
                                Text(town)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .navigationTitle(String(localized: "Where to?", comment: "Travel flow: pick destination navigation title"))
    }

    private func variantPickerList(_ viewModel: TravelFlowViewModel) -> some View {
        List {
            Section(String(localized: "Which direction?", comment: "Travel flow: pick direction section header")) {
                ForEach(viewModel.variantPreviews, id: \.variant.sourceID) { preview in
                    Button {
                        viewModel.selectVariant(preview.variant)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(
                                localized: "→ \(preview.variant.headsign)",
                                comment: "Travel flow: direction headsign with arrow prefix"
                            ))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                            if !preview.viaStationNames.isEmpty {
                                let viaText = formatViaStations(preview.viaStationNames)
                                Text(String(localized: "via \(viaText)", comment: "Travel flow: intermediate stops via label"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            if preview.totalStops > 0 {
                                Text(String(
                                    localized: "\(preview.totalStops) stops",
                                    comment: "Travel flow: total stops count for direction"
                                ))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .navigationTitle(String(localized: "Pick direction", comment: "Travel flow: pick direction navigation title"))
    }

    private func formatViaStations(_ names: [String]) -> String {
        switch names.count {
        case 0: return ""
        case 1 ... 3: return names.joined(separator: ", ")
        default:
            let first = names.prefix(2).joined(separator: ", ")
            return "\(first) ... \(names.last ?? "")"
        }
    }
}
