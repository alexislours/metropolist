#!/usr/bin/env swift
import CryptoKit
import Foundation

let key = Curve25519.Signing.PrivateKey()

print("Public key  — paste into TransitManifestVerifier.publicKeysBase64:")
print(key.publicKey.rawRepresentation.base64EncodedString())
print("")
print("Private key — store as the TRANSIT_SIGNING_KEY GitHub Actions secret:")
print(key.rawRepresentation.base64EncodedString())
print("")
print("Do not commit the private key.")
