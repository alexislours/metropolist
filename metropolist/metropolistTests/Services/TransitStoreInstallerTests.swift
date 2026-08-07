import Foundation
@testable import metropolist
import Testing
import TransitModels

@Suite("Transit store install decisions", .tags(.transitUpdate))
struct TransitStoreInstallerDecisionTests {
    private static func info(dataVersion: Int, schemaVersion: Int = 1) -> TransitStoreInfo {
        TransitStoreInfo(
            schemaVersion: schemaVersion,
            dataVersion: dataVersion,
            generatedAt: "2026-01-01T00:00:00.000Z",
            sha256: "bundle\(dataVersion)",
            byteSize: 100,
            counts: TransitStoreCounts(lines: 1, stations: 1, routeVariants: 1, lineStops: 1, transfers: 1),
            modelHash: "model"
        )
    }

    private static func descriptor(
        source: TransitStoreDescriptor.Source,
        dataVersion: Int,
        schemaVersion: Int = 1,
        sha256: String = "sha"
    ) -> TransitStoreDescriptor {
        TransitStoreDescriptor(
            source: source,
            schemaVersion: schemaVersion,
            dataVersion: dataVersion,
            generatedAt: "2026-01-01T00:00:00.000Z",
            sha256: sha256,
            byteSize: 100,
            installedAt: Date()
        )
    }

    private static func decide(
        bundle: Int,
        installed: TransitStoreDescriptor?,
        pending: TransitStoreDescriptor? = nil,
        storeExists: Bool = true
    ) -> TransitStoreInstaller.InstallDecision {
        TransitStoreInstaller.decide(
            bundle: info(dataVersion: bundle),
            installed: installed,
            pending: pending,
            storeExists: storeExists,
            currentSchemaVersion: 1
        )
    }

    @Test("Fresh install copies from the bundle")
    func freshInstall() {
        #expect(Self.decide(bundle: 10, installed: nil, storeExists: false) == .installFromBundle)
    }

    @Test("Missing descriptor reinstalls from the bundle")
    func missingDescriptor() {
        #expect(Self.decide(bundle: 10, installed: nil) == .installFromBundle)
    }

    @Test("Matching bundle version is kept")
    func steadyState() {
        let installed = Self.descriptor(source: .bundle, dataVersion: 10, sha256: "bundle10")
        #expect(Self.decide(bundle: 10, installed: installed) == .keep)
    }

    @Test("A bundled store whose contents changed is reinstalled even at the same version")
    func bundleContentChangedAtSameVersion() {
        let installed = Self.descriptor(source: .bundle, dataVersion: 10, sha256: "unknown-100-1")
        #expect(Self.decide(bundle: 10, installed: installed) == .installFromBundle)
    }

    @Test("A newer bundled dataset replaces the installed bundle copy")
    func appUpdateWithNewerBundle() {
        let installed = Self.descriptor(source: .bundle, dataVersion: 9)
        #expect(Self.decide(bundle: 10, installed: installed) == .installFromBundle)
    }

    @Test("A deliberate bundle rollback also takes effect")
    func bundleRollback() {
        let installed = Self.descriptor(source: .bundle, dataVersion: 11)
        #expect(Self.decide(bundle: 10, installed: installed) == .installFromBundle)
    }

    @Test("An app update must NOT clobber a newer downloaded store")
    func appUpdateKeepsNewerRemote() {
        let installed = Self.descriptor(source: .remote, dataVersion: 20)
        #expect(Self.decide(bundle: 10, installed: installed) == .keep)
        #expect(Self.decide(bundle: 20, installed: installed) == .keep)
    }

    @Test("A bundle newer than the downloaded store wins")
    func bundleNewerThanRemote() {
        let installed = Self.descriptor(source: .remote, dataVersion: 20)
        #expect(Self.decide(bundle: 21, installed: installed) == .installFromBundle)
    }

    @Test("A schema mismatch on the installed store forces a bundle reinstall")
    func schemaMismatchReinstalls() {
        let installed = Self.descriptor(source: .remote, dataVersion: 99, schemaVersion: 2)
        #expect(Self.decide(bundle: 10, installed: installed) == .installFromBundle)
    }

    @Test("A newer staged store is promoted")
    func promotesPending() {
        let installed = Self.descriptor(source: .bundle, dataVersion: 10)
        let pending = Self.descriptor(source: .remote, dataVersion: 11)
        #expect(Self.decide(bundle: 10, installed: installed, pending: pending) == .promotePending)
    }

    @Test("A staged store built for another schema is discarded")
    func discardsPendingWithWrongSchema() {
        let installed = Self.descriptor(source: .bundle, dataVersion: 10, sha256: "bundle10")
        let pending = Self.descriptor(source: .remote, dataVersion: 99, schemaVersion: 2)
        #expect(Self.decide(bundle: 10, installed: installed, pending: pending) == .keep)
    }

    @Test("A staged store older than the new bundle is discarded")
    func discardsStalePending() {
        let installed = Self.descriptor(source: .bundle, dataVersion: 12, sha256: "bundle12")
        let pending = Self.descriptor(source: .remote, dataVersion: 11)
        #expect(Self.decide(bundle: 12, installed: installed, pending: pending) == .keep)
    }
}

