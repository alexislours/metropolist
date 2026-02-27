import SwiftUI

enum AppBootstrap {
    case ready(DataStore)
    case failed(Error)

    init() {
        do {
            self = try .ready(DataStore())
        } catch {
            self = .failed(error)
        }
    }
}

@main
struct MetropolistApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var bootstrap = AppBootstrap()

    #if DEBUG
        private let isScreenshotMode = ProcessInfo.processInfo.arguments.contains("--screenshots")
    #endif

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case let .ready(dataStore):
                MainTabView()
                    .task {
                        registerQuickActions()
                        handleQuickAction(appDelegate.pendingQuickActionType)
                        appDelegate.pendingQuickActionType = nil
                        if let snapshot = (logged { try GamificationSnapshot.build(from: dataStore).snapshot }) {
                            WidgetDataBridge.updateWidget(from: snapshot)
                        }
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
                    .environment(dataStore)
            case let .failed(error):
                DataStoreErrorView(error: error)
            }
        }
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
        if case let .ready(dataStore) = bootstrap {
            dataStore.travelFlowPrefill = TravelFlowPrefill()
        }
    }
}

extension Notification.Name {
    static let quickActionTriggered = Notification.Name("com.alexislours.metropolist.quickAction")
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    var pendingQuickActionType: String?

    func application(
        _: UIApplication,
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

@MainActor
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        NotificationCenter.default.post(name: .quickActionTriggered, object: shortcutItem.type)
        completionHandler(true)
    }
}
