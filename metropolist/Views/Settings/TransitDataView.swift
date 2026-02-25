import SwiftUI
import UIKit

struct TransitDataView: View {
    let stats: TransitStats

    @State private var exportedFileURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CardSection(title: String(localized: "OVERVIEW", comment: "Transit data: overview section header")) {
                    VStack(spacing: 12) {
                        statRow(
                            label: String(localized: "Lines", comment: "Settings: transit data lines label"),
                            value: "\(stats.totalLines)"
                        )

                        statRow(
                            label: String(localized: "Branches", comment: "Settings: transit data branches label"),
                            value: "\(stats.totalBranches)"
                        )

                        statRow(
                            label: String(localized: "Stops", comment: "Settings: transit data stops label"),
                            value: "\(stats.totalStations)"
                        )

                        if let dbSize = stats.databaseSize {
                            Divider()

                            statRow(
                                label: String(localized: "Database Size", comment: "Settings: transit database size label"),
                                value: dbSize
                            )
                        }
                    }
                }

                if !stats.linesByMode.isEmpty {
                    CardSection(title: String(localized: "LINES BY MODE", comment: "Transit data: lines by mode section header")) {
                        VStack(spacing: 12) {
                            ForEach(stats.linesByMode, id: \.mode) { item in
                                HStack {
                                    Image(systemName: item.mode.systemImage)
                                        .frame(width: 20)
                                    Text(item.mode.label)
                                    Spacer()
                                    Text("\(item.count)")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }

                CardSection {
                    HStack {
                        Label(
                            String(localized: "Ile-de-France Mobilites (IDFM)", comment: "Settings: transit data provider attribution"),
                            systemImage: "building.columns.fill"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                if let generatedAt = stats.generatedAt {
                    CardSection {
                        HStack {
                            Text(String(localized: "Data Version", comment: "Settings: transit data version label"))
                                .font(.subheadline)
                            Spacer()
                            Text(generatedAt)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    exportDatabase()
                } label: {
                    CardSection {
                        HStack {
                            Label(
                                String(localized: "Export as SQLite", comment: "Transit data: export database button"),
                                systemImage: "square.and.arrow.up"
                            )
                            .font(.subheadline)
                            Spacer()
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(String(localized: "Transit Data", comment: "Transit data: navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $exportedFileURL) { url in
            ShareSheet(activityItems: [url])
                .presentationDetents([.medium])
        }
    }

    private func exportDatabase() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let storeURL = appSupport.appendingPathComponent("transit.store")
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }

        let tempDir = FileManager.default.temporaryDirectory
        let exportURL = tempDir.appendingPathComponent("metropolist-transit.sqlite")

        try? FileManager.default.removeItem(at: exportURL)
        do {
            try FileManager.default.copyItem(at: storeURL, to: exportURL)
            exportedFileURL = exportURL
        } catch {
            // Copy failed — nothing to present
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Share Sheet

extension URL: @retroactive Identifiable {
    public var id: String {
        absoluteString
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
