# RetryKit

RetryKit is a small Swift package for retrying failed async operations, such as network calls and API requests. It supports constant, linear, and exponential backoff strategies and allows retry logic to be tested without waiting for real delays.

## Why I Built This

Many apps need to retry requests when a server is temporarily unavailable or a request times out. RetryKit provides a reusable way to handle this without giving up immediately or sending too many requests. It can also be added to the networking layer of apps to retry failed stock quote requests.

## Installation

Add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/YOUR_USERNAME/RetryKit.git", from: "1.0.0")
]
```

## Usage

```swift
import RetryKit

let retrier = Retrier(
    policy: RetryPolicy(
        maxAttempts: 4,
        strategy: .exponential(baseSeconds: 0.5, multiplier: 2.0),
        jitterFraction: 0.2,
        maxDelaySeconds: 10.0
    )
)

let data = try await retrier.run(
    shouldRetry: { error in
        guard let apiError = error as? APIError else { return true }

        switch apiError {
        case .rateLimited, .unknown:
            return true
        case .invalidURL, .decodingFailed:
            return false
        default:
            return true
        }
    }
) {
    try await fetchFromFlakyAPI()
}
```

## What the Tests Cover

There are 11 tests across two files.

### `RetryPolicyTests.swift` — 6 Tests

Tests the retry delay calculations:

* Constant backoff stays the same.
* Linear backoff increases by a fixed amount.
* Exponential backoff doubles the delay.
* Maximum delay limits large delays.
* Jitter stays within the expected range.
* Invalid max attempts are set to at least 1.

### `RetrierTests.swift` — 5 Tests

Tests the actual retry behavior:

* Succeeds without retrying when the first attempt works.
* Retries until the operation succeeds.
* Throws the last error when all attempts fail.
* Stops immediately when an error should not be retried.
* Uses the correct delays from the retry policy.

Tests use a `FakeSleeper` so they can test retry delays without actually waiting.

## Running the Tests

```bash
swift test
```

The package works on Windows, macOS, and Linux because it does not use platform-specific features.

## What I'd Add Next

* A token-bucket rate limiter
* Logging hooks for retry attempts
* A tagged release for the Swift Package Index
