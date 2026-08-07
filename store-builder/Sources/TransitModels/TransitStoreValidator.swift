import CryptoKit
import Foundation
import SQLite3

public enum TransitStoreValidator {
    public struct Expectation: Equatable, Sendable {
        public var schemaVersion: Int
        public var dataVersion: Int?
        public var generatedAt: String?
        public var counts: TransitStoreCounts?

        public init(
            schemaVersion: Int,
            dataVersion: Int? = nil,
            generatedAt: String? = nil,
            counts: TransitStoreCounts? = nil
        ) {
            self.schemaVersion = schemaVersion
            self.dataVersion = dataVersion
            self.generatedAt = generatedAt
            self.counts = counts
        }
    }

    public struct Contents: Equatable, Sendable {
        public var schemaVersion: Int
        public var dataVersion: Int
        public var generatedAt: String
        public var counts: TransitStoreCounts
    }

    public enum ValidationError: Error, Equatable, Sendable {
        case cannotOpen(String)
        case integrityCheckFailed(String)
        case missingTable(String)
        case missingMetadata(String)
        case malformedMetadata(key: String, value: String)
        case schemaVersionMismatch(found: Int, expected: Int)
        case dataVersionMismatch(found: Int, expected: Int)
        case generatedAtMismatch(found: String, expected: String)
        case countMismatch(table: String, found: Int, expected: Int)
        case emptyTable(String)
        // periphery:ignore - Used by StoreBuilder target
        case modelHashUnavailable
    }

    // MARK: - Public API

    @discardableResult
    public static func validate(storeAt url: URL, expecting expectation: Expectation) throws -> Contents {
        let db = try open(url)
        defer { sqlite3_close(db) }

        try runIntegrityCheck(db)
        try assertTablesExist(db)

        let contents = try readContents(db)
        try assertMatches(contents, expectation)
        return contents
    }

    // periphery:ignore - Used by StoreBuilder target
    public static func readContents(storeAt url: URL) throws -> Contents {
        let db = try open(url)
        defer { sqlite3_close(db) }
        return try readContents(db)
    }

