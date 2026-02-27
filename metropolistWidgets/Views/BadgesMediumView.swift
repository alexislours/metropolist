import SwiftUI
import WidgetKit

struct BadgesMediumView: View {
    let data: WidgetData

    var body: some View {
        HStack(spacing: 0) {
            // Badges section
            VStack(alignment: .leading, spacing: 10) {
                Label {
                    Text("Badges", comment: "Widget: badges section title")
                } icon: {
                    Image(systemName: "medal.fill")
                }
                .font(.caption.bold())
                .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 8) {
                    MediumBadgeRow(
                        icon: "medal.star.fill",
                        label: String(localized: "Gold", comment: "Widget: gold badge tier"),
                        count: data.goldBadges ?? 0,
                        total: data.totalBadgeSlots ?? 0,
                        color: WidgetColors.goldColor
                    )
                    MediumBadgeRow(
                        icon: "medal.fill",
                        label: String(localized: "Silver", comment: "Widget: silver badge tier"),
                        count: data.silverBadges ?? 0,
                        total: data.totalBadgeSlots ?? 0,
                        color: WidgetColors.silverColor
                    )
                    MediumBadgeRow(
                        icon: "medal.fill",
                        label: String(localized: "Bronze", comment: "Widget: bronze badge tier"),
                        count: data.bronzeBadges ?? 0,
                        total: data.totalBadgeSlots ?? 0,
                        color: WidgetColors.bronzeColor
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .padding(.horizontal, 12)

            // Achievements section
            VStack(spacing: 10) {
                Label {
                    Text("Achievements", comment: "Widget: achievements section title")
                } icon: {
                    Image(systemName: "trophy.fill")
                }
                .font(.caption.bold())
                .foregroundStyle(.purple)

                let unlocked = data.unlockedAchievements ?? 0
                let total = data.totalAchievements ?? 0

                Text("\(unlocked) / \(total)", comment: "Widget: achievements unlocked / total")
                    .font(.system(.title3, design: .rounded, weight: .bold))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.quaternary)
                            .frame(height: 6)

                        Capsule()
                            .fill(LinearGradient(colors: [.purple, .purple.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(6, geo.size.width * achievementProgress), height: 6)
                    }
                }
                .frame(height: 6)

                Text("unlocked", comment: "Widget: achievements unlocked subtitle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    private var achievementProgress: Double {
        let total = data.totalAchievements ?? 0
        guard total > 0 else { return 0 }
        return min(1.0, Double(data.unlockedAchievements ?? 0) / Double(total))
    }
}

private struct MediumBadgeRow: View {
    let icon: String
    let label: String
    let count: Int
    let total: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 14)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(count) / \(total)", comment: "Widget: badge count as earned / total")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
        }
    }
}
