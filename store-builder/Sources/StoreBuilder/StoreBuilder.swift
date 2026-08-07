import CryptoKit
import Foundation
import SQLite3
import SwiftData
import TransitModels

enum StoreBuilderError: LocalizedError {
    case missingInput(String)
    case sqlite(String)
    var errorDescription: String? {
        switch self {
        case .missingInput(let path):
            return "Input file not found at '\(path)'. Run data-builder first."
        case .sqlite(let msg):
            return msg
        }
    }
}

@main
struct StoreBuilder {
    static func main() async throws {
        let jsonPath = CommandLine.arguments.count > 1
            ? CommandLine.arguments[1]
            : "../data-builder/metropolist-data.json"
        let outputPath = CommandLine.arguments.count > 2
            ? CommandLine.arguments[2]
            : "./transit.store"

        print("Reading \(jsonPath)...")
        let jsonURL = URL(fileURLWithPath: jsonPath)
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            throw StoreBuilderError.missingInput(jsonPath)
        }
        let jsonData = try Data(contentsOf: jsonURL)
        print("  \(String(format: "%.1f", Double(jsonData.count) / 1_048_576)) MB read")

        print("Decoding...")
        let metro = try JSONDecoder().decode(MetropolistDataDTO.self, from: jsonData)
        print("  \(metro.lines.count) lines, \(metro.stations.count) stations, \(metro.lineStops.count) line stops")

        let outputURL = URL(fileURLWithPath: outputPath)

        print("\nBuilding store...")
        let startTime = ContinuousClock.now

        try autoreleasepool {
            let schema = Schema(TransitSchema.models)
            let config = ModelConfiguration(schema: schema, url: outputURL)
            let container = try ModelContainer(for: schema, configurations: config)
            let context = ModelContext(container)
            context.autosaveEnabled = false

            try context.delete(model: TransitLineStop.self)
            try context.delete(model: TransitTransfer.self)
            try context.delete(model: TransitRouteVariant.self)
            try context.delete(model: TransitStation.self)
            try context.delete(model: TransitLine.self)
            try context.delete(model: TransitMetadata.self)
            try context.save()
            print("  Cleared existing data")

            print("  Lines...")
            for dto in metro.lines {
                context.insert(TransitLine(
                    sourceID: dto.id, shortName: dto.shortName, longName: dto.longName,
                    mode: dto.mode, submode: dto.submode, color: dto.color,
                    textColor: dto.textColor, operatorName: dto.operatorName,
                    networkName: dto.networkName, status: dto.status,
                    isAccessible: dto.isAccessible, groupID: dto.groupId,
                    groupName: dto.groupName
                ))
            }
            try context.save()

            print("  Stations...")
            for dto in metro.stations {
                context.insert(TransitStation(
                    sourceID: dto.id, name: dto.name,
                    latitude: dto.latitude, longitude: dto.longitude,
                    fareZone: dto.fareZone, town: dto.town, postalCode: dto.postalCode,
                    isAccessible: dto.isAccessible,
                    hasAudibleSignals: dto.hasAudibleSignals,
                    hasVisualSigns: dto.hasVisualSigns
                ))
            }
            try context.save()

            print("  Route variants...")
            for dto in metro.routeVariants {
                context.insert(TransitRouteVariant(
                    sourceID: dto.id, lineSourceID: dto.lineId,
                    direction: dto.direction, headsign: dto.headsign,
                    stationCount: dto.stationCount
                ))
            }
            try context.save()

            print("  Line stops...")
            for (i, dto) in metro.lineStops.enumerated() {
                context.insert(TransitLineStop(
                    lineSourceID: dto.lineId, stationSourceID: dto.stationId,
                    routeVariantSourceID: dto.routeVariantId,
                    order: dto.order, isTerminus: dto.isTerminus
                ))
                if (i + 1) % 10_000 == 0 {
                    try context.save()
                    print("    \(i + 1) / \(metro.lineStops.count)")
                }
            }
            try context.save()

            print("  Transfers...")
            for dto in metro.transfers {
                context.insert(TransitTransfer(
                    fromStationSourceID: dto.fromStationId,
                    toStationSourceID: dto.toStationId,
                    minTransferTime: dto.minTransferTime
                ))
            }
            try context.save()

            print("  Metadata...")
            context.insert(TransitMetadata(
                key: TransitSchema.MetadataKey.generatedAt, value: metro.generatedAt
            ))
            context.insert(TransitMetadata(
                key: TransitSchema.MetadataKey.dataVersion, value: String(metro.dataVersion)
            ))
            context.insert(TransitMetadata(
                key: TransitSchema.MetadataKey.schemaVersion, value: String(TransitSchema.version)
            ))
            try context.save()

        }
        
