import MapKit
import SwiftUI
import TransitModels

struct TravelTimelineView: View {
    @Environment(DataStore.self) private var dataStore
    @State private var viewModel: TimelineViewModel?
    @State private var showDatePicker = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var travelDetailNavigation: TravelDetailNavigation?
    @State private var showReplay = false

    var body: some View {
        Group {
            if let viewModel, !viewModel.isLoading {
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        if !viewModel.dayTravels.isEmpty {
                            TimelineMapView(
                                segments: viewModel.travelMapData,
                                highlightedTravelID: viewModel.highlightedTravelID,
                                cameraPosition: $cameraPosition,
                                onAnnotationTap: { travelID in
                                    travelDetailNavigation = TravelDetailNavigation(travelID: travelID)
                                },
                                onBackgroundTap: {
                                    guard viewModel.highlightedTravelID != nil else { return }
                                    resetMapToDay(viewModel)
                                }
                            )
                            .frame(height: geo.size.height * 0.45)
                        }

                        VStack(spacing: 0) {
                            TimelineDateNavigator(
                                selectedDate: viewModel.selectedDate,
                                canGoBack: viewModel.canNavigatePrevious,
                                canGoForward: viewModel.canNavigateNext,
                                onPrevious: {
                                    viewModel.navigateToPreviousDay()
                                    resetMapToDay(viewModel)
                                },
                                onNext: {
                                    viewModel.navigateToNextDay()
                                    resetMapToDay(viewModel)
                                },
                                onCalendarTap: { showDatePicker = true }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                            if viewModel.dayTravels.isEmpty {
                                emptyState
                            } else {
                                daySummary(viewModel.daySummary)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)

                                ScrollView {
                                    LazyVStack(spacing: 0) {
                                        ForEach(
                                            Array(viewModel.dayTravels.enumerated()),
                                            id: \.element.id
                                        ) { index, travel in
                                            TimelineTravelEntry(
                                                travel: travel,
                                                line: viewModel.travelLines[travel.lineSourceID],
                                                fromName: viewModel.stationNames[travel.fromStationSourceID]
                                                    ?? travel.fromStationSourceID,
                                                toName: viewModel.stationNames[travel.toStationSourceID]
                                                    ?? travel.toStationSourceID,
                                                isFirst: index == 0,
                                                isLast: index == viewModel.dayTravels.count - 1,
                                                isHighlighted: viewModel.highlightedTravelID == travel.id
                                            )
                                            .onTapGesture {
                                                handleTravelTap(travel, viewModel: viewModel)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                    .padding(.bottom, 80)
                                }
                            }
                        }
                    }
                }
                .background(Color(UIColor.systemGroupedBackground))
            } else {
                TransitLoadingIndicator()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(String(localized: "Timeline", comment: "Timeline: navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $travelDetailNavigation) { nav in
            TravelDetailView(travelID: nav.travelID)
        }
        .toolbar {
            if let viewModel, !viewModel.dayTravels.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showReplay = true
                    } label: {
                        Image(systemName: "play.circle")
                    }
                    .accessibilityLabel(
                        String(localized: "Replay day", comment: "Timeline: replay button accessibility label")
                    )
                }
            }
        }
        .fullScreenCover(isPresented: $showReplay) {
            if let viewModel {
                TravelReplayView(
                    travels: viewModel.dayTravels,
                    segments: viewModel.travelMapData,
                    lines: viewModel.travelLines,
                    stationNames: viewModel.stationNames
                )
            }
        }
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet
        }
        .task(id: dataStore.userDataVersion) {
            if viewModel == nil {
                let model = TimelineViewModel(dataStore: dataStore)
                viewModel = model
                await model.load()
                resetMapToDay(model)
            } else {
                await viewModel?.load()
                if let viewModel {
                    resetMapToDay(viewModel)
                }
            }
        }
    }

    // MARK: - Interaction

    private func handleTravelTap(_ travel: Travel, viewModel: TimelineViewModel) {
        if viewModel.highlightedTravelID == travel.id {
            travelDetailNavigation = TravelDetailNavigation(travelID: travel.id)
        } else {
            withAnimation(.snappy(duration: 0.3)) {
                viewModel.highlightTravel(travel.id)
            }
            if let region = viewModel.regionForTravel(travel.id) {
                withAnimation(.snappy(duration: 0.5)) {
                    cameraPosition = .region(region)
                }
            }
        }
    }

    private func resetMapToDay(_ viewModel: TimelineViewModel) {
        withAnimation(.snappy(duration: 0.3)) {
            viewModel.clearHighlight()
        }
        if let region = viewModel.dayMapRegion {
            withAnimation(.snappy(duration: 0.5)) {
                cameraPosition = .region(region)
            }
        } else {
            cameraPosition = .automatic
        }
    }

    // MARK: - Day Summary

    private func daySummary(_ summary: TimelineViewModel.DaySummary) -> some View {
        HStack(spacing: 16) {
            Label(
                String(localized: "\(summary.travelCount) travels", comment: "Timeline: day travel count"),
                systemImage: "arrow.triangle.swap"
            )

            Label(
                String(localized: "\(summary.totalStops) stops", comment: "Timeline: day stops count"),
                systemImage: "mappin.and.ellipse"
            )

            if summary.totalDistance > 0 {
                Label(
                    DistanceCalculator.formatDistance(summary.totalDistance),
                    systemImage: "point.bottomleft.forward.to.point.topright.scurvepath"
                )
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity)
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 1))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            String(localized: "No travels on this day", comment: "Timeline: empty day title"),
            systemImage: "tram",
            description: Text(String(localized: "Tap + to record a travel", comment: "Timeline: empty day hint"))
        )
    }

    // MARK: - Date Picker Sheet

    private var datePickerSheet: some View {
        NavigationStack {
            TimelineCalendarPicker(
                daysWithTravels: viewModel?.daysWithTravels ?? [],
                selectedDate: viewModel?.selectedDate ?? Date(),
                onDateSelected: { date in
                    viewModel?.selectDate(date)
                    if let viewModel {
                        resetMapToDay(viewModel)
                    }
                    showDatePicker = false
                }
            )
            .padding()
            .navigationTitle(String(localized: "Jump to Date", comment: "Timeline: date picker navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done", comment: "Timeline: dismiss date picker")) {
                        showDatePicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Navigation

private struct TravelDetailNavigation: Hashable {
    let travelID: String
}
