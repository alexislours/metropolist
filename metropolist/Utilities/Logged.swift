import os

/// Shared logger for non-critical operations that fall back to a default value on failure.
let fallbackLogger = Logger(subsystem: "com.alexislours.metropolist", category: "fallback")

/// Executes a throwing closure and returns its result on success, or logs the error and returns `nil`.
func logged<T>(_ context: String = #function, _ body: () throws -> T) -> T? {
    do {
        return try body()
    } catch {
        fallbackLogger.error("\(context, privacy: .public): \(String(describing: error), privacy: .public)")
        return nil
    }
}
