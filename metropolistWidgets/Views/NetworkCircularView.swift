import SwiftUI
import WidgetKit

struct NetworkCircularView: View {
    let data: WidgetData

    var body: some View {
        Gauge(value: networkProgress) {
            Image(systemName: "mappin.and.ellipse")
        } currentValueLabel: {
            Text(percentText)
                .font(.system(.body, design: .rounded, weight: .bold))
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var networkProgress: Double {
        guard let total = data.totalStationsInNetwork, total > 0 else { return 0 }
        return min(1.0, Double(data.totalStationsVisited) / Double(total))
    }

    private var percentText: String {
        "\(Int(networkProgress * 100))%"
    }
}