@Suite("Transit store installer file operations", .tags(.transitUpdate))
struct TransitStoreInstallerIOTests {
    private static func makeRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("installer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func makeBundleStore(in root: URL, contents: String) throws -> URL {
        let url = root.appendingPathComponent("bundled.store")
        try Data(contents.utf8).write(to: url)
        return url
    }

    private static func info(dataVersion: Int) -> TransitStoreInfo {
        TransitStoreInfo(
            schemaVersion: TransitSchema.version,
            dataVersion: dataVersion,
            generatedAt: "2026-01-01T00:00:00.000Z",
            sha256: "sha-\(dataVersion)",
            byteSize: 4,
            counts: TransitStoreCounts(lines: 1, stations: 1, routeVariants: 1, lineStops: 1, transfers: 1),
            modelHash: "model"
        )
    }

    @Test("First install writes the store and its descriptor")
    func firstInstall() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundleStore = try Self.makeBundleStore(in: root, contents: "bundle")

        let descriptor = try TransitStoreInstaller.prepareStore(
            in: root, bundleStore: bundleStore, bundleInfo: Self.info(dataVersion: 5)
        )
        let layout = TransitStoreInstaller.Layout(root: root)

        #expect(descriptor.source == .bundle)
        #expect(descriptor.dataVersion == 5)
        #expect(FileManager.default.fileExists(atPath: layout.store.path))
        #expect(FileManager.default.fileExists(atPath: layout.descriptor.path))
        #expect(try Data(contentsOf: layout.store) == Data("bundle".utf8))
    }

    @Test("The installed store is excluded from iCloud backup")
    func excludesFromBackup() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundleStore = try Self.makeBundleStore(in: root, contents: "bundle")

        try TransitStoreInstaller.prepareStore(
            in: root, bundleStore: bundleStore, bundleInfo: Self.info(dataVersion: 5)
        )
        let layout = TransitStoreInstaller.Layout(root: root)
        let values = try layout.store.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test("Promotion swaps in the staged store and clears staging")
    func promotesStagedStore() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundleStore = try Self.makeBundleStore(in: root, contents: "bundle")

        try TransitStoreInstaller.prepareStore(
            in: root, bundleStore: bundleStore, bundleInfo: Self.info(dataVersion: 5)
        )

        let candidate = root.appendingPathComponent("candidate.store")
        try Data("downloaded".utf8).write(to: candidate)
        let staged = TransitStoreDescriptor(
            source: .remote,
            schemaVersion: TransitSchema.version,
            dataVersion: 6,
            generatedAt: "2026-02-01T00:00:00.000Z",
            sha256: "remote-sha",
            byteSize: 10,
            installedAt: Date()
        )
        try TransitStoreInstaller.stage(candidate, descriptor: staged, in: root)
        #expect(TransitStoreInstaller.stagedDescriptor(in: root)?.dataVersion == 6)

        let promoted = try TransitStoreInstaller.prepareStore(
            in: root, bundleStore: bundleStore, bundleInfo: Self.info(dataVersion: 5)
        )
        let layout = TransitStoreInstaller.Layout(root: root)

        #expect(promoted.source == .remote)
        #expect(promoted.dataVersion == 6)
        #expect(try Data(contentsOf: layout.store) == Data("downloaded".utf8))
        #expect(!FileManager.default.fileExists(atPath: layout.staging.path))
    }

    @Test("A promoted store survives a later launch with an older bundle")
    func remoteStoreSurvivesAppUpdate() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundleStore = try Self.makeBundleStore(in: root, contents: "bundle")

        try TransitStoreInstaller.prepareStore(
            in: root, bundleStore: bundleStore, bundleInfo: Self.info(dataVersion: 5)
        )
        let candidate = root.appendingPathComponent("candidate.store")
        try Data("downloaded".utf8).write(to: candidate)
        try TransitStoreInstaller.stage(
            candidate,
            descriptor: TransitStoreDescriptor(
                source: .remote, schemaVersion: TransitSchema.version, dataVersion: 6,
                generatedAt: "g", sha256: "s", byteSize: 10, installedAt: Date()
            ),
            in: root
        )
        try TransitStoreInstaller.prepareStore(
            in: root, bundleStore: bundleStore, bundleInfo: Self.info(dataVersion: 5)
        )

        let again = try TransitStoreInstaller.prepareStore(
            in: root, bundleStore: bundleStore, bundleInfo: Self.info(dataVersion: 5)
        )
        let layout = TransitStoreInstaller.Layout(root: root)
        #expect(again.source == .remote)
        #expect(try Data(contentsOf: layout.store) == Data("downloaded".utf8))
    }

    @Test("Staging accepts a candidate downloaded inside the staging directory")
    func stagesCandidateFromStagingDirectory() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundleStore = try Self.makeBundleStore(in: root, contents: "bundle")

        try TransitStoreInstaller.prepareStore(
            in: root, bundleStore: bundleStore, bundleInfo: Self.info(dataVersion: 5)
        )

        let layout = TransitStoreInstaller.Layout(root: root)
        try FileManager.default.createDirectory(at: layout.staging, withIntermediateDirectories: true)
        let candidate = layout.staging.appendingPathComponent("candidate.store")
        try Data("downloaded".utf8).write(to: candidate)

        try TransitStoreInstaller.stage(
            candidate,
            descriptor: TransitStoreDescriptor(
                source: .remote, schemaVersion: TransitSchema.version, dataVersion: 6,
                generatedAt: "g", sha256: "s", byteSize: 10, installedAt: Date()
            ),
            in: root
        )

        #expect(TransitStoreInstaller.stagedDescriptor(in: root)?.dataVersion == 6)
        #expect(try Data(contentsOf: layout.pendingStore) == Data("downloaded".utf8))

        let promoted = try TransitStoreInstaller.prepareStore(
            in: root, bundleStore: bundleStore, bundleInfo: Self.info(dataVersion: 5)
        )
        #expect(promoted.dataVersion == 6)
        #expect(try Data(contentsOf: layout.store) == Data("downloaded".utf8))
    }

    @Test("Staging twice replaces the previous candidate")
    func restagingReplacesPrevious() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let layout = TransitStoreInstaller.Layout(root: root)

        for (contents, version) in [("first", 6), ("second", 7)] {
            try FileManager.default.createDirectory(at: layout.staging, withIntermediateDirectories: true)
            let candidate = layout.staging.appendingPathComponent("candidate.store")
            try Data(contents.utf8).write(to: candidate)
            try TransitStoreInstaller.stage(
                candidate,
                descriptor: TransitStoreDescriptor(
                    source: .remote, schemaVersion: TransitSchema.version, dataVersion: version,
                    generatedAt: "g", sha256: "s", byteSize: 10, installedAt: Date()
                ),
                in: root
            )
        }

        #expect(TransitStoreInstaller.stagedDescriptor(in: root)?.dataVersion == 7)
        #expect(try Data(contentsOf: layout.pendingStore) == Data("second".utf8))
    }

    @Test("Discarding staged data removes the whole staging directory")
    func discardStagedClearsDirectory() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let layout = TransitStoreInstaller.Layout(root: root)

        try FileManager.default.createDirectory(at: layout.staging, withIntermediateDirectories: true)
        let candidate = layout.staging.appendingPathComponent("candidate.store")
        try Data("downloaded".utf8).write(to: candidate)
        try TransitStoreInstaller.stage(
            candidate,
            descriptor: TransitStoreDescriptor(
                source: .remote, schemaVersion: TransitSchema.version, dataVersion: 6,
                generatedAt: "g", sha256: "s", byteSize: 10, installedAt: Date()
            ),
            in: root
        )

        TransitStoreInstaller.discardStaged(in: root)
        #expect(!FileManager.default.fileExists(atPath: layout.staging.path))
        #expect(TransitStoreInstaller.stagedDescriptor(in: root) == nil)
    }

    @Test("Installing a store removes the previous SQLite sidecars")
    func removesSidecarsOnInstall() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundleStore = try Self.makeBundleStore(in: root, contents: "bundle")
        let layout = TransitStoreInstaller.Layout(root: root)

        try TransitStoreInstaller.prepareStore(
            in: root, bundleStore: bundleStore, bundleInfo: Self.info(dataVersion: 5)
        )

        let sidecars = ["-wal", "-shm"].map {
            root.appendingPathComponent(layout.store.lastPathComponent + $0)
        }
        for sidecar in sidecars {
            try Data("stale".utf8).write(to: sidecar)
        }

        let newerBundle = try Self.makeBundleStore(in: root, contents: "newer")
        try TransitStoreInstaller.prepareStore(
            in: root, bundleStore: newerBundle, bundleInfo: Self.info(dataVersion: 6)
        )

        for sidecar in sidecars {
            #expect(!FileManager.default.fileExists(atPath: sidecar.path))
        }
    }

    @Test("Recovery reinstalls the bundle and denylists the failed hash")
    func recoveryRejectsFailedStore() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundleStore = try Self.makeBundleStore(in: root, contents: "bundle")
        let failedHash = "failed-\(UUID().uuidString)"

        let failed = TransitStoreDescriptor(
            source: .remote, schemaVersion: TransitSchema.version, dataVersion: 9,
            generatedAt: "g", sha256: failedHash, byteSize: 10, installedAt: Date()
        )
        let recovered = try TransitStoreInstaller.recoverFromBundle(
            in: root, bundleStore: bundleStore, bundleInfo: Self.info(dataVersion: 5), rejecting: failed
        )

        #expect(recovered.source == .bundle)
        #expect(TransitStoreInstaller.rejectedHashes().contains(failedHash))

        var hashes = UserDefaults.standard.stringArray(forKey: TransitStoreInstaller.rejectedHashesKey) ?? []
        hashes.removeAll { $0 == failedHash }
        UserDefaults.standard.set(hashes, forKey: TransitStoreInstaller.rejectedHashesKey)
    }
}
