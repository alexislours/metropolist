import SwiftUI
import WidgetKit

struct BadgesSmallView: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label {
                Text("Badges", comment: "Widget: badges section title")
            } icon: {
                Image(systemName: "medal.fill")
            }
            .font(.caption.bold())
            .foregroundStyle(.orange)

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 12) {
                BadgeRow(
                    icon: "medal.star.fill",
                    label: String(localized: "Gold", comment: "Widget: gold badge tier"),
                    count: data.goldBadges ?? 0,
                    total: data.totalBadgeSlots ?? 0,
                    color: WidgetColors.goldColor
                )
                BadgeRow(
                    icon: "medal.fill",
                    label: String(localized: "Silver", comment: "Widget: silver badge tier"),
                    count: data.silverBadges ?? 0,
                    total: data.totalBadgeSlots ?? 0,
                    color: WidgetColors.silverColor
                )
                BadgeRow(
                    icon: "medal.fill",
                    label: String(localized: "Bronze", comment: "Widget: bronze badge tier"),
                    count: data.bronzeBadges ?? 0,
                    total: data.totalBadgeSlots ?? 0,
                    color: WidgetColors.bronzeColor
                )
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct BadgeRow: View {
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
