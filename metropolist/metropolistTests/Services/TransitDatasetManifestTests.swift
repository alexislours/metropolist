import Foundation
@testable import metropolist
import Testing

@Suite("Transit dataset manifest", .tags(.transitUpdate))
struct TransitDatasetManifestTests {
    private static func decode(_ json: String) throws -> TransitDatasetManifest {
        try JSONDecoder().decode(TransitDatasetManifest.self, from: Data(json.utf8))
    }

    private static func entryJSON(
        schemaVersion: Int = 1,
        dataVersion: Int = 2026080703,
        sha256: String = "abc",
        minimumAppBuild: Int? = nil
    ) -> String {
        let minBuild = minimumAppBuild.map { "\"minimumAppBuild\": \($0)," } ?? ""
        return """
        {
          "schemaVersion": \(schemaVersion),
          "dataVersion": \(dataVersion),
          "generatedAt": "2026-08-07T03:12:44.921Z",
          "url": "https://example.com/transit.store",
          "byteSize": 9191424,
          \(minBuild)
          "sha256": "\(sha256)"
        }
        """
    }

    private static func manifestJSON(_ entries: [String], version: Int = 1) -> String {
        """
        { "manifestVersion": \(version), "datasets": [\(entries.joined(separator: ","))] }
        """
    }

    @Test("Picks the highest dataVersion for the current schema")
    func picksNewest() throws {
        let manifest = try Self.decode(Self.manifestJSON([
            Self.entryJSON(dataVersion: 100, sha256: "old"),
            Self.entryJSON(dataVersion: 300, sha256: "new"),
            Self.entryJSON(dataVersion: 200, sha256: "mid"),
        ]))
        let entry = manifest.bestEntry(
            schemaVersion: 1, appBuild: 2026051801, installedDataVersion: 0, rejectedHashes: []
        )
        #expect(entry?.dataVersion == 300)
    }

    @Test("Ignores entries built for another schema")
    func filtersSchema() throws {
        let manifest = try Self.decode(Self.manifestJSON([
            Self.entryJSON(schemaVersion: 2, dataVersion: 900),
            Self.entryJSON(schemaVersion: 1, dataVersion: 100),
        ]))
        let entry = manifest.bestEntry(
            schemaVersion: 1, appBuild: 2026051801, installedDataVersion: 0, rejectedHashes: []
        )
        #expect(entry?.dataVersion == 100)
    }

    @Test("Ignores datasets that require a newer app build")
    func filtersMinimumAppBuild() throws {
        let manifest = try Self.decode(Self.manifestJSON([
            Self.entryJSON(dataVersion: 300, minimumAppBuild: 2030010101),
        ]))
        let entry = manifest.bestEntry(
            schemaVersion: 1, appBuild: 2026051801, installedDataVersion: 0, rejectedHashes: []
        )
        #expect(entry == nil)
    }

    @Test("Ignores datasets already installed")
    func filtersInstalled() throws {
        let manifest = try Self.decode(Self.manifestJSON([Self.entryJSON(dataVersion: 300)]))
        let entry = manifest.bestEntry(
            schemaVersion: 1, appBuild: 2026051801, installedDataVersion: 300, rejectedHashes: []
        )
        #expect(entry == nil)
    }

    @Test("Ignores datasets on the rejected list")
    func filtersRejected() throws {
        let manifest = try Self.decode(Self.manifestJSON([Self.entryJSON(dataVersion: 300, sha256: "bad")]))
        let entry = manifest.bestEntry(
            schemaVersion: 1, appBuild: 2026051801, installedDataVersion: 0, rejectedHashes: ["bad"]
        )
        #expect(entry == nil)
    }

    @Test("A newer manifest version is ignored rather than misparsed")
    func rejectsNewerManifestVersion() throws {
        let manifest = try Self.decode(Self.manifestJSON([Self.entryJSON()], version: 99))
        #expect(!manifest.isSupported)
        #expect(manifest.bestEntry(
            schemaVersion: 1, appBuild: 2026051801, installedDataVersion: 0, rejectedHashes: []
        ) == nil)
    }

    @Test("One malformed entry does not discard the whole manifest")
    func tolerantDecoding() throws {
        let manifest = try Self.decode("""
        {
          "manifestVersion": 1,
          "unknownTopLevelKey": true,
          "datasets": [
            { "schemaVersion": 1, "dataVersion": "not a number" },
            \(Self.entryJSON(dataVersion: 400))
          ]
        }
        """)
        #expect(manifest.datasets.count == 1)
        #expect(manifest.datasets.first?.dataVersion == 400)
    }

    @Test("Non-https dataset URLs are rejected")
    func rejectsInsecureURL() throws {
        let manifest = try Self.decode("""
        {
          "manifestVersion": 1,
          "datasets": [{
            "schemaVersion": 1, "dataVersion": 1, "generatedAt": "g",
            "url": "http://example.com/transit.store", "byteSize": 1, "sha256": "a"
          }]
        }
        """)
        #expect(manifest.datasets.isEmpty)
    }

    @Test("An empty dataset list yields no update")
    func emptyDatasets() throws {
        let manifest = try Self.decode(Self.manifestJSON([]))
        #expect(manifest.bestEntry(
            schemaVersion: 1, appBuild: 2026051801, installedDataVersion: 0, rejectedHashes: []
        ) == nil)
    }
}

