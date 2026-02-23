import SwiftUI

struct MainTabView: View {
    @Environment(DataStore.self) private var dataStore
    @State private var showingTravelFlow = false
    @State private var activePrefill: TravelFlowPrefill?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView {
                LinesTab()
                    .tabItem {
                        Label(String(localized: "Lines", comment: "Tab: lines list"), systemImage: "tram.fill")
                    }

                ProfileTab()
                    .tabItem {
                        Label(String(localized: "Profile", comment: "Tab: user profile"), systemImage: "person.fill")
                    }

                SettingsTab()
                    .tabItem {
                        Label(String(localized: "Settings", comment: "Tab: app settings"), systemImage: "gear")
                    }
            }

            FABButton {
                activePrefill = nil
                showingTravelFlow = true
            }
            .padding(.trailing, 20)
            .padding(.bottom, 60)
        }
        .sheet(
            isPresented: $showingTravelFlow,
            onDismiss: { activePrefill = nil },
            content: { TravelCreationFlow(prefill: activePrefill) }
        )
        .celebrationOverlay()
        .onChange(of: dataStore.travelFlowPrefill) { _, newValue in
            if newValue != nil {
                activePrefill = dataStore.travelFlowPrefill
                dataStore.travelFlowPrefill = nil
                showingTravelFlow = true
            }
        }
    }
}
