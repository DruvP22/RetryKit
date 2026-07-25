import Foundation

/// How long to wait between attempts, and how that wait changes over time.
public enum BackoffStrategy: Sendable {
    /// Same delay every time.
    case constant(seconds: Double)
    /// Delay grows by a fixed amount each attempt: base, 2*base, 3*base...
    case linear(baseSeconds: Double)
    /// Delay doubles (or multiplies by whatever you pick) each attempt:
    /// base, base*m, base*m^2... This is the usual choice for network
    /// retries since it backs off fast enough to give a struggling server
    /// some breathing room.
    case exponential(baseSeconds: Double, multiplier: Double = 2.0)
}

/// Holds the rules for retrying: how many attempts, how the delay grows,
/// and any limits on that delay. This is kept separate from Retrier so the
/// delay math can be tested on its own, without any async code involved.
public struct RetryPolicy: Sendable {
    public let maxAttempts: Int
    public let strategy: BackoffStrategy
    /// How much randomness to add to each delay, e.g. 0.2 means +/-20%.
    /// This keeps a bunch of clients that failed at the same time from all
    /// retrying at the exact same moment again.
    public let jitterFraction: Double
    /// Caps the delay so exponential backoff doesn't grow forever.
    public let maxDelaySeconds: Double?

    public init(
        maxAttempts: Int = 3,
        strategy: BackoffStrategy = .exponential(baseSeconds: 1.0),
        jitterFraction: Double = 0.0,
        maxDelaySeconds: Double? = nil
    ) {
        self.maxAttempts = max(1, maxAttempts)
        self.strategy = strategy
        self.jitterFraction = min(max(jitterFraction, 0), 1)
        self.maxDelaySeconds = maxDelaySeconds
    }

    /// The delay to wait before the given attempt. Attempt numbers start
    /// at 1, so attempt 1 is the wait before the first retry (i.e. after
    /// the original try already failed).
    public func delaySeconds(forAttempt attempt: Int) -> Double {
        let base: Double
        switch strategy {
        case .constant(let seconds):
            base = seconds
        case .linear(let baseSeconds):
            base = baseSeconds * Double(attempt)
        case .exponential(let baseSeconds, let multiplier):
            base = baseSeconds * pow(multiplier, Double(attempt - 1))
        }

        let capped = maxDelaySeconds.map { min(base, $0) } ?? base
        guard jitterFraction > 0 else { return capped }

        let jitterRange = capped * jitterFraction
        let jittered = capped + Double.random(in: -jitterRange...jitterRange)
        return max(0, jittered)
    }
}
