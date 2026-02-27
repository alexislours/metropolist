import SwiftUI
import WidgetKit

struct StatsSmallView: View {
    let data: WidgetData

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                WidgetProgressRing(
                    progress: xpProgress,
                    gradient: WidgetColors.levelGradient(for: data.levelNumber),
                    lineWidth: 7,
                    size: 68
                )

                Text("\(data.levelNumber)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(WidgetColors.levelColor(for: data.levelNumber))
            }

            Label("\(data.currentStreak)", systemImage: "flame.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.orange)

            Text("\(data.xpInCurrentLevel) / \(data.xpToNextLevel) XP", comment: "Widget: XP progress as current / total XP")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var xpProgress: Double {
        guard data.xpToNextLevel > 0 else { return 0 }
        return min(1.0, Double(data.xpInCurrentLevel) / Double(data.xpToNextLevel))
    }
}
