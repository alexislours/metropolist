import CloudKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsTab: View {
    @Environment(DataStore.self) var store

    @AppStorage("destinationSort") private var destinationSort: String = "route"
    @AppStorage("nearbyRadius") private var nearbyRadius: Int = 500
    @AppStorage("mapStyle") private var mapStyle: String = "standard"
    @AppStorage("devMode") private var devMode: Bool = false

    @State var exportedFileURL: URL?
    @State private var showImporter = false
    @State var importAlert: ImportAlert?
    @State private var showDeleteConfirmation = false
    @State private var transitStats: TransitStats?
    @State var cloudKitStatus: CKAccountStatus?
    @State private var devModeTapCount = 0
    @State private var devModeFeedback: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private var dataVersion: String {
        transitStats?.generatedAt ?? "—"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    cloudKitSection
                    preferencesSection
                    transitDataSection
                    dataManagementSection
                    faqSection
                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(String(localized: "Settings", comment: "Settings: navigation title"))
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .alert(
                importAlert?.title ?? "",
                isPresented: Binding(
                    get: { importAlert != nil },
                    set: { if !$0 { importAlert = nil } }
                )
            ) {
                // Empty actions = default OK dismiss button
            } message: {
                Text(importAlert?.message ?? "")
            }
            .alert(
                String(localized: "Delete All User Data?", comment: "Settings: delete all data confirmation title"),
                isPresented: $showDeleteConfirmation
            ) {
                Button(String(localized: "Cancel", comment: "Settings: cancel delete action"), role: .cancel) {}
                Button(String(localized: "Delete All", comment: "Settings: confirm delete all button"), role: .destructive) {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    deleteAllUserData()
                }
            } message: {
                Text(String(
                    localized: "This will permanently delete all your completed stops and travels. This action cannot be undone.",
                    comment: "Settings: delete all data warning message"
                ))
            }
            .task {
                transitStats = loadTransitStats()
                cloudKitStatus = try? await CKContainer(identifier: "iCloud.com.alexislours.metropolist").accountStatus()
            }
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        CardSection(title: String(localized: "PREFERENCES", comment: "Settings: preferences section header")) {
            VStack(spacing: 0) {
                HStack {
                    Text(String(localized: "Destination Sort", comment: "Settings: destination sort label"))
                        .font(.subheadline)
                    Spacer()
                    let sortLabel = String(localized: "Destination Sort", comment: "Settings: destination sort label")
                    Picker(sortLabel, selection: $destinationSort) {
                        Text(String(localized: "Route Order", comment: "Settings: sort by route order")).tag("route")
                        Text(String(localized: "Alphabetical", comment: "Settings: sort alphabetically")).tag("alphabetical")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(.secondary)
                }

                Divider()
                    .padding(.vertical, 12)

                HStack {
                    Text(String(localized: "Nearby Radius", comment: "Settings: nearby radius label"))
                        .font(.subheadline)
                    Spacer()
                    Picker(String(localized: "Nearby Radius", comment: "Settings: nearby radius label"), selection: $nearbyRadius) {
                        Text(String(localized: "200 m", comment: "Settings: nearby radius 200 meters")).tag(200)
                        Text(String(localized: "500 m", comment: "Settings: nearby radius 500 meters")).tag(500)
                        Text(String(localized: "1 km", comment: "Settings: nearby radius 1 kilometer")).tag(1000)
                        Text(String(localized: "2 km", comment: "Settings: nearby radius 2 kilometers")).tag(2000)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(.secondary)
                }

                Divider()
                    .padding(.vertical, 12)

                HStack {
                    Text(String(localized: "Map Style", comment: "Settings: map style label"))
                        .font(.subheadline)
                    Spacer()
                    Picker(String(localized: "Map Style", comment: "Settings: map style label"), selection: $mapStyle) {
                        Text(String(localized: "Standard", comment: "Settings: standard map style")).tag("standard")
                        Text(String(localized: "Satellite", comment: "Settings: satellite map style")).tag("satellite")
                        Text(String(localized: "Hybrid", comment: "Settings: hybrid map style")).tag("hybrid")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(.secondary)
                }
            }
        }
    }

    // MARK: - Transit Data Section

    private var transitDataSection: some View {
        CardSection(title: String(localized: "TRANSIT DATA", comment: "Settings: transit data section header")) {
            if let stats = transitStats {
                NavigationLink(destination: TransitDataView(stats: stats)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "Transit Database", comment: "Settings: transit database link title"))
                                .font(.subheadline.weight(.medium))
                            Text(
                                "\(stats.totalLines) " + String(localized: "lines", comment: "Settings: lines count suffix") + " · "
                                    + "\(stats.totalStations) " + String(localized: "stops", comment: "Settings: stops count suffix")
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        CardSection(title: String(localized: "DATA MANAGEMENT", comment: "Settings: data management section header")) {
            VStack(spacing: 0) {
                if let url = exportedFileURL {
                    ShareLink(item: url) {
                        HStack {
                            Label(
                                String(localized: "Export Data", comment: "Settings: export data button"),
                                systemImage: "square.and.arrow.up"
                            )
                            .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                } else {
                    Button {
                        prepareExport()
                    } label: {
                        HStack {
                            Label(
                                String(localized: "Export Data", comment: "Settings: export data button"),
                                systemImage: "square.and.arrow.up"
                            )
                            .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Divider()
                    .padding(.vertical, 12)

                Button {
                    showImporter = true
                } label: {
                    HStack {
                        Label(
                            String(localized: "Import Data", comment: "Settings: import data button"),
                            systemImage: "square.and.arrow.down"
                        )
                        .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)

                Divider()
                    .padding(.vertical, 12)

                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Label(
                            String(localized: "Delete All User Data", comment: "Settings: delete all user data button"),
                            systemImage: "trash"
                        )
                        .font(.subheadline)
                        Spacer()
                    }
                }
                .foregroundStyle(.red)
            }
        }
    }

    // MARK: - FAQ Section

    private var faqSection: some View {
        CardSection(title: String(localized: "HELP", comment: "Settings: help section header")) {
            NavigationLink(destination: FAQView()) {
                HStack {
                    Label(
                        String(localized: "FAQ", comment: "Settings: FAQ link"),
                        systemImage: "questionmark.circle"
                    )
                    .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(.primary)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        CardSection(title: String(localized: "ABOUT", comment: "Settings: about section header")) {
            VStack(spacing: 12) {
                HStack {
                    Text(String(localized: "Version", comment: "Settings: app version label"))
                        .font(.subheadline)
                    Spacer()
                    Text(appVersion)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    Text(String(localized: "Build", comment: "Settings: build number label"))
                        .font(.subheadline)
                    Spacer()
                    Text(devModeFeedback ?? buildNumber)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    devModeTapCount += 1
                    if devModeTapCount >= 5 {
                        devModeTapCount = 0
                        devMode.toggle()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(reduceMotion ? .none : .default) {
                            devModeFeedback = devMode ? "Developer Mode ON" : "Developer Mode OFF"
                        }
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation(reduceMotion ? .none : .default) {
                                devModeFeedback = nil
                            }
                        }
                    }
                }

                Divider()

                HStack {
                    Text(String(localized: "Data Version", comment: "Settings: transit data version label"))
                        .font(.subheadline)
                    Spacer()
                    Text(dataVersion)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                NavigationLink(destination: LicencesView()) {
                    HStack {
                        Text(String(localized: "Open Data Licences", comment: "Settings: open data licences link"))
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)

                Divider()

                Text(String(localized: "Made with ♡ for Paris transit riders", comment: "Settings: app tagline"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
