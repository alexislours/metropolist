import Foundation
import Observation
import TransitModels

@MainActor
@Observable
final class TransitUpdateModel {
    private(set) var state: TransitUpdateState = .idle
    var isPresentingPrompt = false

    @ObservationIgnored private let service: TransitUpdateService
    @ObservationIgnored private let installedDataVersion: Int
    @ObservationIgnored private let root: URL?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var lastPublishedBytes: Int64 = 0
    @ObservationIgnored private var lastPublishedAt: Date = .distantPast

    static let autoUpdateKey = "transitAutoUpdate"
    static let lastCheckKey = "transitLastUpdateCheck"
    static let deferredVersionKey = "transitDeferredDataVersion"
    private static let checkInterval: TimeInterval = 24 * 60 * 60
    private static let progressInterval: TimeInterval = 0.1

    init(service: TransitUpdateService, installedDataVersion: Int, root: URL? = nil) {
        self.service = service
        self.installedDataVersion = installedDataVersion
        self.root = root
    }

    convenience init(descriptor: TransitStoreDescriptor, root: URL) {
        self.init(
            service: TransitUpdateService(root: root),
            installedDataVersion: descriptor.dataVersion,
            root: root
        )
    }

    var policy: TransitAutoUpdatePolicy {
        get {
            TransitAutoUpdatePolicy(
                rawValue: UserDefaults.standard.string(forKey: Self.autoUpdateKey) ?? ""
            ) ?? .wifi
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.autoUpdateKey) }
    }

    var lastCheckedAt: Date? {
        let raw = UserDefaults.standard.double(forKey: Self.lastCheckKey)
        return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
    }

    // MARK: - Prompt gating

    nonisolated static func shouldPresentPrompt(
        state: TransitUpdateState,
        policy: TransitAutoUpdatePolicy,
        deferredVersion: Int,
        isFirstLaunch: Bool
    ) -> Bool {
        guard policy != .off, !isFirstLaunch else { return false }
        guard case let .available(entry) = state else { return false }
        return entry.dataVersion != deferredVersion
    }

    func deferCurrentUpdate() {
        if let entry = state.entry {
            UserDefaults.standard.set(entry.dataVersion, forKey: Self.deferredVersionKey)
        }
        isPresentingPrompt = false
    }

    // MARK: - Checking

    func autoCheckIfDue(isFirstLaunch: Bool) async {
        guard policy.allowsAutomaticCheck else { return }
        if let last = lastCheckedAt, Date().timeIntervalSince(last) < Self.checkInterval {
            return
        }
        await check()

        let deferred = UserDefaults.standard.integer(forKey: Self.deferredVersionKey)
        if Self.shouldPresentPrompt(
            state: state, policy: policy, deferredVersion: deferred, isFirstLaunch: isFirstLaunch
        ) {
            isPresentingPrompt = true
        }
    }

    func check() async {
        guard !state.isBusy else { return }
        state = .checking
        do {
            let manifest = try await service.fetchManifest()
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)

            let entry = manifest.bestEntry(
                schemaVersion: TransitSchema.version,
                appBuild: Self.appBuild,
                installedDataVersion: max(installedDataVersion, stagedDataVersion),
                rejectedHashes: TransitStoreInstaller.rejectedHashes()
            )
            state = entry.map { .available($0) } ?? .upToDate(checkedAt: Date())
        } catch let failure as TransitUpdateFailure {
            state = .failed(failure)
        } catch {
            state = .failed(.network(status: nil))
        }
    }

    // MARK: - Downloading

    func download(allowExpensive: Bool) {
        guard let entry = state.entry, !state.isBusy else { return }
        isPresentingPrompt = false
        lastPublishedBytes = 0
        lastPublishedAt = .distantPast
        state = .downloading(entry: entry, progress: TransitUpdateProgress(received: 0, total: entry.byteSize))

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let descriptor = try await service.downloadAndStage(
                    entry,
                    allowExpensive: allowExpensive,
                    onProgress: { [weak self] received in
                        Task { @MainActor in self?.publish(received: received, entry: entry) }
                    }
                )
                guard !Task.isCancelled else {
                    discardStaged()
                    return
                }
                state = .staged(descriptor)
            } catch let failure as TransitUpdateFailure {
                state = failure == .cancelled ? .idle : .failed(failure)
            } catch {
                state = .failed(.network(status: nil))
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        state = .idle
    }

    private func discardStaged() {
        guard let root else { return }
        TransitStoreInstaller.discardStaged(in: root)
    }

    private func publish(received: Int64, entry: TransitDatasetEntry) {
        guard case .downloading = state else { return }
        let now = Date()
        let step = max(entry.byteSize / 100, 1)
        let enough = received - lastPublishedBytes >= step
        let overdue = now.timeIntervalSince(lastPublishedAt) >= Self.progressInterval
        guard enough || overdue || received >= entry.byteSize else { return }

        lastPublishedBytes = received
        lastPublishedAt = now
        state = .downloading(
            entry: entry, progress: TransitUpdateProgress(received: received, total: entry.byteSize)
        )
    }

    // MARK: - Helpers

    private var stagedDataVersion: Int {
        guard let root else { return 0 }
        return TransitStoreInstaller.stagedDescriptor(in: root)?.dataVersion ?? 0
    }

    static var appBuild: Int {
        Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "") ?? 0
    }
}
