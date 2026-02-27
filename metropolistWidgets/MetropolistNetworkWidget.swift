import SwiftUI
import WidgetKit

struct MetropolistNetworkWidget: Widget {
    let kind = "com.alexislours.metropolist.network"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetropolistTimelineProvider()) { entry in
            NetworkWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(LocalizedStringResource("Network", comment: "Widget gallery: network widget name"))
        .description(LocalizedStringResource("Your station coverage progress.", comment: "Widget gallery: network widget description"))
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

private struct NetworkWidgetEntryView: View {
    let entry: MetropolistEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            NetworkSmallView(data: entry.data)
        case .accessoryCircular:
            NetworkCircularView(data: entry.data)
        default:
            NetworkSmallView(data: entry.data)
        }
    }
}
