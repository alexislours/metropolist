import SwiftUI
import TransitModels

struct LineDetailView: View {
    @Environment(DataStore.self) private var dataStore
    let lineSourceID: String

    @State private var viewModel: LineDetailViewModel?
    @State private var showPercentage = false
    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 80
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(viewModel?.line?.shortName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: StationDestination.self) { dest in
            StationDetailView(stationSourceID: dest.stationSourceID)
        }
        .navigationDestination(for: GamificationDestination.self) { dest in
            if case let .travelDetail(id) = dest {
                TravelDetailView(travelID: id)
            }
        }
        .task {
            if viewModel == nil {
                let model = LineDetailViewModel(lineSourceID: lineSourceID, dataStore: dataStore)
                await model.loadData()
                viewModel = model
            }
        }
        .onChange(of: dataStore.userDataVersion) {
            viewModel?.refresh()
        }
    }

    @ViewBuilder
    private func content(_ viewModel: LineDetailViewModel) -> some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(spacing: 16) {
                if let line = viewModel.line {
                    headerCard(line, viewModel: viewModel)
                }

                if !viewModel.stationAnnotations.isEmpty {
                    mapCard(viewModel)
                }

                startTravelButton(viewModel)

                variantPickerAndStops(viewModel)

                if !viewModel.recentTravels.isEmpty {
                    travelHistoryCard(viewModel)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 80)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Header Card

    private func headerCard(_ line: TransitLine, viewModel: LineDetailViewModel) -> some View {
        CardSection {
            VStack(spacing: 12) {
                // Top accent bar
                Color(hex: line.color)
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    .clipShape(Capsule())

                // Mode label
                let mode = TransitMode(rawValue: line.mode)
                Text(mode?.label ?? line.mode)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                LineBadge(line: line)
                    .scaleEffect(1.5)

                // Line name + operator
                VStack(spacing: 4) {
                    if line.longName != line.shortName {
                        Text(line.longName)
                            .font(.subheadline.weight(.medium))
                    }

                    HStack(spacing: 4) {
                        Text(line.operatorName)
                        if let network = line.networkName {
                            Text("·")
                            Text(network)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Divider()

                // Completion ring (tappable)
                CompletionRing(
                    completed: viewModel.completedStopIDs.count,
                    total: viewModel.totalStations,
                    size: ringSize,
                    showPercentage: showPercentage
                )
                .padding(.vertical, 4)
                .onTapGesture {
                    withAnimation(reduceMotion ? .none : .default) {
                        showPercentage.toggle()
                    }
                }

                // Stats row
                FlowLayout(spacing: 12) {
                    Label(
                        String(localized: "\(viewModel.totalStations) stops", comment: "Line detail: stop count"),
                        systemImage: "mappin.circle"
                    )
                    Label(
                        TransitMode(rawValue: line.mode)?.branchCountLabel(viewModel.variants.count)
                            ?? String(localized: "\(viewModel.variants.count) directions", comment: "Line detail: fallback branch count"),
                        systemImage: "arrow.triangle.branch"
                    )

                    if line.isAccessible {
                        Label(
                            String(localized: "Accessible", comment: "Line detail: accessibility indicator"),
                            systemImage: "figure.roll"
                        )
                    }

                    if viewModel.travelCount > 0 {
                        Label(
                            String(localized: "\(viewModel.travelCount) trips", comment: "Line detail: trip count"),
                            systemImage: "figure.walk"
                        )
                    }

                    if let lastDate = viewModel.lastTravelDate {
                        Label {
                            Text(lastDate, format: .dateTime.month(.abbreviated).day())
                        } icon: {
                            Image(systemName: "clock")
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Map Card

    private func mapCard(_ viewModel: LineDetailViewModel) -> some View {
        LineRouteMapView(
            segments: viewModel.segments,
            stationAnnotations: viewModel.stationAnnotations,
            lineColor: Color(hex: viewModel.line?.color ?? "000000")
        )
    }

    // MARK: - Start Travel

    private func startTravelButton(_ viewModel: LineDetailViewModel) -> some View {
        Button {
            dataStore.travelFlowPrefill = TravelFlowPrefill(lineSourceID: lineSourceID)
        } label: {
            Label(String(localized: "Start travel", comment: "Line detail: start travel button"), systemImage: "play.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(hex: viewModel.line?.textColor ?? "FFFFFF"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: viewModel.line?.color ?? "007AFF"), in: RoundedRectangle(cornerRadius: 10))
        }
        .controlSize(.large)
        .accessibilityIdentifier("button-start-travel")
    }

    // MARK: - Variant Picker + Stops

    @ViewBuilder
    private func variantPickerAndStops(_ viewModel: LineDetailViewModel) -> some View {
        @Bindable var viewModel = viewModel
        let lineColor = Color(hex: viewModel.line?.color ?? "007AFF")

        VStack(spacing: 12) {
            // Direction picker
            if viewModel.variants.count > 1 {
                directionPicker(viewModel, lineColor: lineColor)
            }

            // Stops list
            CardSection(title: String(localized: "Stops", comment: "Line detail: stops section header")) {
                VStack(spacing: 0) {
                    if let variant = viewModel.selectedVariant {
                        let stops = viewModel.variantStops[variant.sourceID] ?? []
                        let completed = stops.filter {
                            viewModel.completedStopIDs.contains($0.stationSourceID)
                        }.count
                        HStack {
                            Text(String(
                                localized: "\(completed)/\(stops.count) completed",
                                comment: "Line detail: completed stops fraction"
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.bottom, 8)
                    }

                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.currentStops, id: \.order) { stop in
                            NavigationLink(value: StationDestination(stationSourceID: stop.stationSourceID)) {
                                EnhancedStopRow(
                                    name: viewModel.stationsMap[stop.stationSourceID]?.name ?? stop.stationSourceID,
                                    isCompleted: viewModel.completedStopIDs.contains(stop.stationSourceID),
                                    isTerminus: stop.isTerminus,
                                    connectionCount: (viewModel.connectingLinesMap[stop.stationSourceID] ?? []).count
                                )
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)

                            if stop.order != viewModel.currentStops.last?.order {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Branch Picker

    @ViewBuilder
    private func directionPicker(_ viewModel: LineDetailViewModel, lineColor: Color) -> some View {
        @Bindable var viewModel = viewModel
        Menu {
            ForEach(viewModel.variants.indices, id: \.self) { index in
                Button {
                    viewModel.selectedVariantIndex = index
                } label: {
                    HStack {
                        Text(viewModel.variants[index].headsign)
                        if index == viewModel.selectedVariantIndex {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                // Direction indicator
                Circle()
                    .fill(lineColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.line.flatMap({ TransitMode(rawValue: $0.mode) })?.branchLabel
                         ?? String(localized: "Direction", comment: "Line detail: fallback branch label"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(viewModel.selectedVariant?.headsign ?? "")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Travel History

    private func travelHistoryCard(_ viewModel: LineDetailViewModel) -> some View {
        CardSection(title: String(localized: "Recent Travels", comment: "Line detail: recent travels section header")) {
            VStack(spacing: 8) {
                ForEach(viewModel.recentTravels, id: \.id) { travel in
                    NavigationLink(value: GamificationDestination.travelDetail(travel.id)) {
                        TravelHistoryRow(
                            travel: travel,
                            line: viewModel.travelLineMap[travel.lineSourceID],
                            fromName: viewModel.travelStationNames[travel.fromStationSourceID] ?? travel.fromStationSourceID,
                            toName: viewModel.travelStationNames[travel.toStationSourceID] ?? travel.toStationSourceID
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
