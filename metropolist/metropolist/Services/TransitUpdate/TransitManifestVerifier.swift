import CryptoKit
import Foundation

nonisolated enum TransitManifestVerifier {
    static let publicKeysBase64 = [
        "Aesq6MsW3mmc44cYUCm54UpHKWkbfp32kphRynTlNos=",
    ]

    static func verify(manifest: Data, signature: Data) -> Bool {
        let keys = publicKeysBase64.compactMap { encoded -> Curve25519.Signing.PublicKey? in
            guard let raw = Data(base64Encoded: encoded) else { return nil }
            return try? Curve25519.Signing.PublicKey(rawRepresentation: raw)
        }
        guard !keys.isEmpty else { return false }
        return keys.contains { $0.isValidSignature(signature, for: manifest) }
    }
}
