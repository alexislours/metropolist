import SwiftUI
import WidgetKit

struct StatsMediumView: View {
    let data: WidgetData

    var body: some View {
        HStack(spacing: 12) {
            // Level ring
            VStack(spacing: 6) {
                ZStack {
                    WidgetProgressRing(
                        progress: xpProgress,
                        gradient: WidgetColors.levelGradient(for: data.levelNumber),
                        lineWidth: 7,
                        size: 64
                    )

                    VStack(spacing: 0) {
                        Text("\(data.levelNumber)")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(WidgetColors.levelColor(for: data.levelNumber))
                        Text("LEVEL", comment: "Widget: label inside level ring")
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Text("\(data.xpInCurrentLevel) / \(data.xpToNextLevel) XP", comment: "Widget: XP progress as current / total XP")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // 2x2 stats grid with card backgrounds
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    MediumStatCard(
                        icon: "flame.fill",
                        value: "\(data.currentStreak)",
                        label: String(localized: "Streak", comment: "Widget: current travel streak label"),
                        tint: .orange
                    )
                    MediumStatCard(
                        icon: "tram.fill",
                        value: "\(data.totalTravels)",
                        label: String(localized: "Travels", comment: "Widget: total travels label"),
                        tint: .blue
                    )
                }
                GridRow {
                    MediumStatCard(
                        icon: "mappin.and.ellipse",
                        value: "\(data.totalStationsVisited)",
                        label: String(localized: "Stations", comment: "Widget: total stations visited label"),
                        tint: .red
                    )
                    MediumStatCard(
                        icon: "checkmark.circle.fill",
                        value: "\(data.totalLinesCompleted)",
                        label: String(localized: "Lines", comment: "Widget: lines completed label"),
                        tint: .green
                    )
                }
            }
        }
    }

    private var xpProgress: Double {
        guard data.xpToNextLevel > 0 else { return 0 }
        return min(1.0, Double(data.xpInCurrentLevel) / Double(data.xpToNextLevel))
    }
}

private struct MediumStatCard: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
