import CryptoKit
import Foundation

nonisolated protocol TransitTransport: Sendable {
    func fetch(_ url: URL, allowExpensive: Bool) async throws -> Data

    func download(
        from url: URL,
        to destination: URL,
        expectedBytes: Int64,
        allowExpensive: Bool,
        onProgress: @Sendable (Int64) -> Void
    ) async throws -> String
}

nonisolated struct URLSessionTransport: TransitTransport {
    private static let chunkSize = 64 * 1024

    private func session(allowExpensive: Bool) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.allowsExpensiveNetworkAccess = allowExpensive
        config.allowsConstrainedNetworkAccess = allowExpensive
        return URLSession(configuration: config)
    }

    func fetch(_ url: URL, allowExpensive: Bool) async throws -> Data {
        do {
            let (data, response) = try await session(allowExpensive: allowExpensive).data(from: url)
            try Self.assertSuccess(response)
            return data
        } catch let error as TransitUpdateFailure {
            throw error
        } catch {
            throw Self.mapped(error)
        }
    }

    func download(
        from url: URL,
        to destination: URL,
        expectedBytes: Int64,
        allowExpensive: Bool,
        onProgress: @Sendable (Int64) -> Void
    ) async throws -> String {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: destination)
        fileManager.createFile(atPath: destination.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: destination) else {
            throw TransitUpdateFailure.insufficientDiskSpace
        }
        defer { try? handle.close() }

        var hasher = SHA256()
        var received: Int64 = 0
        var buffer = Data()
        buffer.reserveCapacity(Self.chunkSize)

        do {
            let (bytes, response) = try await session(allowExpensive: allowExpensive).bytes(from: url)
            try Self.assertSuccess(response)

            for try await byte in bytes {
                buffer.append(byte)
                if buffer.count >= Self.chunkSize {
                    try handle.write(contentsOf: buffer)
                    hasher.update(data: buffer)
                    received += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    onProgress(received)
                }
            }
            if !buffer.isEmpty {
                try handle.write(contentsOf: buffer)
                hasher.update(data: buffer)
                received += Int64(buffer.count)
                onProgress(received)
            }
        } catch let error as TransitUpdateFailure {
            try? fileManager.removeItem(at: destination)
            throw error
        } catch {
            try? fileManager.removeItem(at: destination)
            throw Self.mapped(error)
        }

        guard received == expectedBytes else {
            try? fileManager.removeItem(at: destination)
            throw TransitUpdateFailure.sizeMismatch
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func assertSuccess(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw TransitUpdateFailure.network(status: http.statusCode)
        }
    }

    private static func mapped(_ error: Error) -> TransitUpdateFailure {
        if error is CancellationError {
            return .cancelled
        }
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            return .network(status: nil)
        }
        switch nsError.code {
        case NSURLErrorCancelled:
            return .cancelled
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
             NSURLErrorDataNotAllowed, NSURLErrorCannotConnectToHost:
            return .offline
        default:
            return .network(status: nil)
        }
    }
}
