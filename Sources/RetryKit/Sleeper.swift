import Foundation

/// Represents "wait this long." Retrier calls this instead of Task.sleep
/// directly, so in tests we can swap in a fake version that skips the
/// actual waiting.
public protocol Sleeper: Sendable {
    func sleep(seconds: Double) async throws
}

/// The real version. Used by default outside of tests.
public struct SystemSleeper: Sleeper {
    public init() {}

    public func sleep(seconds: Double) async throws {
        let nanoseconds = UInt64(max(seconds, 0) * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
