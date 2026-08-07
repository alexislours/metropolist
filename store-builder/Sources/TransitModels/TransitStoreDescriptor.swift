import Foundation

public struct TransitStoreCounts: Codable, Equatable, Sendable {
    public var lines: Int
    public var stations: Int
    public var routeVariants: Int
    public var lineStops: Int
    public var transfers: Int

    public init(lines: Int, stations: Int, routeVariants: Int, lineStops: Int, transfers: Int) {
        self.lines = lines
        self.stations = stations
        self.routeVariants = routeVariants
        self.lineStops = lineStops
        self.transfers = transfers
    }
}

public struct TransitStoreInfo: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var dataVersion: Int
    public var generatedAt: String
    public var sha256: String
    public var byteSize: Int64
    public var counts: TransitStoreCounts
    public var modelHash: String

    public init(
        schemaVersion: Int,
        dataVersion: Int,
        generatedAt: String,
        sha256: String,
        byteSize: Int64,
        counts: TransitStoreCounts,
        modelHash: String
    ) {
        self.schemaVersion = schemaVersion
        self.dataVersion = dataVersion
        self.generatedAt = generatedAt
        self.sha256 = sha256
        self.byteSize = byteSize
        self.counts = counts
        self.modelHash = modelHash
    }
}

public struct TransitStoreDescriptor: Codable, Equatable, Sendable {
    public enum Source: String, Codable, Sendable {
        case bundle
        case remote
    }

    public var source: Source
    public var schemaVersion: Int
    public var dataVersion: Int
    public var generatedAt: String
    public var sha256: String
    public var byteSize: Int64
    public var installedAt: Date

    public init(
        source: Source,
        schemaVersion: Int,
        dataVersion: Int,
        generatedAt: String,
        sha256: String,
        byteSize: Int64,
        installedAt: Date
    ) {
        self.source = source
        self.schemaVersion = schemaVersion
        self.dataVersion = dataVersion
        self.generatedAt = generatedAt
        self.sha256 = sha256
        self.byteSize = byteSize
        self.installedAt = installedAt
    }

    public init(info: TransitStoreInfo, source: Source, installedAt: Date) {
        self.init(
            source: source,
            schemaVersion: info.schemaVersion,
            dataVersion: info.dataVersion,
            generatedAt: info.generatedAt,
            sha256: info.sha256,
            byteSize: info.byteSize,
            installedAt: installedAt
        )
    }

    public var cacheIdentity: String {
        "\(source.rawValue)-\(schemaVersion)-\(dataVersion)-\(sha256.prefix(16))"
    }
}
