import SwiftUI
import WidgetKit

struct StreakCircularView: View {
    let data: WidgetData

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                Text("\(data.currentStreak)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }
        }
    }
}
