import SwiftUI
import WidgetKit

@main
struct MetropolistWidgetBundle: WidgetBundle {
    var body: some Widget {
        MetropolistStreakWidget()
        MetropolistStatsWidget()
        MetropolistNetworkWidget()
        MetropolistBadgesWidget()
    }
}
