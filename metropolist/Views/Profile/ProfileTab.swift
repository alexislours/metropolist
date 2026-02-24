import SwiftUI
import TransitModels

struct ProfileTab: View {
    @Environment(DataStore.self) private var dataStore
    @State private var viewModel: ProfileViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel, !viewModel.isLoading {
                    ScrollView {
                        VStack(spacing: 16) {
                            LevelHeaderCard(snapshot: viewModel.snapshot)

                            GamificationTiles(
                                snapshot: viewModel.snapshot,
                                totalBadgeSlots: viewModel.lineMetadataMap.count * 3
                            )

                            NavigationLink(value: GamificationDestination.stats) {
                                HStack {
                                    Label(
                                        String(localized: "Statistics", comment: "Profile: statistics link"),
                                        systemImage: "chart.bar.fill"
                                    )
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(16)
                                .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("link-statistics")

                            ModeProgressTiles(
                                snapshot: viewModel.snapshot,
                                linesByMode: viewModel.linesByMode
                            )

                            TravelHistoryCard(
                                travels: viewModel.recentTravels,
                                travelLines: viewModel.travelLines,
                                stationNames: viewModel.stationNames
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 80)
                    }
                    .background(Color(UIColor.systemGroupedBackground))
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(String(localized: "Profile", comment: "Profile: navigation title"))
            .navigationDestination(for: GamificationDestination.self) { dest in
                switch dest {
                case .badges:
                    if let viewModel {
                        BadgesDetailView(
                            snapshot: viewModel.snapshot,
                            linesByMode: viewModel.linesByMode
                        )
                    }
                case .achievements:
                    if let viewModel {
                        AchievementsDetailView(achievements: viewModel.snapshot.achievements)
                    }
                case .stats:
                    if let viewModel {
                        StatsDetailView(viewModel: viewModel)
                    }
                case let .progress(mode):
                    if let viewModel,
                       let lines = viewModel.linesByMode.first(where: { $0.mode == mode })?.lines {
                        ProgressDetailView(
                            snapshot: viewModel.snapshot,
                            mode: mode,
                            lines: lines
                        )
                    }
                case .travelHistory:
                    if let viewModel {
                        TravelHistoryDetailView(viewModel: viewModel)
                    }
                case let .travelDetail(travelID):
                    TravelDetailView(travelID: travelID)
                }
            }
            .task {
                if viewModel == nil {
                    let model = ProfileViewModel(dataStore: dataStore)
                    viewModel = model
                    await model.load()
                }
            }
            .onChange(of: dataStore.userDataVersion) {
                Task { await viewModel?.load() }
            }
        }
    }
}

// MARK: - Navigation

enum GamificationDestination: Hashable {
    case badges
    case achievements
    case stats
    case travelHistory
    case progress(TransitMode)
    case travelDetail(String) // Travel ID
}

// MARK: - Tiles

private struct GamificationTiles: View {
    let snapshot: GamificationSnapshot
    let totalBadgeSlots: Int

    private var earnedBadgeCount: Int {
        snapshot.lineBadges.values.reduce(0) { $0 + $1.rawValue }
    }

    private var unlockedAchievementCount: Int {
        snapshot.achievements.filter(\.isUnlocked).count
    }

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: GamificationDestination.badges) {
                TileContent(
                    icon: "medal.fill",
                    title: String(localized: "Badges", comment: "Profile: badges tile title"),
                    count: earnedBadgeCount,
                    total: totalBadgeSlots,
                    color: .orange
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tile-badges")

            NavigationLink(value: GamificationDestination.achievements) {
                TileContent(
                    icon: "trophy.fill",
                    title: String(localized: "Achievements", comment: "Profile: achievements tile title"),
                    count: unlockedAchievementCount,
                    total: snapshot.achievements.count,
                    color: .purple
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tile-achievements")
        }
    }
}

private struct TileContent: View {
    let icon: String
    let title: String
    let count: Int
    let total: Int
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text("\(count)/\(total)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

// MARK: - Mode Progress Tiles

private struct ModeProgressTiles: View {
    let snapshot: GamificationSnapshot
    let linesByMode: [(mode: TransitMode, lines: [LineMetadata])]

    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 60

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(linesByMode, id: \.mode) { group in
                let totalStops = group.lines.reduce(0) { $0 + $1.totalStations }
                let completedStops = group.lines.reduce(0) { $0 + (snapshot.lineProgress[$1.sourceID]?.completedStops ?? 0) }

                NavigationLink(value: GamificationDestination.progress(group.mode)) {
                    VStack(spacing: 8) {
                        CompletionRing(completed: completedStops, total: totalStops, size: ringSize, showPercentage: true)

                        Label(group.mode.label, systemImage: group.mode.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text("\(completedStops)/\(totalStops)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Detail Views

struct BadgesDetailView: View {
    let snapshot: GamificationSnapshot
    let linesByMode: [(mode: TransitMode, lines: [LineMetadata])]
    @State private var selectedMode: TransitMode?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16, pinnedViews: .sectionHeaders) {
                BadgesSummaryHeader(
                    snapshot: snapshot,
                    linesByMode: linesByMode
                )

                BadgesModeFilter(
                    snapshot: snapshot,
                    linesByMode: linesByMode,
                    selectedMode: $selectedMode
                )

                BadgesLineList(
                    snapshot: snapshot,
                    linesByMode: linesByMode,
                    selectedMode: selectedMode
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 80)
            .animation(reduceMotion ? .none : .snappy(duration: 0.25), value: selectedMode)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(String(localized: "Badges", comment: "Badges: navigation title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AchievementsDetailView: View {
    let achievements: [AchievementState]
    @State private var selectedGroup: AchievementGroup?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var groupedAchievements: [AchievementGroup: [AchievementState]] {
        Dictionary(grouping: achievements, by: \.definition.group)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AchievementsSummaryHeader(achievements: achievements)

                AchievementGroupFilter(
                    achievements: achievements,
                    grouped: groupedAchievements,
                    selectedGroup: $selectedGroup
                )

                AchievementsList(
                    selectedGroup: selectedGroup,
                    grouped: groupedAchievements
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 80)
            .animation(reduceMotion ? .none : .snappy(duration: 0.25), value: selectedGroup)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(String(localized: "Achievements", comment: "Achievements: navigation title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProgressDetailView: View {
    let snapshot: GamificationSnapshot
    let mode: TransitMode
    let lines: [LineMetadata]

    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 80

    private var totalStops: Int {
        lines.reduce(0) { $0 + $1.totalStations }
    }

    private var completedStops: Int {
        lines.reduce(0) { $0 + (snapshot.lineProgress[$1.sourceID]?.completedStops ?? 0) }
    }

    private var sortedLines: [LineMetadata] {
        lines.sorted { lhs, rhs in
            let fracA = snapshot.lineProgress[lhs.sourceID]?.fraction ?? 0
            let fracB = snapshot.lineProgress[rhs.sourceID]?.fraction ?? 0
            if fracA != fracB { return fracA > fracB }
            return lhs.shortName.localizedStandardCompare(rhs.shortName) == .orderedAscending
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                VStack(spacing: 4) {
                    CompletionRing(completed: completedStops, total: totalStops, size: ringSize, showPercentage: true)

                    Text(String(localized: "\(completedStops)/\(totalStops) stops", comment: "Profile: completed stops out of total stops"))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(sortedLines, id: \.sourceID) { meta in
                        LineProgressRow(
                            meta: meta,
                            progress: snapshot.lineProgress[meta.sourceID]
                        )
                    }
                }
                .padding(16)
                .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(mode.label)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// StatsDetailView and related sub-views are in Sections/StatsCard.swift
