import XCTest
@testable import RetryKit

final class RetryPolicyTests: XCTestCase {

    func testConstantBackoffReturnsSameDelayEveryAttempt() {
        let policy = RetryPolicy(strategy: .constant(seconds: 2.0))

        XCTAssertEqual(policy.delaySeconds(forAttempt: 1), 2.0)
        XCTAssertEqual(policy.delaySeconds(forAttempt: 5), 2.0)
    }

    func testLinearBackoffGrowsByFixedIncrement() {
        let policy = RetryPolicy(strategy: .linear(baseSeconds: 1.0))

        XCTAssertEqual(policy.delaySeconds(forAttempt: 1), 1.0)
        XCTAssertEqual(policy.delaySeconds(forAttempt: 2), 2.0)
        XCTAssertEqual(policy.delaySeconds(forAttempt: 3), 3.0)
    }

    func testExponentialBackoffDoublesEachAttempt() {
        let policy = RetryPolicy(strategy: .exponential(baseSeconds: 1.0, multiplier: 2.0))

        XCTAssertEqual(policy.delaySeconds(forAttempt: 1), 1.0)
        XCTAssertEqual(policy.delaySeconds(forAttempt: 2), 2.0)
        XCTAssertEqual(policy.delaySeconds(forAttempt: 3), 4.0)
        XCTAssertEqual(policy.delaySeconds(forAttempt: 4), 8.0)
    }

    func testMaxDelayCapsExponentialGrowth() {
        let policy = RetryPolicy(
            strategy: .exponential(baseSeconds: 1.0, multiplier: 2.0),
            maxDelaySeconds: 5.0
        )

        XCTAssertEqual(policy.delaySeconds(forAttempt: 1), 1.0)
        XCTAssertEqual(policy.delaySeconds(forAttempt: 2), 2.0)
        XCTAssertEqual(policy.delaySeconds(forAttempt: 3), 4.0)
        // Without the cap this would be 8.0.
        XCTAssertEqual(policy.delaySeconds(forAttempt: 4), 5.0)
        // Without the cap this would be 16.0.
        XCTAssertEqual(policy.delaySeconds(forAttempt: 5), 5.0)
    }

    func testJitterStaysWithinExpectedBounds() {
        let policy = RetryPolicy(
            strategy: .constant(seconds: 10.0),
            jitterFraction: 0.2
        )

        // Jitter is random, so check a bunch of samples and make sure
        // every one lands within +/-20% of 10.0, i.e. between 8 and 12.
        for _ in 0..<200 {
            let delay = policy.delaySeconds(forAttempt: 1)
            XCTAssertGreaterThanOrEqual(delay, 8.0)
            XCTAssertLessThanOrEqual(delay, 12.0)
        }
    }

    func testMaxAttemptsIsClampedToAtLeastOne() {
        let policy = RetryPolicy(maxAttempts: 0)
        XCTAssertEqual(policy.maxAttempts, 1)
    }
}
