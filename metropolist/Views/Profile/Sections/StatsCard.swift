import SwiftUI

struct StatsDetailView: View {
    let viewModel: ProfileViewModel

    private var stats: PlayerStats {
        viewModel.snapshot.stats
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                OverviewCard(
                    stats: stats,
                    badgeCount: viewModel.snapshot.lineBadges.values.reduce(0) { $0 + $1.rawValue }
                )

                ModeBreakdownCard(modeBreakdown: viewModel.modeBreakdown)

                NetworkCoverageCard(
                    stats: stats,
                    linesByMode: viewModel.linesByMode
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
        .accessibilityIdentifier("view-stats-detail")
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(String(localized: "Statistics", comment: "Statistics: navigation title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Overview Card

private struct OverviewCard: View {
    let stats: PlayerStats
    let badgeCount: Int

    var body: some View {
        CardSection(title: String(localized: "OVERVIEW", comment: "Statistics: overview section header")) {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    BigStat(
                        icon: "figure.walk",
                        value: stats.totalTravels,
                        label: String(localized: "Travels", comment: "Statistics: travels count label")
                    )
                    BigStat(
                        icon: "mappin.and.ellipse",
                        value: stats.totalStationsVisited,
                        label: String(localized: "Stops", comment: "Statistics: stops count label")
                    )
                    BigStat(
                        icon: "medal.fill",
                        value: badgeCount,
                        label: String(localized: "Badges", comment: "Statistics: badges earned count label")
                    )
                }

                Divider()

                HStack {
                    Label {
                        Text(String(localized: "\(stats.currentStreak) day streak", comment: "Statistics: current streak count"))
                            .font(.subheadline.weight(.medium))
                    } icon: {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                    }

                    Spacer()

                    if let first = stats.firstTravelDate {
                        Text(String(
                            localized: "Since \(first.formatted(.dateTime.month(.wide).day().year()))",
                            comment: "Statistics: first travel date"
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct BigStat: View {
    let icon: String
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(value)")
                .font(.title3.bold().monospacedDigit())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Mode Breakdown Card

private struct ModeBreakdownCard: View {
    let modeBreakdown: [ModeBreakdownEntry]

    var body: some View {
        CardSection(title: String(localized: "MODE BREAKDOWN", comment: "Statistics: mode breakdown section header")) {
            if modeBreakdown.isEmpty {
                Text(String(localized: "No travels recorded", comment: "Statistics: empty mode breakdown"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(modeBreakdown) { item in
                        ModeBar(mode: item.mode, count: item.count, percentage: item.percentage)
                    }
                }
            }
        }
    }
}

private struct ModeBar: View {
    let mode: TransitMode
    let count: Int
    let percentage: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(mode.label, systemImage: mode.systemImage)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(count)")
                    .font(.subheadline.monospacedDigit().bold())

                Text("\(Int((percentage * 100).rounded()))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

            ProgressView(value: percentage)
                .tint(mode.tintColor)
        }
    }
}

// MARK: - Network Coverage Card

private struct NetworkCoverageCard: View {
    let stats: PlayerStats
    let linesByMode: [(mode: TransitMode, lines: [LineMetadata])]

    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 80

    private var totalStops: Int {
        linesByMode.reduce(0) { $0 + $1.lines.reduce(0) { $0 + $1.totalStations } }
    }

    private var totalLines: Int {
        linesByMode.reduce(0) { $0 + $1.lines.count }
    }

    var body: some View {
        CardSection(title: String(localized: "NETWORK COVERAGE", comment: "Statistics: network coverage section header")) {
            VStack(spacing: 12) {
                CompletionRing(
                    completed: stats.totalStationsVisited,
                    total: totalStops,
                    size: ringSize,
                    showPercentage: true
                )
                .frame(maxWidth: .infinity)

                Text(String(
                    localized: "\(stats.totalStationsVisited) / \(totalStops) stops",
                    comment: "Statistics: stops visited out of total"
                ))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

                Divider()

                VStack(spacing: 8) {
                    CoverageRow(
                        icon: "mappin.circle.fill",
                        label: String(localized: "Stops visited", comment: "Statistics: stops visited coverage row"),
                        value: stats.totalStationsVisited,
                        total: totalStops
                    )
                    CoverageRow(
                        icon: "line.horizontal.3",
                        label: String(localized: "Lines started", comment: "Statistics: lines started coverage row"),
                        value: stats.totalLinesStarted,
                        total: totalLines
                    )
                    CoverageRow(
                        icon: "checkmark.circle.fill",
                        label: String(localized: "Lines completed", comment: "Statistics: lines completed coverage row"),
                        value: stats.totalLinesCompleted,
                        total: totalLines
                    )
                }
            }
        }
    }
}

private struct CoverageRow: View {
    let icon: String
    let label: String
    let value: Int
    let total: Int

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            Text("\(value)/\(total)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
