import SwiftUI
import WidgetKit

struct MetropolistStatsWidget: Widget {
    let kind = "com.alexislours.metropolist.stats"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetropolistTimelineProvider()) { entry in
            StatsWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(LocalizedStringResource("Stats", comment: "Widget gallery: stats widget name"))
        .description(LocalizedStringResource("Your level and travel stats.", comment: "Widget gallery: stats widget description"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct StatsWidgetEntryView: View {
    let entry: MetropolistEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            StatsSmallView(data: entry.data)
        case .systemMedium:
            StatsMediumView(data: entry.data)
        case .systemLarge:
            StatsLargeView(data: entry.data)
        default:
            StatsSmallView(data: entry.data)
        }
    }
}
