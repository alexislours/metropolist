#!/usr/bin/env swift
import CryptoKit
import Foundation

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("usage: transit-sign.swift <file>\n".utf8))
    exit(2)
}

guard let encodedKey = ProcessInfo.processInfo.environment["TRANSIT_SIGNING_KEY"],
      let rawKey = Data(base64Encoded: encodedKey.trimmingCharacters(in: .whitespacesAndNewlines)),
      let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: rawKey)
else {
    FileHandle.standardError.write(Data("TRANSIT_SIGNING_KEY missing or invalid\n".utf8))
    exit(3)
}

let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let payload = try? Data(contentsOf: url),
      let signature = try? key.signature(for: payload)
else {
    FileHandle.standardError.write(Data("could not sign \(url.path)\n".utf8))
    exit(4)
}

print(signature.base64EncodedString())
