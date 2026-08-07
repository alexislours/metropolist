import SwiftUI

struct TransitUpdatesSection: View {
    @Bindable var model: TransitUpdateModel

    @State private var showCellularConfirmation = false
    @State private var showChanges = false

    var body: some View {
        CardSection(title: String(localized: "UPDATES", comment: "Transit data: updates section header")) {
            VStack(spacing: 0) {
                policyRow

                Divider()
                    .padding(.vertical, 12)

                stateContent
            }
        }
        .alert(
            String(localized: "Download over cellular?", comment: "Transit updates: cellular confirmation title"),
            isPresented: $showCellularConfirmation
        ) {
            Button(String(localized: "Download", comment: "Transit updates: confirm cellular download")) {
                model.download(allowExpensive: true)
            }
            Button(String(localized: "Cancel", comment: "Transit updates: cancel cellular download"), role: .cancel) {}
        } message: {
            Text(String(
                localized: "Automatic updates are set to Wi-Fi only. Download this update now anyway?",
                comment: "Transit updates: cellular confirmation message"
            ))
        }
    }

    private var policyRow: some View {
        HStack {
            Text(String(localized: "Automatic Updates", comment: "Transit updates: automatic updates label"))
                .font(.subheadline)
            Spacer()
            Picker(
                String(localized: "Automatic Updates", comment: "Transit updates: automatic updates label"),
                selection: Binding(get: { model.policy }, set: { model.policy = $0 })
            ) {
                ForEach(TransitAutoUpdatePolicy.allCases, id: \.self) { policy in
                    Text(policy.label).tag(policy)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(.secondary)
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch model.state {
        case .idle, .upToDate, .failed:
            VStack(alignment: .leading, spacing: 10) {
                checkRow
                if case let .failed(failure) = model.state {
                    Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        case .checking:
            HStack {
                Text(String(localized: "Checking for Updates…", comment: "Transit updates: checking label"))
                    .font(.subheadline)
                Spacer()
                ProgressView()
                    .controlSize(.small)
            }
        case let .available(entry):
            availableContent(entry)
        case let .downloading(entry, progress):
            downloadingContent(entry: entry, progress: progress)
        case .verifying:
            HStack {
                Text(String(localized: "Verifying…", comment: "Transit updates: verifying label"))
                    .font(.subheadline)
                Spacer()
                ProgressView()
                    .controlSize(.small)
            }
        case .staged:
            Label(
                String(
                    localized: "Update ready. It will be applied the next time you open Metropolist.",
                    comment: "Transit updates: staged label"
                ),
                systemImage: "checkmark.circle.fill"
            )
            .font(.subheadline)
            .foregroundStyle(.green)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var checkRow: some View {
        Button {
            Task { await model.check() }
        } label: {
            HStack {
                Text(String(localized: "Check for Updates", comment: "Transit updates: check button"))
                    .font(.subheadline)
                Spacer()
                if let checked = lastCheckedLabel {
                    Text(checked)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private func availableContent(_ entry: TransitDatasetEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    String(localized: "Update available", comment: "Transit updates: available label"),
                    systemImage: "arrow.down.circle.fill"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.tint)
                Spacer()
                Button {
                    showChanges.toggle()
                } label: {
                    Text(showChanges
                        ? String(localized: "Hide changes", comment: "Transit updates: hide change list")
                        : String(localized: "What's new", comment: "Transit updates: show change list"))
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if showChanges {
                TransitChangesView(changes: entry.changes)
            }

            Button {
                if model.policy == .wifi {
                    showCellularConfirmation = true
                } else {
                    model.download(allowExpensive: true)
                }
            } label: {
                Text(String(
                    localized: "Download (\(TransitUpdateSheet.sizeLabel(entry.byteSize)))",
                    comment: "Transit updates: download button with size"
                ))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func downloadingContent(
        entry: TransitDatasetEntry, progress: TransitUpdateProgress
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ProgressView(value: progress.fraction)
                .progressViewStyle(.linear)
            HStack {
                Text(verbatim: "\(TransitUpdateSheet.sizeLabel(progress.received)) / \(TransitUpdateSheet.sizeLabel(entry.byteSize))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    model.cancel()
                } label: {
                    Text(String(localized: "Cancel", comment: "Transit updates: cancel download"))
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
    }

    private var lastCheckedLabel: String? {
        guard let date = model.lastCheckedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
