import XCTest
@testable import RetryKit

/// Keeps track of every delay it was asked to sleep for, but never
/// actually waits. This is how a test can cover minutes of "real" backoff
/// time in a fraction of a second.
final class FakeSleeper: Sleeper, @unchecked Sendable {
    private(set) var recordedDelays: [Double] = []

    func sleep(seconds: Double) async throws {
        recordedDelays.append(seconds)
    }
}

struct TestError: Error, Equatable {
    let code: Int
}

final class RetrierTests: XCTestCase {

    func testSucceedsOnFirstTryWithoutRetrying() async throws {
        let sleeper = FakeSleeper()
        let retrier = Retrier(policy: RetryPolicy(maxAttempts: 3), sleeper: sleeper)

        let result = try await retrier.run {
            "success"
        }

        XCTAssertEqual(result, "success")
        XCTAssertTrue(sleeper.recordedDelays.isEmpty)
    }

    func testRetriesUntilOperationSucceeds() async throws {
        let sleeper = FakeSleeper()
        let retrier = Retrier(
            policy: RetryPolicy(maxAttempts: 5, strategy: .constant(seconds: 1.0)),
            sleeper: sleeper
        )

        var callCount = 0
        let result = try await retrier.run {
            callCount += 1
            if callCount < 3 {
                throw TestError(code: 500)
            }
            return "recovered"
        }

        XCTAssertEqual(result, "recovered")
        XCTAssertEqual(callCount, 3)
        // It failed twice before succeeding, so it should have slept twice.
        XCTAssertEqual(sleeper.recordedDelays.count, 2)
    }

    func testThrowsLastErrorAfterExhaustingAllAttempts() async {
        let sleeper = FakeSleeper()
        let retrier = Retrier(
            policy: RetryPolicy(maxAttempts: 3, strategy: .constant(seconds: 0.5)),
            sleeper: sleeper
        )

        var callCount = 0

        do {
            _ = try await retrier.run {
                callCount += 1
                throw TestError(code: callCount)
            }
            XCTFail("Expected run(_:) to throw after exhausting attempts")
        } catch let error as TestError {
            // It should surface the error from the last attempt.
            XCTAssertEqual(error, TestError(code: 3))
        } catch {
            XCTFail("Expected TestError, got \(error)")
        }

        XCTAssertEqual(callCount, 3)
        // It sleeps between attempts 1-2 and 2-3, but not after the final failure.
        XCTAssertEqual(sleeper.recordedDelays.count, 2)
    }

    func testShouldRetryFalseStopsImmediatelyWithoutSleeping() async {
        let sleeper = FakeSleeper()
        let retrier = Retrier(
            policy: RetryPolicy(maxAttempts: 5, strategy: .constant(seconds: 1.0)),
            sleeper: sleeper
        )

        var callCount = 0

        do {
            _ = try await retrier.run(shouldRetry: { _ in false }) {
                callCount += 1
                throw TestError(code: 400)
            }
            XCTFail("Expected run(_:) to throw immediately")
        } catch let error as TestError {
            XCTAssertEqual(error, TestError(code: 400))
        } catch {
            XCTFail("Expected TestError, got \(error)")
        }

        // shouldRetry said no, so it gives up after one try.
        XCTAssertEqual(callCount, 1)
        XCTAssertTrue(sleeper.recordedDelays.isEmpty)
    }

    func testDelaysMatchPolicyForExponentialStrategy() async throws {
        let sleeper = FakeSleeper()
        let retrier = Retrier(
            policy: RetryPolicy(maxAttempts: 4, strategy: .exponential(baseSeconds: 1.0, multiplier: 2.0)),
            sleeper: sleeper
        )

        var callCount = 0
        do {
            _ = try await retrier.run {
                callCount += 1
                throw TestError(code: 503)
            }
        } catch {
            // We expect this to throw — we only care about the recorded delays.
        }

        XCTAssertEqual(sleeper.recordedDelays, [1.0, 2.0, 4.0])
    }
}
