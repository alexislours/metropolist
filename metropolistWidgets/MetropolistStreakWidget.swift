import SwiftUI
import WidgetKit

struct MetropolistStreakWidget: Widget {
    let kind = "com.alexislours.metropolist.streak"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetropolistTimelineProvider()) { entry in
            StreakWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {}
        }
        .configurationDisplayName(LocalizedStringResource("Streak", comment: "Widget gallery: streak widget name"))
        .description(LocalizedStringResource("Your current travel streak.", comment: "Widget gallery: streak widget description"))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

private struct StreakWidgetEntryView: View {
    let entry: MetropolistEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            StreakCircularView(data: entry.data)
        case .accessoryRectangular:
            StreakRectangularView(data: entry.data)
        default:
            StreakCircularView(data: entry.data)
        }
    }
}
