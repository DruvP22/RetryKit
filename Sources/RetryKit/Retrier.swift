import Foundation

/// Runs an async operation, retrying with backoff on failure.
///
/// Usage:
/// ```swift
/// let retrier = Retrier(policy: RetryPolicy(maxAttempts: 4, strategy: .exponential(baseSeconds: 0.5)))
/// let data = try await retrier.run {
///     try await fetchFromFlakyAPI()
/// }
/// ```
public struct Retrier: Sendable {
    private let policy: RetryPolicy
    private let sleeper: Sleeper

    public init(policy: RetryPolicy = RetryPolicy(), sleeper: Sleeper = SystemSleeper()) {
        self.policy = policy
        self.sleeper = sleeper
    }

    /// Runs `operation`, retrying with backoff if it throws.
    ///
    /// - Parameter shouldRetry: Decides which errors are worth retrying.
    ///   Defaults to retrying everything. In a real networking layer
    ///   you'd probably return `false` for something like a 400 Bad
    ///   Request (trying again won't fix it) and `true` for a timeout
    ///   or a 503.
    /// - Parameter operation: The work to run.
    /// - Returns: Whatever `operation` returns, once it succeeds.
    /// - Throws: The error from the last failed attempt.
    public func run<T>(
        shouldRetry: @escaping (Error) -> Bool = { _ in true },
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var attempt = 1

        while true {
            do {
                return try await operation()
            } catch {
                let isLastAttempt = attempt >= policy.maxAttempts
                if isLastAttempt || !shouldRetry(error) {
                    throw error
                }

                let delay = policy.delaySeconds(forAttempt: attempt)
                try await sleeper.sleep(seconds: delay)
                attempt += 1
            }
        }
    }
}