        var dbHandle: OpaquePointer?
        guard sqlite3_open(outputURL.path, &dbHandle) == SQLITE_OK else {
            let err = dbHandle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(dbHandle)
            throw StoreBuilderError.sqlite("Failed to open database: \(err)")
        }
        sqlite3_busy_timeout(dbHandle, 10_000)
        for table in ["ACHANGE", "ATRANSACTION", "ATRANSACTIONSTRING"] {
            guard sqlite3_exec(dbHandle, "DELETE FROM \(table)", nil, nil, nil) == SQLITE_OK else {
                let err = String(cString: sqlite3_errmsg(dbHandle))
                sqlite3_close(dbHandle)
                throw StoreBuilderError.sqlite("DELETE FROM \(table) failed: \(err)")
            }
        }
        guard sqlite3_exec(dbHandle, "PRAGMA wal_checkpoint(TRUNCATE)", nil, nil, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(dbHandle))
            sqlite3_close(dbHandle)
            throw StoreBuilderError.sqlite("WAL checkpoint failed: \(err)")
        }
        guard sqlite3_exec(dbHandle, "VACUUM", nil, nil, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(dbHandle))
            sqlite3_close(dbHandle)
            throw StoreBuilderError.sqlite("VACUUM failed: \(err)")
        }
        sqlite3_close(dbHandle)
        print("  Purged persistent history tables")

        var removedFiles: [String] = []
        for suffix in ["-shm", "-wal"] {
            let path = outputPath + suffix
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
                removedFiles.append(suffix)
            }
        }
        if !removedFiles.isEmpty {
            print("  Cleaned up leftover \(removedFiles.joined(separator: ", ")) files")
        }

        let elapsed = ContinuousClock.now - startTime
        let attrs = try FileManager.default.attributesOfItem(atPath: outputPath)
        let size = (attrs[.size] as? Int64 ?? 0)

        let infoURL = try writeStoreInfo(storeURL: outputURL, metro: metro, byteSize: size)
        print("  Wrote \(infoURL.lastPathComponent)")

        print("\nDone! \(outputPath) (\(String(format: "%.1f", Double(size) / 1_048_576)) MB) in \(elapsed)")
    }

    private static func writeStoreInfo(
        storeURL: URL, metro: MetropolistDataDTO, byteSize: Int64
    ) throws -> URL {
        let digest = SHA256.hash(data: try Data(contentsOf: storeURL))
        let info = TransitStoreInfo(
            schemaVersion: TransitSchema.version,
            dataVersion: metro.dataVersion,
            generatedAt: metro.generatedAt,
            sha256: digest.map { String(format: "%02x", $0) }.joined(),
            byteSize: byteSize,
            counts: TransitStoreCounts(
                lines: metro.lines.count,
                stations: metro.stations.count,
                routeVariants: metro.routeVariants.count,
                lineStops: metro.lineStops.count,
                transfers: metro.transfers.count
            ),
            modelHash: try TransitStoreValidator.modelHash(storeAt: storeURL)
        )

        try TransitStoreValidator.validate(
            storeAt: storeURL,
            expecting: TransitStoreValidator.Expectation(
                schemaVersion: TransitSchema.version,
                dataVersion: metro.dataVersion,
                generatedAt: metro.generatedAt,
                counts: info.counts
            )
        )

        let infoURL = storeURL.deletingLastPathComponent().appendingPathComponent("transit-info.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(info).write(to: infoURL, options: .atomic)
        return infoURL
    }
}
