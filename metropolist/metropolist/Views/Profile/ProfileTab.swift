import SwiftUI
import TransitModels

struct ProfileTab: View {
    @Environment(DataStore.self) private var dataStore
    @State private var viewModel: ProfileViewModel?
    @State private var selectedRecap: RecapKind?
    // periphery:ignore
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let viewModel, viewModel.error != nil {
                    ContentUnavailableView(
                        String(localized: "Unable to Load Profile", comment: "Profile: error screen title"),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                } else if let viewModel, !viewModel.isLoading {
                    ScrollView {
                        VStack(spacing: 16) {
                            LevelHeaderCard(snapshot: viewModel.snapshot, totalDistance: viewModel.totalDistance)

                            RecapsPreviewCard(summaries: viewModel.recentRecapSummaries)

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
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("link-statistics")

                            TravelHistoryCard(
                                travels: viewModel.recentTravels,
                                travelLines: viewModel.travelLines,
                                stationNames: viewModel.stationNames,
                                historySource: .all
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 80)
                    }
                    .background(Color(UIColor.systemGroupedBackground))
                } else {
                    TransitLoadingIndicator()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(String(localized: "Profile", comment: "Profile: navigation title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: GamificationDestination.timeline) {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    }
                    .accessibilityLabel(
                        String(localized: "Timeline", comment: "Profile: timeline toolbar button")
                    )
                    .accessibilityIdentifier("link-timeline")
                }
            }
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
                case .timeline:
                    TravelTimelineView()
                case let .travelHistory(source):
                    TravelHistoryDetailView(source: source)
                case .recaps:
                    RecapListView(dataStore: dataStore)
                case let .travelDetail(travelID):
                    TravelDetailView(travelID: travelID)
                }
            }
            .fullScreenCover(
                item: Binding(
                    get: { selectedRecap.map { RecapPresentation(kind: $0) } },
                    set: { selectedRecap = $0?.kind }
                ),
                content: { presentation in
                    switch presentation.kind {
                    case let .monthly(month):
                        MonthlyRecapView(month: month, dataStore: dataStore)
                    case let .yearly(year):
                        YearlyRecapView(year: year, dataStore: dataStore)
                    }
                }
            )
            .environment(\.openRecap) { kind in
                selectedRecap = kind
            }
            .navigationDestination(for: String.self) { lineSourceID in
                LineDetailView(lineSourceID: lineSourceID)
            }
            .navigationDestination(for: StationDestination.self) { dest in
                StationDetailView(stationSourceID: dest.stationSourceID)
            }
            .task(id: dataStore.userDataVersion) {
                if viewModel == nil {
                    let model = ProfileViewModel(dataStore: dataStore)
                    viewModel = model
                    await model.load()
                } else {
                    await viewModel?.load()
                }
            }
        }
    }
}

// MARK: - Navigation

enum TravelHistorySource: Hashable {
    case all
    case line(String) // lineSourceID
    case station(String) // stationSourceID
}

enum GamificationDestination: Hashable {
    case badges
    case achievements
    case stats
    case timeline
    case travelHistory(TravelHistorySource)
    case recaps
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(
                localized: "Badges, \(earnedBadgeCount) of \(totalBadgeSlots)",
                comment: "Profile accessibility: badges tile"
            ))
            .accessibilityAddTraits(.isButton)

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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(
                localized: "Achievements, \(unlockedAchievementCount) of \(snapshot.achievements.count)",
                comment: "Profile accessibility: achievements tile"
            ))
            .accessibilityAddTraits(.isButton)
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
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 1))
    }
}

// MARK: - Detail Views

struct BadgesDetailView: View {
    let snapshot: GamificationSnapshot
    let linesByMode: [(mode: TransitMode, lines: [LineMetadata])]
    @State private var selectedMode: TransitMode?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sortedLinesByMode: [(mode: TransitMode, sortedLines: [LineMetadata])] {
        linesByMode.map { group in
            let sorted = group.lines.sorted { lhs, rhs in
                let tierA = snapshot.lineBadges[lhs.sourceID] ?? .locked
                let tierB = snapshot.lineBadges[rhs.sourceID] ?? .locked
                if tierA != tierB {
                    return tierA > tierB
                }
                let fracA = snapshot.lineProgress[lhs.sourceID]?.fraction ?? 0
                let fracB = snapshot.lineProgress[rhs.sourceID]?.fraction ?? 0
                if fracA != fracB {
                    return fracA > fracB
                }
                return lhs.shortName.localizedStandardCompare(rhs.shortName) == .orderedAscending
            }
            return (mode: group.mode, sortedLines: sorted)
        }
    }

    var body: some View {
        let sortedModes = sortedLinesByMode
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
                    linesByMode: sortedModes,
                    selectedMode: selectedMode
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 80)
            .animation(reduceMotion ? .none : .snappy(duration: 0.25), value: selectedMode)
        }
        .accessibilityIdentifier("view-badges-detail")
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(String(localized: "Badges", comment: "Badges: navigation title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AchievementsDetailView: View {
    let achievements: [AchievementState]
    @State private var selectedGroup: AchievementGroup?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let groupedAchievements: [AchievementGroup: [AchievementState]]

    init(achievements: [AchievementState]) {
        self.achievements = achievements
        groupedAchievements = Dictionary(grouping: achievements, by: \.definition.group)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
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
        .accessibilityIdentifier("view-achievements-detail")
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(String(localized: "Achievements", comment: "Achievements: navigation title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Open Recap Environment

private struct OpenRecapKey: EnvironmentKey {
    static let defaultValue: (RecapKind) -> Void = { _ in }
}

extension EnvironmentValues {
    var openRecap: (RecapKind) -> Void {
        get { self[OpenRecapKey.self] }
        set { self[OpenRecapKey.self] = newValue }
    }
}