    // periphery:ignore - Used by StoreBuilder target
    public static func modelHash(storeAt url: URL) throws -> String {
        let db = try open(url)
        defer { sqlite3_close(db) }

        guard let plist = try queryBlob(db, "SELECT Z_PLIST FROM Z_METADATA LIMIT 1") else {
            throw ValidationError.modelHashUnavailable
        }
        let object = try PropertyListSerialization.propertyList(from: plist, format: nil)
        guard let root = object as? [String: Any],
              let hashes = root["NSStoreModelVersionHashes"] as? [String: Any]
        else {
            throw ValidationError.modelHashUnavailable
        }

        var hasher = SHA256()
        for name in hashes.keys.sorted() {
            hasher.update(data: Data(name.utf8))
            if let value = hashes[name] as? Data {
                hasher.update(data: value)
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Opening

    private static func open(_ url: URL) throws -> OpaquePointer {
        let uri = url.absoluteString + "?immutable=1"
        var handle: OpaquePointer?
        let status = sqlite3_open_v2(uri, &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil)
        guard status == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "status \(status)"
            sqlite3_close(handle)
            throw ValidationError.cannotOpen(message)
        }
        return handle
    }

    // MARK: - Checks

    private static func runIntegrityCheck(_ db: OpaquePointer) throws {
        let result = try queryString(db, "PRAGMA quick_check") ?? "no result"
        guard result == "ok" else {
            throw ValidationError.integrityCheckFailed(result)
        }
    }

    private static func assertTablesExist(_ db: OpaquePointer) throws {
        for table in TransitSchema.tableNames {
            let sql = "SELECT name FROM sqlite_master WHERE type='table' AND name='\(table)' LIMIT 1"
            guard try queryString(db, sql) != nil else {
                throw ValidationError.missingTable(table)
            }
        }
    }

    private static func readContents(_ db: OpaquePointer) throws -> Contents {
        let metadata = try readMetadata(db)

        let schemaVersion = try intMetadata(metadata, key: TransitSchema.MetadataKey.schemaVersion)
        let dataVersion = try intMetadata(metadata, key: TransitSchema.MetadataKey.dataVersion)
        guard let generatedAt = metadata[TransitSchema.MetadataKey.generatedAt] else {
            throw ValidationError.missingMetadata(TransitSchema.MetadataKey.generatedAt)
        }

        let counts = TransitStoreCounts(
            lines: try count(db, "ZTRANSITLINE"),
            stations: try count(db, "ZTRANSITSTATION"),
            routeVariants: try count(db, "ZTRANSITROUTEVARIANT"),
            lineStops: try count(db, "ZTRANSITLINESTOP"),
            transfers: try count(db, "ZTRANSITTRANSFER")
        )

        return Contents(
            schemaVersion: schemaVersion,
            dataVersion: dataVersion,
            generatedAt: generatedAt,
            counts: counts
        )
    }

    private static func assertMatches(_ contents: Contents, _ expectation: Expectation) throws {
        guard contents.schemaVersion == expectation.schemaVersion else {
            throw ValidationError.schemaVersionMismatch(
                found: contents.schemaVersion, expected: expectation.schemaVersion
            )
        }
        if let expected = expectation.dataVersion, contents.dataVersion != expected {
            throw ValidationError.dataVersionMismatch(found: contents.dataVersion, expected: expected)
        }
        if let expected = expectation.generatedAt, contents.generatedAt != expected {
            throw ValidationError.generatedAtMismatch(found: contents.generatedAt, expected: expected)
        }

        let found = contents.counts
        for (table, value) in [
            ("ZTRANSITLINE", found.lines), ("ZTRANSITSTATION", found.stations),
            ("ZTRANSITROUTEVARIANT", found.routeVariants), ("ZTRANSITLINESTOP", found.lineStops),
        ] where value == 0 {
            throw ValidationError.emptyTable(table)
        }

        guard let expected = expectation.counts else { return }
        for (table, foundValue, expectedValue) in [
            ("ZTRANSITLINE", found.lines, expected.lines),
            ("ZTRANSITSTATION", found.stations, expected.stations),
            ("ZTRANSITROUTEVARIANT", found.routeVariants, expected.routeVariants),
            ("ZTRANSITLINESTOP", found.lineStops, expected.lineStops),
            ("ZTRANSITTRANSFER", found.transfers, expected.transfers),
        ] where foundValue != expectedValue {
            throw ValidationError.countMismatch(table: table, found: foundValue, expected: expectedValue)
        }
    }

    // MARK: - Metadata helpers

    private static func readMetadata(_ db: OpaquePointer) throws -> [String: String] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT ZKEY, ZVALUE FROM ZTRANSITMETADATA", -1, &statement, nil) == SQLITE_OK else {
            throw ValidationError.missingTable("ZTRANSITMETADATA")
        }
        defer { sqlite3_finalize(statement) }

        var result: [String: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let key = sqlite3_column_text(statement, 0),
                  let value = sqlite3_column_text(statement, 1)
            else { continue }
            result[String(cString: key)] = String(cString: value)
        }
        return result
    }

    private static func intMetadata(_ metadata: [String: String], key: String) throws -> Int {
        guard let raw = metadata[key] else {
            throw ValidationError.missingMetadata(key)
        }
        guard let value = Int(raw) else {
            throw ValidationError.malformedMetadata(key: key, value: raw)
        }
        return value
    }

    // MARK: - SQLite helpers

    private static func count(_ db: OpaquePointer, _ table: String) throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM \(table)", -1, &statement, nil) == SQLITE_OK else {
            throw ValidationError.missingTable(table)
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw ValidationError.missingTable(table)
        }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private static func queryString(_ db: OpaquePointer, _ sql: String) throws -> String? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ValidationError.cannotOpen(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW, let text = sqlite3_column_text(statement, 0) else {
            return nil
        }
        return String(cString: text)
    }

    // periphery:ignore - Used by StoreBuilder target
    private static func queryBlob(_ db: OpaquePointer, _ sql: String) throws -> Data? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ValidationError.cannotOpen(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW, let bytes = sqlite3_column_blob(statement, 0) else {
            return nil
        }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
    }
}
