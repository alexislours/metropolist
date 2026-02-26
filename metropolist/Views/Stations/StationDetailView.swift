import MapKit
import SwiftUI
import TransitModels

struct StationDetailView: View {
    @Environment(DataStore.self) private var dataStore
    let stationSourceID: String

    @State private var station: TransitStation?
    @State private var isFavorited = false
    @State private var connectingLines: [TransitLine] = []
    @State private var recentTravels: [Travel] = []
    @State private var travelLineMap: [String: TransitLine] = [:]
    @State private var groupedLines: [(mode: TransitMode, lines: [TransitLine])] = []
    @State private var travelStationNames: [String: String] = [:]
    @AppStorage("mapStyle") private var mapStyle: String = "standard"
    @AppStorage("devMode") private var devMode: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let station {
                    headerCard(station)
                    mapCard(station)

                    Button {
                        dataStore.travelFlowPrefill = TravelFlowPrefill(stationSourceID: stationSourceID)
                    } label: {
                        Label(String(localized: "Start travel", comment: "Station detail: start travel button"), systemImage: "play.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.tint, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }
                }

                if !connectingLines.isEmpty {
                    connectingLinesCard
                }

                if !recentTravels.isEmpty {
                    TravelHistoryCard(
                        travels: recentTravels,
                        travelLines: travelLineMap,
                        stationNames: travelStationNames,
                        historySource: .station(stationSourceID)
                    )
                }

                if devMode, let station {
                    DebugInfoSection(items: [
                        ("sourceID", station.sourceID),
                        ("name", station.name),
                        ("latitude", String(station.latitude)),
                        ("longitude", String(station.longitude)),
                        ("fareZone", station.fareZone ?? "nil"),
                        ("town", station.town ?? "nil"),
                        ("postalCode", station.postalCode ?? "nil"),
                        ("isAccessible", String(station.isAccessible)),
                        ("hasAudibleSignals", String(station.hasAudibleSignals)),
                        ("hasVisualSigns", String(station.hasVisualSigns)),
                        ("connectingLines", String(connectingLines.count)),
                        ("recentTravels", String(recentTravels.count)),
                    ])
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 80)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(station?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isFavorited = logged { try dataStore.userService.toggleFavorite(
                        kind: FavoriteKind.station.rawValue,
                        sourceID: stationSourceID
                    ) } ?? isFavorited
                    UIImpactFeedbackGenerator(style: isFavorited ? .medium : .light).impactOccurred()
                } label: {
                    Image(systemName: isFavorited ? "star.fill" : "star")
                        .foregroundStyle(isFavorited ? .yellow : .secondary)
                }
                .accessibilityLabel(
                    isFavorited
                        ? String(localized: "Remove from favorites", comment: "Station detail: unfavorite button")
                        : String(localized: "Add to favorites", comment: "Station detail: favorite button")
                )
            }
        }
        .task {
            await loadData()
        }
        .onChange(of: dataStore.userDataVersion) {
            isFavorited = logged { try dataStore.userService.isFavorite(
                kind: FavoriteKind.station.rawValue,
                sourceID: stationSourceID
            ) } ?? false
        }
    }

    // MARK: - Header Card

    private func headerCard(_ station: TransitStation) -> some View {
        CardSection {
            VStack(spacing: 12) {
                // Section label
                Text(String(localized: "STOP", comment: "Stop detail: section label"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                // Station name
                Text(station.name)
                    .font(.title2.bold())

                // Subtitle: town + fare zone
                HStack(spacing: 4) {
                    if let town = station.town {
                        Text(town)
                    }
                    if station.town != nil, station.fareZone != nil {
                        Text("·")
                    }
                    if let fareZone = station.fareZone {
                        Text(String(localized: "Zone \(fareZone)", comment: "Station detail: fare zone label"))
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Divider()

                // Modes served
                if !groupedLines.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(groupedLines, id: \.mode) { group in
                            Label(group.mode.label, systemImage: group.mode.systemImage)
                                .foregroundStyle(group.mode.tintColor)
                        }
                    }
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                }

                // Stats row
                FlowLayout(spacing: 12) {
                    Label(
                        String(localized: "\(connectingLines.count) lines", comment: "Station detail: connecting lines count"),
                        systemImage: "line.3.horizontal"
                    )

                    if station.isAccessible {
                        Label(
                            String(localized: "Accessible", comment: "Station detail: accessibility indicator"),
                            systemImage: "figure.roll"
                        )
                    }
                    if station.hasAudibleSignals {
                        Label(
                            String(localized: "Audio", comment: "Station detail: audible signals indicator"),
                            systemImage: "speaker.wave.2"
                        )
                    }
                    if station.hasVisualSigns {
                        Label(String(localized: "Visual", comment: "Station detail: visual signs indicator"), systemImage: "eye")
                    }

                    if !recentTravels.isEmpty {
                        Label(
                            String(localized: "\(recentTravels.count) trips", comment: "Station detail: trip count"),
                            systemImage: "figure.walk"
                        )
                    }

                    if let lastTravel = recentTravels.first {
                        Label {
                            Text(lastTravel.createdAt, format: .dateTime.month(.abbreviated).day())
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

    private func mapCard(_ station: TransitStation) -> some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )), interactionModes: []) {
            Marker(station.name, coordinate: CLLocationCoordinate2D(
                latitude: station.latitude,
                longitude: station.longitude
            ))
        }
        .mapStyle(mapStyle == "satellite" ? .imagery : mapStyle == "hybrid" ? .hybrid : .standard)
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Connecting Lines

    private var connectingLinesCard: some View {
        CardSection(title: String(localized: "Lines", comment: "Station detail: connecting lines section header")) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(groupedLines, id: \.mode) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(group.mode.label, systemImage: group.mode.systemImage)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        FlowLayout(spacing: 6, alignment: .leading) {
                            ForEach(group.lines) { line in
                                NavigationLink(value: line.sourceID) {
                                    LineBadge(line: line)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        await Task.yield()
        do {
            station = try dataStore.transitService.station(bySourceID: stationSourceID)
            connectingLines = try dataStore.transitService.lines(forStationSourceID: stationSourceID)
            groupedLines = Dictionary(grouping: connectingLines) { line in
                TransitMode(rawValue: line.mode) ?? .bus
            }
            .sorted { $0.key.sortOrder < $1.key.sortOrder }
            .map { (mode: $0.key, lines: $0.value) }
            // Load travel history
            recentTravels = try dataStore.travelsPassingThrough(stationSourceID: stationSourceID)

            // Load travel metadata
            var lineIDs: Set<String> = []
            var stationIDs: Set<String> = []
            for travel in recentTravels {
                lineIDs.insert(travel.lineSourceID)
                stationIDs.insert(travel.fromStationSourceID)
                stationIDs.insert(travel.toStationSourceID)
            }

            if !lineIDs.isEmpty {
                let lines = try dataStore.transitService.lines(bySourceIDs: Array(lineIDs))
                for line in lines {
                    travelLineMap[line.sourceID] = line
                }
            }

            if !stationIDs.isEmpty {
                let stations = try dataStore.transitService.stations(bySourceIDs: Array(stationIDs))
                var names: [String: String] = [:]
                for station in stations {
                    names[station.sourceID] = station.name
                }
                // Fill missing station names with fallback
                for travel in recentTravels {
                    for id in [travel.fromStationSourceID, travel.toStationSourceID] where names[id] == nil {
                        names[id] = String(localized: "Unknown stop", comment: "Fallback name when stop cannot be resolved")
                    }
                }
                travelStationNames = names
            }
            isFavorited = logged { try dataStore.userService.isFavorite(
                kind: FavoriteKind.station.rawValue,
                sourceID: stationSourceID
            ) } ?? false
        } catch {
            #if DEBUG
                print("Failed to load station detail: \(error)")
            #endif
        }
    }
}
