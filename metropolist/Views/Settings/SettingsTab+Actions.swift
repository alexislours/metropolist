import SwiftData
import SwiftUI
import TransitModels

extension SettingsTab {
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    func loadTransitStats() -> TransitStats? {
        do {
            let lines = try store.transitService.allLines()
            let totalStations = try store.transitService.totalStationCount()
            let totalBranches = try store.transitService.totalRouteVariantCount()

            var countsByMode: [TransitMode: Int] = [:]
            for line in lines {
                if let mode = TransitMode(rawValue: line.mode) {
                    countsByMode[mode, default: 0] += 1
                }
            }

            let linesByMode = countsByMode
                .map { (mode: $0.key, count: $0.value) }
                .sorted { $0.mode.sortOrder < $1.mode.sortOrder }

            var generatedAt: String?
            if let raw = try store.transitService.metadata(forKey: "generatedAt") {
                if let date = Self.isoFormatter.date(from: raw) {
                    generatedAt = Self.displayDateFormatter.string(from: date)
                }
            }

            let databaseSize = Self.formattedTransitStoreSize()

            return TransitStats(
                totalLines: lines.count,
                totalStations: totalStations,
                totalBranches: totalBranches,
                linesByMode: linesByMode,
                generatedAt: generatedAt,
                databaseSize: databaseSize
            )
        } catch {
            return nil
        }
    }

    private static let bytesFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }()

    private static func formattedTransitStoreSize() -> String? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let storeURL = appSupport.appendingPathComponent("transit.store")
        guard let attrs = (logged { try FileManager.default.attributesOfItem(atPath: storeURL.path) }),
              let size = attrs[.size] as? Int64
        else {
            return nil
        }
        return bytesFormatter.string(fromByteCount: size)
    }

    func prepareExport() {
        do {
            let data = try UserDataTransferService.exportJSON(context: store.userContext)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("metropolist-backup.json")
            try data.write(to: tempURL)
            exportedFileURL = tempURL
        } catch {
            importAlert = ImportAlert(
                title: String(localized: "Export Failed", comment: "Settings: export error alert title"),
                message: error.localizedDescription
            )
        }
    }

    func deleteAllUserData() {
        do {
            try store.userContext.delete(model: CompletedStop.self)
            try store.userContext.delete(model: Travel.self)
            try store.userContext.delete(model: Favorite.self)
            try store.userContext.save()
            store.userDataVersion += 1
            WidgetDataBridge.updateWidget(from: .empty)
            importAlert = ImportAlert(
                title: String(localized: "Data Deleted", comment: "Settings: data deleted alert title"),
                message: String(localized: "All user data has been deleted.", comment: "Settings: data deleted confirmation message")
            )
        } catch {
            importAlert = ImportAlert(
                title: String(localized: "Delete Failed", comment: "Settings: delete error alert title"),
                message: error.localizedDescription
            )
        }
    }

    func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case let .success(url):
            guard url.startAccessingSecurityScopedResource() else {
                importAlert = ImportAlert(
                    title: String(localized: "Import Failed", comment: "Settings: import error alert title"),
                    message: String(localized: "Could not access the selected file.", comment: "Settings: file access error message")
                )
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                let counts = try UserDataTransferService.importJSON(data: data, context: store.userContext)
                store.userDataVersion += 1
                if let snapshot = (logged { try GamificationSnapshot.build(from: store).snapshot }) {
                    WidgetDataBridge.updateWidget(from: snapshot)
                }
                importAlert = ImportAlert(
                    title: String(localized: "Import Successful", comment: "Settings: import success alert title"),
                    message: Self.importSummary(counts)
                )
            } catch {
                importAlert = ImportAlert(
                    title: String(localized: "Import Failed", comment: "Settings: import error alert title"),
                    message: error.localizedDescription
                )
            }
        case let .failure(error):
            importAlert = ImportAlert(
                title: String(localized: "Import Failed", comment: "Settings: import error alert title"),
                message: error.localizedDescription
            )
        }
    }

    private static func importSummary(_ counts: ImportResult) -> String {
        let stops = counts.stopsImported
        let travels = counts.travelsImported
        let favs = counts.favoritesImported
        return String(
            localized: "\(stops) stops, \(travels) travels, and \(favs) favorites imported.",
            comment: "Settings: import success message with counts"
        )
    }
}
