import SwiftUI
import WidgetKit

struct MetropolistBadgesWidget: Widget {
    let kind = "com.alexislours.metropolist.badges"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetropolistTimelineProvider()) { entry in
            BadgesWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(LocalizedStringResource("Badges", comment: "Widget gallery: badges widget name"))
        .description(LocalizedStringResource("Your badge collection progress.", comment: "Widget gallery: badges widget description"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct BadgesWidgetEntryView: View {
    let entry: MetropolistEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            BadgesSmallView(data: entry.data)
        case .systemMedium:
            BadgesMediumView(data: entry.data)
        default:
            BadgesSmallView(data: entry.data)
        }
    }
}
