import SwiftUI
import TransitModels

struct TravelCreationFlow: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss

    var prefill: TravelFlowPrefill?

    @State private var viewModel: TravelFlowViewModel?
    @AppStorage("destinationSort") private var destinationSort: String = "route"

    var body: some View {
        Group {
            if let viewModel {
                flowContent(viewModel)
            } else {
                TransitLoadingIndicator()
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

    private func sortedDestinationOptions(_ viewModel: TravelFlowViewModel) -> [TravelFlowViewModel.DestinationOption] {
        if destinationSort == "alphabetical" {
            viewModel.destinationOptions.sorted {
                $0.station.name.localizedStandardCompare($1.station.name) == .orderedAscending
            }
        } else {
            viewModel.destinationOptions.sorted { $0.minStopDistance < $1.minStopDistance }
        }
    }

    private func destinationPickerList(_ viewModel: TravelFlowViewModel) -> some View {
        List {
            if viewModel.isLoadingDestinations {
                HStack(spacing: 12) {
                    TransitLoadingIndicator()
                    Text(String(localized: "Loading destinations...", comment: "Travel flow: loading destinations indicator"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            } else {
                ForEach(sortedDestinationOptions(viewModel)) { option in
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker(String(localized: "Sort", comment: "Station picker: sort order picker label"), selection: $destinationSort) {
                        Text(String(localized: "Route Order", comment: "Settings: sort by route order")).tag("route")
                        Text(String(localized: "Alphabetical", comment: "Settings: sort alphabetically")).tag("alphabetical")
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
    }

    @ViewBuilder
    private func variantPickerList(_ viewModel: TravelFlowViewModel) -> some View {
        let lineColor = viewModel.selectedLine.map { Color(hex: $0.color) } ?? .secondary

        ScrollView {
            LazyVStack(spacing: 16) {
                // Line context header
                if let line = viewModel.selectedLine {
                    HStack(spacing: 10) {
                        LineBadge(line: line)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.originStation?.name ?? "")
                                .font(.subheadline.weight(.semibold))
                            Text(String(
                                localized: "→ \(viewModel.destinationStation?.name ?? "")",
                                comment: "Travel flow: direction indicator with destination"
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }

                ForEach(viewModel.variantPreviews) { group in
                    variantGroupCard(group, viewModel: viewModel, lineColor: lineColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 80)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(viewModel.selectedLine.flatMap { TransitMode(rawValue: $0.mode) }?.chooseBranchTitle
            ?? String(localized: "Choose a direction", comment: "Travel flow: fallback choose branch title"))
    }

    private func variantGroupCard(
        _ group: TravelFlowViewModel.VariantPreview,
        viewModel: TravelFlowViewModel,
        lineColor: Color
    ) -> some View {
        VStack(spacing: 0) {
            // Expandable stop preview at the top
            if !group.viaStationNames.isEmpty {
                variantStopsPreview(group, viewModel: viewModel, lineColor: lineColor)
            }

            // Direction buttons
            ForEach(Array(group.variants.enumerated()), id: \.element.sourceID) { index, variant in
                if index > 0 || !group.viaStationNames.isEmpty {
                    Divider().padding(.horizontal, 16)
                }

                Button {
                    viewModel.selectVariant(variant)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                            .foregroundStyle(lineColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.selectedLine.flatMap { TransitMode(rawValue: $0.mode) }?.branchLabel
                                ?? String(localized: "Direction", comment: "Travel flow: fallback branch label"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(variant.headsign)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    private func variantStopsPreview(
        _ group: TravelFlowViewModel.VariantPreview,
        viewModel: TravelFlowViewModel,
        lineColor: Color
    ) -> some View {
        var stopNames: [String] = []
        if let originName = viewModel.originStation?.name {
            stopNames.append(originName)
        }
        stopNames.append(contentsOf: group.viaStationNames)
        if let destName = viewModel.destinationStation?.name {
            stopNames.append(destName)
        }

        return ExpandableStopsSection(
            lineColor: lineColor,
            stopNames: stopNames
        )
    }
}

// MARK: - Expandable stops section (needs own @State)

private struct ExpandableStopsSection: View {
    let lineColor: Color
    let stopNames: [String]

    @State private var isExpanded = false
    @State private var visibleCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Button {
                if isExpanded {
                    // Collapse: reset immediately
                    withAnimation(reduceMotion ? .none : .snappy(duration: 0.2)) {
                        visibleCount = 0
                        isExpanded = false
                    }
                } else {
                    // Expand: show container, then stagger rows in
                    withAnimation(reduceMotion ? .none : .snappy(duration: 0.2)) {
                        isExpanded = true
                    }
                    staggerIn()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(lineColor)

                    Text(String(
                        localized: "\(stopNames.count) stops",
                        comment: "Travel flow: total stops count for direction"
                    ))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(stopNames.enumerated()), id: \.offset) { index, name in
                        let isEndpoint = index == 0 || index == stopNames.count - 1
                        let isFirst = index == 0
                        let isLast = index == stopNames.count - 1
                        let isVisible = index < visibleCount

                        HStack(spacing: 12) {
                            ZStack {
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .fill(isFirst ? .clear : lineColor)
                                        .frame(width: 3)
                                    Rectangle()
                                        .fill(isLast ? .clear : lineColor)
                                        .frame(width: 3)
                                }

                                Circle()
                                    .fill(isEndpoint ? lineColor : lineColor.opacity(0.3))
                                    .frame(width: isEndpoint ? 12 : 6, height: isEndpoint ? 12 : 6)
                                    .overlay {
                                        if isEndpoint {
                                            Circle()
                                                .strokeBorder(.white, lineWidth: 2)
                                        }
                                    }
                            }
                            .frame(width: 20)

                            Text(name)
                                .font(isEndpoint ? .subheadline.weight(.semibold) : .subheadline)
                                .foregroundStyle(isEndpoint ? .primary : .secondary)

                            Spacer()
                        }
                        .frame(height: isEndpoint ? 36 : 28)
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: isVisible ? 0 : -6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            Divider().padding(.horizontal, 16)
        }
    }

    private func staggerIn() {
        if reduceMotion {
            visibleCount = stopNames.count
            return
        }
        let count = stopNames.count
        for index in 0 ..< count {
            let delay = Double(index) * 0.03
            withAnimation(.snappy(duration: 0.25).delay(delay)) {
                visibleCount = index + 1
            }
        }
    }
}
