import SwiftUI

struct TransitUpdateSheet: View {
    let entry: TransitDatasetEntry
    let onDownload: () -> Void
    let onDefer: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "New transit data is available", comment: "Transit update sheet: title"))
                            .font(.title3.weight(.semibold))
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    TransitChangesView(changes: entry.changes)

                    VStack(spacing: 10) {
                        Button {
                            onDownload()
                            dismiss()
                        } label: {
                            Text(
                                String(
                                    localized: "Download (\(Self.sizeLabel(entry.byteSize)))",
                                    comment: "Transit update sheet: download button with size"
                                )
                            )
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            onDefer()
                            dismiss()
                        } label: {
                            Text(String(localized: "Not Now", comment: "Transit update sheet: dismiss button"))
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private var subtitle: String {
        let date = Self.formattedDate(entry.generatedAt)
        return String(
            localized: "Published \(date)",
            comment: "Transit update sheet: dataset publication date"
        )
    }

    static func sizeLabel(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    static func formattedDate(_ iso: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return iso }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
