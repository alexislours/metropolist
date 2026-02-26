import SwiftUI

struct DataStoreErrorView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView {
            Label(
                String(localized: "Unable to Start", comment: "DataStore error screen: title"),
                systemImage: "exclamationmark.triangle.fill"
            )
        } description: {
            Text(error.localizedDescription)
            Text(String(
                localized: "Try restarting the app. If the problem persists, reinstall the app.",
                comment: "DataStore error screen: recovery suggestion"
            ))
        }
    }
}

#Preview {
    DataStoreErrorView(
        error: NSError(
            domain: "NSCocoaErrorDomain",
            code: 134_110,
            userInfo: [
                NSLocalizedDescriptionKey: "Could not create user database: Failed to find a currently active account.",
            ]
        )
    )
}
