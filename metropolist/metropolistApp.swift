import SwiftUI

@main
struct MetropolistApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var dataStore = DataStore()

    #if DEBUG
        private let isScreenshotMode = ProcessInfo.processInfo.arguments.contains("--screenshots")
    #endif

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    registerQuickActions()
                    handleQuickAction(appDelegate.pendingQuickActionType)
                    appDelegate.pendingQuickActionType = nil
                }
                .onReceive(NotificationCenter.default.publisher(for: .quickActionTriggered)) { notification in
                    handleQuickAction(notification.object as? String)
                }
            #if DEBUG
                .task {
                    if isScreenshotMode {
                        MockDataSeeder.seed(dataStore: dataStore)
                    }
                }
            #endif
        }
        .environment(dataStore)
    }

    private func registerQuickActions() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: "com.alexislours.metropolist.startTravel",
                localizedTitle: String(localized: "Start travel"),
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "play.fill")
            ),
        ]
    }

    private func handleQuickAction(_ type: String?) {
        guard type == "com.alexislours.metropolist.startTravel" else { return }
        dataStore.travelFlowPrefill = TravelFlowPrefill()
    }
}

extension Notification.Name {
    static let quickActionTriggered = Notification.Name("com.alexislours.metropolist.quickAction")
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    var pendingQuickActionType: String?

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            pendingQuickActionType = shortcutItem.type
        }
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        NotificationCenter.default.post(name: .quickActionTriggered, object: shortcutItem.type)
        completionHandler(true)
    }
}
