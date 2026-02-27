import SwiftUI
import WidgetKit

struct StatsLargeView: View {
    let data: WidgetData

    var body: some View {
        VStack(spacing: 14) {
            // Level header
            HStack(spacing: 14) {
                ZStack {
                    WidgetProgressRing(
                        progress: xpProgress,
                        gradient: WidgetColors.levelGradient(for: data.levelNumber),
                        lineWidth: 8,
                        size: 76
                    )

                    VStack(spacing: 0) {
                        Text("\(data.levelNumber)")
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(WidgetColors.levelColor(for: data.levelNumber))
                        Text("LEVEL", comment: "Widget: label inside level ring")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(data.totalXP) XP", comment: "Widget: total XP count")
                        .font(.system(.title3, design: .rounded, weight: .bold))

                    Text(
                        "\(data.xpInCurrentLevel) / \(data.xpToNextLevel) to next level",
                        comment: "Widget: XP remaining to reach next level"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            // Stats grid (2x3)
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    LargeStatCard(
                        icon: "flame.fill",
                        label: String(localized: "Streak", comment: "Widget: current travel streak label"),
                        value: "\(data.currentStreak)",
                        tint: .orange
                    )
                    LargeStatCard(
                        icon: "tram.fill",
                        label: String(localized: "Travels", comment: "Widget: total travels label"),
                        value: "\(data.totalTravels)",
                        tint: .blue
                    )
                }
                GridRow {
                    LargeStatCard(
                        icon: "mappin.and.ellipse",
                        label: String(localized: "Stations", comment: "Widget: total stations visited label"),
                        value: "\(data.totalStationsVisited)",
                        tint: .red
                    )
                    LargeStatCard(
                        icon: "checkmark.circle.fill",
                        label: String(localized: "Lines done", comment: "Widget: lines completed label"),
                        value: "\(data.totalLinesCompleted)",
                        tint: .green
                    )
                }
                GridRow {
                    LargeStatCard(
                        icon: "trophy.fill",
                        label: String(localized: "Achievements", comment: "Widget: achievements section title"),
                        value: "\(data.unlockedAchievements ?? 0) / \(data.totalAchievements ?? 0)",
                        tint: .purple
                    )
                    LargeStatCard(
                        icon: "globe.europe.africa.fill",
                        label: String(localized: "Network", comment: "Widget: network coverage label"),
                        value: networkPercentText,
                        tint: .teal
                    )
                }
            }

            // Badges bar
            HStack(spacing: 0) {
                Label {
                    Text("Badges", comment: "Widget: badges section title")
                } icon: {
                    Image(systemName: "medal.fill")
                }
                .font(.caption.bold())
                .foregroundStyle(.orange)

                Spacer()

                HStack(spacing: 12) {
                    BadgePill(count: data.goldBadges ?? 0, color: WidgetColors.goldColor, icon: "medal.star.fill")
                    BadgePill(count: data.silverBadges ?? 0, color: WidgetColors.silverColor, icon: "medal.fill")
                    BadgePill(count: data.bronzeBadges ?? 0, color: WidgetColors.bronzeColor, icon: "medal.fill")
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var xpProgress: Double {
        guard data.xpToNextLevel > 0 else { return 0 }
        return min(1.0, Double(data.xpInCurrentLevel) / Double(data.xpToNextLevel))
    }

    private var networkProgress: Double {
        guard let total = data.totalStationsInNetwork, total > 0 else { return 0 }
        return min(1.0, Double(data.totalStationsVisited) / Double(total))
    }

    private var networkPercentText: String {
        "\(Int(networkProgress * 100))%"
    }
}

private struct LargeStatCard: View {
    let icon: String
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct BadgePill: View {
    let count: Int
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption)
            Text("\(count)")
                .font(.system(.caption, design: .rounded, weight: .semibold))
        }
        .foregroundStyle(color)
    }
}
