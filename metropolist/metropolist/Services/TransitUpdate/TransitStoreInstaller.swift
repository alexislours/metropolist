import Foundation
import TransitModels

nonisolated enum TransitStoreInstaller {
    nonisolated enum InstallDecision: Equatable, Sendable {
        case keep
        case installFromBundle
        case promotePending
    }

    nonisolated struct Layout: Sendable {
        let root: URL

        var store: URL {
            root.appendingPathComponent("transit.store")
        }

        var descriptor: URL {
            root.appendingPathComponent("transit-store.json")
        }

        var staging: URL {
            root.appendingPathComponent("PendingTransitStore", isDirectory: true)
        }

        var pendingStore: URL {
            staging.appendingPathComponent("transit.store")
        }

        var pendingDescriptor: URL {
            staging.appendingPathComponent("transit-store.json")
        }

        var probe: URL {
            staging.appendingPathComponent("probe", isDirectory: true)
        }

        init(root: URL) {
            self.root = root
        }
    }

    static let rejectedHashesKey = "transitRejectedHashes"
    private static let legacyModDateKey = "transitStoreModDate"
    private static let maxRejectedHashes = 5

    // MARK: - Decision

    nonisolated static func decide(
        bundle: TransitStoreInfo,
        installed: TransitStoreDescriptor?,
        pending: TransitStoreDescriptor?,
        storeExists: Bool,
        currentSchemaVersion: Int
    ) -> InstallDecision {
        if let pending {
            let baseline = max(bundle.dataVersion, installed?.dataVersion ?? 0)
            let usable = pending.schemaVersion == currentSchemaVersion && pending.dataVersion > baseline
            if usable {
                return .promotePending
            }
        }

        guard storeExists else { return .installFromBundle }
        guard let installed else { return .installFromBundle }
        guard installed.schemaVersion == currentSchemaVersion else { return .installFromBundle }

        switch installed.source {
        case .bundle:
            let unchanged = installed.dataVersion == bundle.dataVersion && installed.sha256 == bundle.sha256
            return unchanged ? .keep : .installFromBundle
        case .remote:
            return bundle.dataVersion > installed.dataVersion ? .installFromBundle : .keep
        }
    }

    // MARK: - Install

    @discardableResult
    nonisolated static func prepareStore(
        in root: URL,
        bundleStore: URL,
        bundleInfo: TransitStoreInfo
    ) throws -> TransitStoreDescriptor {
        let layout = Layout(root: root)
        let fileManager = FileManager.default

        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        } catch {
            throw DataStoreError.appSupportDirCreationFailed(underlying: error)
        }

        let installed = readDescriptor(at: layout.descriptor)
        let pending = readDescriptor(at: layout.pendingDescriptor)
        let hasPendingStore = fileManager.fileExists(atPath: layout.pendingStore.path)

        let decision = decide(
            bundle: bundleInfo,
            installed: installed,
            pending: hasPendingStore ? pending : nil,
            storeExists: fileManager.fileExists(atPath: layout.store.path),
            currentSchemaVersion: TransitSchema.version
        )

        let descriptor: TransitStoreDescriptor
        switch decision {
        case .keep:
            descriptor = installed ?? TransitStoreDescriptor(
                info: bundleInfo, source: .bundle, installedAt: Date()
            )
        case .installFromBundle:
            try replaceStore(at: layout, with: bundleStore, copying: true)
            descriptor = TransitStoreDescriptor(info: bundleInfo, source: .bundle, installedAt: Date())
        case .promotePending:
            guard let pending else { throw DataStoreError.transitStoreMissing }
            try replaceStore(at: layout, with: layout.pendingStore, copying: false)
            descriptor = TransitStoreDescriptor(
                source: .remote,
                schemaVersion: pending.schemaVersion,
                dataVersion: pending.dataVersion,
                generatedAt: pending.generatedAt,
                sha256: pending.sha256,
                byteSize: pending.byteSize,
                installedAt: Date()
            )
        }

        if decision != .keep {
            UserDefaults.standard.removeObject(forKey: legacyModDateKey)
            try writeDescriptor(descriptor, to: layout.descriptor)
        }
        if decision != .keep || hasPendingStore {
            try? fileManager.removeItem(at: layout.staging)
        }

        excludeFromBackup(layout.store)
        excludeFromBackup(layout.descriptor)
        return descriptor
    }

    nonisolated static func recoverFromBundle(
        in root: URL,
        bundleStore: URL,
        bundleInfo: TransitStoreInfo,
        rejecting failed: TransitStoreDescriptor?
    ) throws -> TransitStoreDescriptor {
        let layout = Layout(root: root)
        let fileManager = FileManager.default

        if let failed, failed.source == .remote {
            rejectHash(failed.sha256)
        }

        try? fileManager.removeItem(at: layout.store)
        removeSidecars(of: layout.store)
        try? fileManager.removeItem(at: layout.staging)

        try replaceStore(at: layout, with: bundleStore, copying: true)
        let descriptor = TransitStoreDescriptor(info: bundleInfo, source: .bundle, installedAt: Date())
        try writeDescriptor(descriptor, to: layout.descriptor)
        excludeFromBackup(layout.store)
        excludeFromBackup(layout.descriptor)
        return descriptor
    }

    // MARK: - Staging

    nonisolated static func stage(
        _ candidate: URL,
        descriptor: TransitStoreDescriptor,
        in root: URL
    ) throws {
        let layout = Layout(root: root)
        let fileManager = FileManager.default

        try fileManager.createDirectory(at: layout.staging, withIntermediateDirectories: true)
        try? fileManager.removeItem(at: layout.pendingDescriptor)
        try? fileManager.removeItem(at: layout.pendingStore)
        removeSidecars(of: layout.pendingStore)
        try? fileManager.removeItem(at: layout.probe)
        try fileManager.moveItem(at: candidate, to: layout.pendingStore)
        try writeDescriptor(descriptor, to: layout.pendingDescriptor)
        excludeFromBackup(layout.staging)
    }

    nonisolated static func discardStaged(in root: URL) {
        try? FileManager.default.removeItem(at: Layout(root: root).staging)
    }

    nonisolated static func stagedDescriptor(in root: URL) -> TransitStoreDescriptor? {
        let layout = Layout(root: root)
        guard FileManager.default.fileExists(atPath: layout.pendingStore.path) else { return nil }
        return readDescriptor(at: layout.pendingDescriptor)
    }

    // MARK: - Rejected hashes

    nonisolated static func rejectedHashes() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: rejectedHashesKey) ?? [])
    }

    nonisolated static func rejectHash(_ hash: String) {
        var hashes = UserDefaults.standard.stringArray(forKey: rejectedHashesKey) ?? []
        guard !hashes.contains(hash) else { return }
        hashes.append(hash)
        if hashes.count > maxRejectedHashes {
            hashes.removeFirst(hashes.count - maxRejectedHashes)
        }
        UserDefaults.standard.set(hashes, forKey: rejectedHashesKey)
    }

    // MARK: - Bundle

    nonisolated static func bundledStoreURL(in bundle: Bundle = .main) throws -> URL {
        guard let url = bundle.url(forResource: "transit", withExtension: "store") else {
            throw DataStoreError.transitStoreMissing
        }
        return url
    }

    nonisolated static func bundledInfo(in bundle: Bundle = .main, storeURL: URL) -> TransitStoreInfo {
        if let url = bundle.url(forResource: "transit-info", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let info = try? JSONDecoder().decode(TransitStoreInfo.self, from: data) {
            return info
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: storeURL.path)
        let byteSize = attributes?[.size] as? Int64 ?? 0
        let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return TransitStoreInfo(
            schemaVersion: TransitSchema.version,
            dataVersion: 0,
            generatedAt: "",
            sha256: "unknown-\(byteSize)-\(Int(modified))",
            byteSize: byteSize,
            counts: TransitStoreCounts(lines: 0, stations: 0, routeVariants: 0, lineStops: 0, transfers: 0),
            modelHash: ""
        )
    }

    // MARK: - Private

    private nonisolated static func replaceStore(
        at layout: Layout, with source: URL, copying: Bool
    ) throws {
        let fileManager = FileManager.default
        let temp = layout.root.appendingPathComponent(UUID().uuidString + ".store")
        do {
            if copying {
                try fileManager.copyItem(at: source, to: temp)
            } else {
                try fileManager.moveItem(at: source, to: temp)
            }
            if fileManager.fileExists(atPath: layout.store.path) {
                _ = try fileManager.replaceItemAt(layout.store, withItemAt: temp)
            } else {
                try fileManager.moveItem(at: temp, to: layout.store)
            }
        } catch {
            try? fileManager.removeItem(at: temp)
            throw DataStoreError.transitStoreCopyFailed(underlying: error)
        }
        removeSidecars(of: layout.store)
    }

    private nonisolated static func removeSidecars(of store: URL) {
        let fileManager = FileManager.default
        let directory = store.deletingLastPathComponent()
        for suffix in ["-wal", "-shm"] {
            let sidecar = directory.appendingPathComponent(store.lastPathComponent + suffix)
            try? fileManager.removeItem(at: sidecar)
        }
    }

    private nonisolated static func readDescriptor(at url: URL) -> TransitStoreDescriptor? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TransitStoreDescriptor.self, from: data)
    }

    private nonisolated static func writeDescriptor(
        _ descriptor: TransitStoreDescriptor, to url: URL
    ) throws {
        let data = try JSONEncoder().encode(descriptor)
        try data.write(to: url, options: .atomic)
    }

    private nonisolated static func excludeFromBackup(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        var target = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? target.setResourceValues(values)
    }
}
