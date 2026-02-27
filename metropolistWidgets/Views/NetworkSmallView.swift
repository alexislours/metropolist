import SwiftUI
import WidgetKit

struct NetworkSmallView: View {
    let data: WidgetData

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                WidgetProgressRing(
                    progress: networkProgress,
                    gradient: WidgetColors.networkGradient,
                    lineWidth: 7,
                    size: 80
                )

                Text(percentText)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.teal)
            }

            Text("Stations", comment: "Widget: network coverage title")
                .font(.caption.bold())

            Text("\(data.totalStationsVisited) / \(data.totalStationsInNetwork ?? 0)", comment: "Widget: stations visited / total stations")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var networkProgress: Double {
        guard let total = data.totalStationsInNetwork, total > 0 else { return 0 }
        return min(1.0, Double(data.totalStationsVisited) / Double(total))
    }

    private var percentText: String {
        "\(Int(networkProgress * 100))%"
    }
}
