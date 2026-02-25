import CloudKit
import SwiftUI

extension SettingsTab {
    // MARK: - CloudKit Section

    var cloudKitSection: some View {
        CardSection(title: String(localized: "ICLOUD SYNC", comment: "Settings: iCloud sync section header")) {
            HStack(spacing: 14) {
                Image(systemName: cloudKitStatusIcon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(cloudKitStatusColor)
                    .frame(width: 50, height: 50)
                    .background(cloudKitStatusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "iCloud Sync", comment: "Settings: iCloud sync feature title"))
                        .font(.subheadline.weight(.semibold))
                    Text(String(localized: "Travels and stops sync across your devices", comment: "Settings: iCloud sync description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(cloudKitStatusLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(cloudKitStatusColor.opacity(0.12))
                    .foregroundStyle(cloudKitStatusColor)
                    .clipShape(.capsule)
            }
        }
    }

    var cloudKitStatusLabel: String {
        switch cloudKitStatus {
        case .available: return String(localized: "Active", comment: "Settings: iCloud status active")
        case .noAccount: return String(localized: "No Account", comment: "Settings: iCloud status no account")
        case .restricted: return String(localized: "Restricted", comment: "Settings: iCloud status restricted")
        case .temporarilyUnavailable: return String(localized: "Unavailable", comment: "Settings: iCloud status unavailable")
        case .couldNotDetermine: return String(localized: "Unknown", comment: "Settings: iCloud status unknown")
        case nil: return String(localized: "Checking", comment: "Settings: iCloud status checking")
        @unknown default: return String(localized: "Unknown", comment: "Settings: iCloud status unknown")
        }
    }

    var cloudKitStatusIcon: String {
        switch cloudKitStatus {
        case .available: return "checkmark.icloud.fill"
        case .noAccount: return "icloud.slash.fill"
        case .restricted, .temporarilyUnavailable: return "exclamationmark.icloud.fill"
        case .couldNotDetermine, nil: return "icloud.fill"
        @unknown default: return "icloud.fill"
        }
    }

    var cloudKitStatusColor: Color {
        switch cloudKitStatus {
        case .available: return .green
        case .noAccount, .restricted, .temporarilyUnavailable: return .orange
        case .couldNotDetermine, nil: return .secondary
        @unknown default: return .secondary
        }
    }
}
