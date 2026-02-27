import SwiftUI
import WidgetKit

struct StreakRectangularView: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text("\(data.currentStreak)-day streak", comment: "Widget: streak headline with day count")
            } icon: {
                Image(systemName: "flame.fill")
            }
            .font(.headline)
            .widgetAccentable()

            HStack(spacing: 12) {
                Label("\(data.totalTravels)", systemImage: "tram.fill")
                Label("\(data.totalStationsVisited)", systemImage: "mappin.and.ellipse")
                Label("\(data.totalLinesCompleted)", systemImage: "checkmark.circle.fill")
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
