import SwiftUI

@main
struct MetropolistApp: App {
    @State private var dataStore = DataStore()

    #if DEBUG
        private let isScreenshotMode = ProcessInfo.processInfo.arguments.contains("--screenshots")
    #endif

    var body: some Scene {
        WindowGroup {
            MainTabView()
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
}
