import Foundation
import TransitModels

nonisolated enum TransitChangeHighlightKind: String, Codable, Sendable {
    case lineAdded
    case lineRemoved
    case stationAdded
    case stationRemoved
    case stationRenamed
}

nonisolated struct TransitChangeHighlight: Equatable, Sendable {
    let kind: TransitChangeHighlightKind
    let label: String
    let detail: String?
}

nonisolated struct TransitChangeDelta: Codable, Equatable, Sendable {
    var linesAdded = 0
    var linesRemoved = 0
    var linesModified = 0
    var stationsAdded = 0
    var stationsRemoved = 0
    var stationsModified = 0
    var routeVariantsChanged = 0
    var transfersChanged = 0

    var isEmpty: Bool {
        linesAdded == 0 && linesRemoved == 0 && linesModified == 0
            && stationsAdded == 0 && stationsRemoved == 0 && stationsModified == 0
            && routeVariantsChanged == 0 && transfersChanged == 0
    }
}

nonisolated struct TransitDatasetChanges: Equatable, Sendable {
    static let maxHighlights = 20
    static let maxLabelLength = 60
    static let maxSummaryLength = 400

    var delta = TransitChangeDelta()
    var highlights: [TransitChangeHighlight] = []
    var summary: [String: String] = [:]

    var isEmpty: Bool {
        delta.isEmpty && highlights.isEmpty
    }

    func localizedSummary(for languageCode: String) -> String? {
        summary[languageCode] ?? summary["en"]
    }
}

nonisolated extension TransitChangeHighlight: Decodable {
    private enum CodingKeys: String, CodingKey {
        case kind, label, detail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(TransitChangeHighlightKind.self, forKey: .kind)
        label = try container.decode(String.self, forKey: .label)
            .sanitizedForDisplay(limit: TransitDatasetChanges.maxLabelLength)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)?
            .sanitizedForDisplay(limit: TransitDatasetChanges.maxLabelLength)
    }
}

nonisolated extension TransitDatasetChanges: Decodable {
    private enum CodingKeys: String, CodingKey {
        case delta, highlights, summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        delta = try container.decodeIfPresent(TransitChangeDelta.self, forKey: .delta) ?? TransitChangeDelta()

        let rawHighlights = try container.decodeIfPresent(
            [FailableDecodable<TransitChangeHighlight>].self, forKey: .highlights
        ) ?? []
        highlights = Array(rawHighlights.compactMap(\.value).prefix(TransitDatasetChanges.maxHighlights))

        let rawSummary = try container.decodeIfPresent([String: String].self, forKey: .summary) ?? [:]
        summary = rawSummary.compactMapValues {
            let cleaned = $0.sanitizedForDisplay(limit: TransitDatasetChanges.maxSummaryLength)
            return cleaned.isEmpty ? nil : cleaned
        }
    }
}

nonisolated struct TransitDatasetEntry: Decodable, Equatable, Sendable {
    let schemaVersion: Int
    let dataVersion: Int
    let generatedAt: String
    let url: URL
    let byteSize: Int64
    let sha256: String
    let minimumAppBuild: Int?
    let counts: TransitStoreCounts?
    let changes: TransitDatasetChanges

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, dataVersion, generatedAt, url, byteSize, sha256
        case minimumAppBuild, counts, changes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        dataVersion = try container.decode(Int.self, forKey: .dataVersion)
        generatedAt = try container.decode(String.self, forKey: .generatedAt)
        url = try container.decode(URL.self, forKey: .url)
        byteSize = try container.decode(Int64.self, forKey: .byteSize)
        sha256 = try container.decode(String.self, forKey: .sha256).lowercased()
        minimumAppBuild = try container.decodeIfPresent(Int.self, forKey: .minimumAppBuild)
        counts = try container.decodeIfPresent(TransitStoreCounts.self, forKey: .counts)
        changes = try container.decodeIfPresent(TransitDatasetChanges.self, forKey: .changes)
            ?? TransitDatasetChanges()

        guard url.scheme?.lowercased() == "https" else {
            throw DecodingError.dataCorruptedError(
                forKey: .url, in: container, debugDescription: "Dataset URL must be https"
            )
        }
    }
}

nonisolated struct TransitDatasetManifest: Decodable, Equatable, Sendable {
    static let supportedManifestVersion = 1

    let manifestVersion: Int
    let datasets: [TransitDatasetEntry]

    private enum CodingKeys: String, CodingKey {
        case manifestVersion, datasets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        manifestVersion = try container.decode(Int.self, forKey: .manifestVersion)
        let raw = try container.decodeIfPresent(
            [FailableDecodable<TransitDatasetEntry>].self, forKey: .datasets
        ) ?? []
        datasets = raw.compactMap(\.value)
    }

    var isSupported: Bool {
        manifestVersion <= Self.supportedManifestVersion
    }

    func bestEntry(
        schemaVersion: Int,
        appBuild: Int,
        installedDataVersion: Int,
        rejectedHashes: Set<String>
    ) -> TransitDatasetEntry? {
        guard isSupported else { return nil }
        return datasets
            .filter { $0.schemaVersion == schemaVersion }
            .filter { $0.dataVersion > installedDataVersion }
            .filter { !rejectedHashes.contains($0.sha256) }
            .filter { ($0.minimumAppBuild ?? 0) <= appBuild }
            .max { $0.dataVersion < $1.dataVersion }
    }
}

nonisolated struct FailableDecodable<Wrapped: Decodable>: Decodable {
    let value: Wrapped?

    init(from decoder: Decoder) throws {
        value = try? Wrapped(from: decoder)
    }
}

private nonisolated extension String {
    func sanitizedForDisplay(limit: Int) -> String {
        let stripped = unicodeScalars
            .map { CharacterSet.controlCharacters.contains($0) ? " " : Character($0) }
            .reduce(into: "") { $0.append($1) }
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard stripped.count > limit else { return stripped }
        return String(stripped.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