@Suite("Transit dataset changes decoding", .tags(.transitUpdate))
struct TransitDatasetChangesTests {
    private static func decodeChanges(_ json: String) throws -> TransitDatasetChanges {
        try JSONDecoder().decode(TransitDatasetChanges.self, from: Data(json.utf8))
    }

    @Test("Highlights are capped")
    func capsHighlights() throws {
        let many = (0 ..< 50)
            .map { "{\"kind\":\"stationAdded\",\"label\":\"S\($0)\"}" }
            .joined(separator: ",")
        let changes = try Self.decodeChanges("{\"highlights\":[\(many)]}")
        #expect(changes.highlights.count == TransitDatasetChanges.maxHighlights)
    }

    @Test("Over-long labels are clamped")
    func clampsLabels() throws {
        let long = String(repeating: "x", count: 300)
        let changes = try Self.decodeChanges(
            "{\"highlights\":[{\"kind\":\"lineAdded\",\"label\":\"\(long)\"}]}"
        )
        #expect(changes.highlights.first!.label.count <= TransitDatasetChanges.maxLabelLength)
    }

    @Test("An unknown highlight kind is dropped without failing the entry")
    func dropsUnknownKind() throws {
        let changes = try Self.decodeChanges("""
        {"highlights":[
          {"kind":"somethingNew","label":"A"},
          {"kind":"lineAdded","label":"B"}
        ]}
        """)
        #expect(changes.highlights.count == 1)
        #expect(changes.highlights.first?.label == "B")
    }

    @Test("Absent changes decode to an empty, usable value")
    func absentChanges() throws {
        let changes = try Self.decodeChanges("{}")
        #expect(changes.isEmpty)
        #expect(changes.delta.isEmpty)
        #expect(changes.localizedSummary(for: "fr") == nil)
    }

    @Test("Summary falls back to English for an unknown language")
    func summaryFallback() throws {
        let changes = try Self.decodeChanges("{\"summary\":{\"en\":\"Two stops added\"}}")
        #expect(changes.localizedSummary(for: "de") == "Two stops added")
    }

    @Test("Control characters are stripped from server text")
    func stripsControlCharacters() throws {
        let changes = try Self.decodeChanges(
            "{\"highlights\":[{\"kind\":\"lineAdded\",\"label\":\"A\\u0007B\"}]}"
        )
        #expect(changes.highlights.first?.label == "A B")
    }
}

@Suite("Transit manifest signature", .tags(.transitUpdate))
struct TransitManifestVerifierTests {
    @Test("A production public key is compiled in")
    func hasPublicKey() {
        #expect(!TransitManifestVerifier.publicKeysBase64.isEmpty)
    }

    @Test("A bogus signature is rejected")
    func rejectsBogusSignature() {
        let payload = Data("{\"manifestVersion\":1}".utf8)
        #expect(!TransitManifestVerifier.verify(manifest: payload, signature: Data(repeating: 0, count: 64)))
    }
}

@Suite("Transit update prompt gating", .tags(.transitUpdate))
struct TransitUpdatePromptTests {
    private static let entry = try! JSONDecoder().decode(
        TransitDatasetEntry.self,
        from: Data("""
        {
          "schemaVersion": 1, "dataVersion": 500, "generatedAt": "g",
          "url": "https://example.com/t.store", "byteSize": 1, "sha256": "a"
        }
        """.utf8)
    )

    @Test("Prompts when an update is available")
    func promptsWhenAvailable() {
        #expect(TransitUpdateModel.shouldPresentPrompt(
            state: .available(Self.entry), policy: .wifi, deferredVersion: 0, isFirstLaunch: false
        ))
    }

    @Test("Never prompts when automatic updates are off")
    func silentWhenOff() {
        #expect(!TransitUpdateModel.shouldPresentPrompt(
            state: .available(Self.entry), policy: .off, deferredVersion: 0, isFirstLaunch: false
        ))
    }

    @Test("Never prompts on first launch")
    func silentOnFirstLaunch() {
        #expect(!TransitUpdateModel.shouldPresentPrompt(
            state: .available(Self.entry), policy: .wifi, deferredVersion: 0, isFirstLaunch: true
        ))
    }

    @Test("A deferred dataset does not prompt again")
    func silentWhenDeferred() {
        #expect(!TransitUpdateModel.shouldPresentPrompt(
            state: .available(Self.entry), policy: .wifi, deferredVersion: 500, isFirstLaunch: false
        ))
    }

    @Test("A different dataset prompts even after an earlier deferral")
    func promptsForNewerAfterDeferral() {
        #expect(TransitUpdateModel.shouldPresentPrompt(
            state: .available(Self.entry), policy: .always, deferredVersion: 499, isFirstLaunch: false
        ))
    }

    @Test("Does not prompt outside the available state")
    func silentWhenNotAvailable() {
        #expect(!TransitUpdateModel.shouldPresentPrompt(
            state: .checking, policy: .wifi, deferredVersion: 0, isFirstLaunch: false
        ))
        #expect(!TransitUpdateModel.shouldPresentPrompt(
            state: .upToDate(checkedAt: Date()), policy: .wifi, deferredVersion: 0, isFirstLaunch: false
        ))
    }
}
