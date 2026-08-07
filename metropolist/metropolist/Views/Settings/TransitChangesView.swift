import SwiftUI

struct TransitChangesView: View {
    let changes: TransitDatasetChanges

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let summary = changes.localizedSummary(for: Self.languageCode) {
                Text(verbatim: summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let rows = deltaRows
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(rows, id: \.self) { row in
                        Text(row)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !changes.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(changes.highlights.enumerated()), id: \.offset) { _, highlight in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: Self.symbol(for: highlight.kind))
                                .font(.caption)
                                .foregroundStyle(Self.tint(for: highlight.kind))
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: highlight.label)
                                    .font(.subheadline)
                                if let detail = highlight.detail {
                                    Text(verbatim: detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            if rows.isEmpty, changes.highlights.isEmpty, changes.summary.isEmpty {
                Text(String(localized: "Updated transit data.", comment: "Transit updates: generic change description"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var deltaRows: [String] {
        let delta = changes.delta
        var rows: [String] = []
        if delta.linesAdded > 0 {
            rows.append(String(localized: "\(delta.linesAdded) lines added", comment: "Transit updates: lines added count"))
        }
        if delta.linesRemoved > 0 {
            rows.append(String(localized: "\(delta.linesRemoved) lines removed", comment: "Transit updates: lines removed count"))
        }
        if delta.linesModified > 0 {
            rows.append(String(localized: "\(delta.linesModified) lines updated", comment: "Transit updates: lines updated count"))
        }
        if delta.stationsAdded > 0 {
            rows.append(String(localized: "\(delta.stationsAdded) stops added", comment: "Transit updates: stops added count"))
        }
        if delta.stationsRemoved > 0 {
            rows.append(String(localized: "\(delta.stationsRemoved) stops removed", comment: "Transit updates: stops removed count"))
        }
        if delta.stationsModified > 0 {
            rows.append(String(localized: "\(delta.stationsModified) stops updated", comment: "Transit updates: stops updated count"))
        }
        if delta.routeVariantsChanged > 0 {
            rows.append(String(
                localized: "\(delta.routeVariantsChanged) routes changed",
                comment: "Transit updates: routes changed count"
            ))
        }
        if delta.transfersChanged > 0 {
            rows.append(String(
                localized: "\(delta.transfersChanged) connections changed",
                comment: "Transit updates: transfers changed count"
            ))
        }
        return rows
    }

    private static var languageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    private static func symbol(for kind: TransitChangeHighlightKind) -> String {
        switch kind {
        case .lineAdded, .stationAdded: "plus.circle.fill"
        case .lineRemoved, .stationRemoved: "minus.circle.fill"
        case .stationRenamed: "pencil.circle.fill"
        }
    }

    private static func tint(for kind: TransitChangeHighlightKind) -> Color {
        switch kind {
        case .lineAdded, .stationAdded: .green
        case .lineRemoved, .stationRemoved: .red
        case .stationRenamed: .orange
        }
    }
}
