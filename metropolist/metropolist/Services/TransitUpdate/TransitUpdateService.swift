import Foundation
import SwiftData
import TransitModels

actor TransitUpdateService {
    static let manifestURLs: [URL] = [
        URL(string: "https://raw.githubusercontent.com/alexislours/metropolist/main/dist/transit-manifest.json")!,
    ]

    private let transport: any TransitTransport
    private let root: URL

    init(transport: any TransitTransport = URLSessionTransport(), root: URL) {
        self.transport = transport
        self.root = root
    }

    func fetchManifest() async throws -> TransitDatasetManifest {
        var lastFailure: TransitUpdateFailure = .manifestUnreadable
        for url in Self.manifestURLs {
            do {
                return try await fetchManifest(from: url)
            } catch let failure as TransitUpdateFailure {
                lastFailure = failure
            }
        }
        throw lastFailure
    }

    private func fetchManifest(from url: URL) async throws -> TransitDatasetManifest {
        let signatureURL = url.appendingPathExtension("sig")
        let manifestData = try await transport.fetch(url, allowExpensive: true)
        let signatureData = try await transport.fetch(signatureURL, allowExpensive: true)

        guard let signature = Data(base64Encoded: sanitized(signatureData)) else {
            throw TransitUpdateFailure.manifestUntrusted
        }
        guard TransitManifestVerifier.verify(manifest: manifestData, signature: signature) else {
            throw TransitUpdateFailure.manifestUntrusted
        }
        guard let manifest = try? JSONDecoder().decode(TransitDatasetManifest.self, from: manifestData) else {
            throw TransitUpdateFailure.manifestUnreadable
        }
        guard manifest.isSupported else {
            throw TransitUpdateFailure.incompatibleManifest
        }
        return manifest
    }

    func downloadAndStage(
        _ entry: TransitDatasetEntry,
        allowExpensive: Bool,
        onProgress: @Sendable @escaping (Int64) -> Void
    ) async throws -> TransitStoreDescriptor {
        try assertDiskSpace(for: entry)

        let layout = TransitStoreInstaller.Layout(root: root)
        let scratch = layout.staging.appendingPathComponent("candidate.store")
        try FileManager.default.createDirectory(at: layout.staging, withIntermediateDirectories: true)

        let digest = try await transport.download(
            from: entry.url,
            to: scratch,
            expectedBytes: entry.byteSize,
            allowExpensive: allowExpensive,
            onProgress: onProgress
        )
        guard digest == entry.sha256 else {
            try? FileManager.default.removeItem(at: scratch)
            throw TransitUpdateFailure.checksumMismatch
        }

        try validate(scratch, against: entry, layout: layout)

        let descriptor = TransitStoreDescriptor(
            source: .remote,
            schemaVersion: entry.schemaVersion,
            dataVersion: entry.dataVersion,
            generatedAt: entry.generatedAt,
            sha256: entry.sha256,
            byteSize: entry.byteSize,
            installedAt: Date()
        )
        do {
            try TransitStoreInstaller.stage(scratch, descriptor: descriptor, in: root)
        } catch {
            try? FileManager.default.removeItem(at: scratch)
            throw TransitUpdateFailure.storeUnusable(error.localizedDescription)
        }
        return descriptor
    }

    private func validate(
        _ candidate: URL, against entry: TransitDatasetEntry, layout: TransitStoreInstaller.Layout
    ) throws {
        do {
            try TransitStoreValidator.validate(
                storeAt: candidate,
                expecting: TransitStoreValidator.Expectation(
                    schemaVersion: TransitSchema.version,
                    dataVersion: entry.dataVersion,
                    generatedAt: entry.generatedAt,
                    counts: entry.counts
                )
            )
        } catch {
            try? FileManager.default.removeItem(at: candidate)
            throw TransitUpdateFailure.storeUnusable("\(error)")
        }

        do {
            try probeWithSwiftData(candidate, layout: layout)
        } catch {
            try? FileManager.default.removeItem(at: candidate)
            throw TransitUpdateFailure.storeUnusable("\(error)")
        }
    }

    private func probeWithSwiftData(_ candidate: URL, layout: TransitStoreInstaller.Layout) throws {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: layout.probe)
        try fileManager.createDirectory(at: layout.probe, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: layout.probe) }

        let probeStore = layout.probe.appendingPathComponent("transit.store")
        try fileManager.copyItem(at: candidate, to: probeStore)

        let schema = Schema(TransitSchema.models)
        let config = ModelConfiguration(schema: schema, url: probeStore, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        context.autosaveEnabled = false

        guard try context.fetchCount(FetchDescriptor<TransitLine>()) > 0,
              try context.fetchCount(FetchDescriptor<TransitStation>()) > 0,
              try context.fetchCount(FetchDescriptor<TransitLineStop>()) > 0
        else {
            throw TransitUpdateFailure.storeUnusable("empty after open")
        }
    }

    private func assertDiskSpace(for entry: TransitDatasetEntry) throws {
        let values = try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let available = values?.volumeAvailableCapacityForImportantUsage else { return }
        guard available > entry.byteSize * 3 else {
            throw TransitUpdateFailure.insufficientDiskSpace
        }
    }

    private func sanitized(_ data: Data) -> String {
        (String(bytes: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
