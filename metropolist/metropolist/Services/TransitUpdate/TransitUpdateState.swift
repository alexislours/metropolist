import Foundation
import TransitModels

nonisolated enum TransitAutoUpdatePolicy: String, CaseIterable, Sendable {
    case off
    case wifi
    case always

    var allowsAutomaticCheck: Bool {
        self != .off
    }

    var label: String {
        switch self {
        case .off:
            String(localized: "Off", comment: "Transit updates: automatic updates off")
        case .wifi:
            String(localized: "Wi-Fi Only", comment: "Transit updates: automatic updates on Wi-Fi only")
        case .always:
            String(localized: "Always", comment: "Transit updates: automatic updates always")
        }
    }
}

nonisolated enum TransitUpdateFailure: Error, Equatable, Sendable {
    case offline
    case network(status: Int?)
    case manifestUnreadable
    case manifestUntrusted
    case incompatibleManifest
    case sizeMismatch
    case checksumMismatch
    case storeUnusable(String)
    case insufficientDiskSpace
    case cancelled

    var message: String {
        switch self {
        case .offline:
            String(localized: "No internet connection.", comment: "Transit update error: offline")
        case .network:
            String(localized: "Could not reach the update server.", comment: "Transit update error: network")
        case .manifestUnreadable, .incompatibleManifest:
            String(localized: "The update information could not be read.", comment: "Transit update error: bad manifest")
        case .manifestUntrusted:
            String(localized: "The update could not be verified as authentic.", comment: "Transit update error: bad signature")
        case .sizeMismatch, .checksumMismatch:
            String(localized: "The download was incomplete or corrupted.", comment: "Transit update error: integrity")
        case .storeUnusable:
            String(localized: "The downloaded data could not be opened.", comment: "Transit update error: unusable store")
        case .insufficientDiskSpace:
            String(localized: "Not enough free space to download the update.", comment: "Transit update error: disk full")
        case .cancelled:
            String(localized: "Download cancelled.", comment: "Transit update error: cancelled")
        }
    }
}

nonisolated struct TransitUpdateProgress: Equatable, Sendable {
    let received: Int64
    let total: Int64

    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(received) / Double(total))
    }
}

nonisolated enum TransitUpdateState: Equatable, Sendable {
    case idle
    case checking
    case upToDate(checkedAt: Date)
    case available(TransitDatasetEntry)
    case downloading(entry: TransitDatasetEntry, progress: TransitUpdateProgress)
    case verifying(TransitDatasetEntry)
    case staged(TransitStoreDescriptor)
    case failed(TransitUpdateFailure)

    var entry: TransitDatasetEntry? {
        switch self {
        case let .available(entry), let .downloading(entry, _), let .verifying(entry):
            entry
        default:
            nil
        }
    }

    var isBusy: Bool {
        switch self {
        case .checking, .downloading, .verifying: true
        default: false
        }
    }
}
