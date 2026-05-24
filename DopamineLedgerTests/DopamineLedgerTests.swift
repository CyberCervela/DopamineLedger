// Transplanted from round 1. 22 tests covering the pure-math layer.
// All passed at transplant time. Re-run via `xcodebuild test` after wiring
// up the new project.

import XCTest
import SwiftData
@testable import DopamineLedger

final class DopamineLedgerTests: XCTestCase {

    // Rate conversion: 6 credits/min should equal 0.1 credits/sec,
    // and 60 seconds of that activity should yield 6 credits.
    func testActivityCreditRate() {
        let activity = Activity(name: "Reading", kind: .charger, ratePerMinute: 6.0)
        XCTAssertEqual(activity.ratePerSecond, 0.1, accuracy: 0.0001)
        XCTAssertEqual(activity.credits(for: 60), 6.0, accuracy: 0.0001)
    }

    // Elapsed time must come from timestamps, not ticks — verify it's non-zero
    // and grows after a short sleep.
    func testSessionElapsed() {
        let session = Session(activityId: UUID())
        XCTAssertTrue(session.isActive)
        Thread.sleep(forTimeInterval: 0.05)
        XCTAssertGreaterThan(session.elapsed, 0)
        XCTAssertLessThan(session.elapsed, 5)
    }

    // A closed session reports the fixed duration, not wall-clock time.
    func testSessionClosedElapsed() {
        let session = Session(activityId: UUID())
        let fixedEnd = session.startedAt.addingTimeInterval(30)
        session.endedAt = fixedEnd
        XCTAssertFalse(session.isActive)
        XCTAssertEqual(session.elapsed, 30, accuracy: 0.001)
    }

    // Debt tracks amount and repaid state correctly.
    func testDebtRepaidFlag() {
        let debt = ActivityDebt(activityId: UUID(), amount: 10.0)
        XCTAssertFalse(debt.isRepaid)
        debt.amount = 0
        XCTAssertTrue(debt.isRepaid)
    }

    // credits(for:) scales linearly — double the time, double the credits.
    func testCreditsScaleLinearly() {
        let activity = Activity(name: "Exercise", kind: .charger, ratePerMinute: 12.0)
        let half  = activity.credits(for: 30)
        let full  = activity.credits(for: 60)
        XCTAssertEqual(full, half * 2, accuracy: 0.0001)
    }

    // MARK: - SessionMath

    func testSessionMathChargerAddsCredits() {
        let outcome = SessionMath.apply(
            kind: .charger, ratePerSecond: 0.1, elapsed: 60, currentBalance: 10
        )
        XCTAssertEqual(outcome.newBalance, 16.0, accuracy: 0.0001)
        XCTAssertEqual(outcome.debtAccrued, 0)
    }

    func testSessionMathSpenderWithinBalance() {
        let outcome = SessionMath.apply(
            kind: .spender, ratePerSecond: 0.1, elapsed: 60, currentBalance: 10
        )
        XCTAssertEqual(outcome.newBalance, 4.0, accuracy: 0.0001)
        XCTAssertEqual(outcome.debtAccrued, 0)
    }

    func testSessionMathSpenderExactlyEmpties() {
        let outcome = SessionMath.apply(
            kind: .spender, ratePerSecond: 0.1, elapsed: 100, currentBalance: 10
        )
        XCTAssertEqual(outcome.newBalance, 0, accuracy: 0.0001)
        XCTAssertEqual(outcome.debtAccrued, 0)
    }

    // The flagship case: spender overruns the balance — debt accrues at 2×
    // the rate for the overrun portion only (not the whole session).
    func testSessionMathSpenderOverrunCreatesDebtAt2x() {
        // rate 0.1/sec, balance 6 → uses up balance in 60s
        // session is 90s → overrun is 30s → debt = 30 × 0.1 × 2 = 6
        let outcome = SessionMath.apply(
            kind: .spender, ratePerSecond: 0.1, elapsed: 90, currentBalance: 6
        )
        XCTAssertEqual(outcome.newBalance, 0, accuracy: 0.0001)
        XCTAssertEqual(outcome.debtAccrued, 6.0, accuracy: 0.0001)
    }

    func testSessionMathSpenderStartsAtZero() {
        let outcome = SessionMath.apply(
            kind: .spender, ratePerSecond: 0.1, elapsed: 60, currentBalance: 0
        )
        XCTAssertEqual(outcome.newBalance, 0, accuracy: 0.0001)
        XCTAssertEqual(outcome.debtAccrued, 12.0, accuracy: 0.0001)
    }

    func testSessionMathZeroElapsedIsNoOp() {
        let outcome = SessionMath.apply(
            kind: .spender, ratePerSecond: 0.1, elapsed: 0, currentBalance: 5
        )
        XCTAssertEqual(outcome.newBalance, 5)
        XCTAssertEqual(outcome.debtAccrued, 0)
    }

    // MARK: - RepayMath

    func testRepayMathFull() {
        let outcome = RepayMath.apply(currentBalance: 100, totalDebt: 30)
        XCTAssertEqual(outcome.amountRepaid, 30)
        XCTAssertEqual(outcome.newBalance,   70)
        XCTAssertEqual(outcome.newDebtTotal, 0)
    }

    func testRepayMathPartial() {
        let outcome = RepayMath.apply(currentBalance: 20, totalDebt: 50)
        XCTAssertEqual(outcome.amountRepaid, 20)
        XCTAssertEqual(outcome.newBalance,   0)
        XCTAssertEqual(outcome.newDebtTotal, 30)
    }

    func testRepayMathExact() {
        let outcome = RepayMath.apply(currentBalance: 50, totalDebt: 50)
        XCTAssertEqual(outcome.amountRepaid, 50)
        XCTAssertEqual(outcome.newBalance,   0)
        XCTAssertEqual(outcome.newDebtTotal, 0)
    }

    func testRepayMathNoBalance() {
        let outcome = RepayMath.apply(currentBalance: 0, totalDebt: 25)
        XCTAssertEqual(outcome.amountRepaid, 0)
        XCTAssertEqual(outcome.newBalance,   0)
        XCTAssertEqual(outcome.newDebtTotal, 25)
    }

    func testRepayMathNoDebt() {
        let outcome = RepayMath.apply(currentBalance: 100, totalDebt: 0)
        XCTAssertEqual(outcome.amountRepaid, 0)
        XCTAssertEqual(outcome.newBalance,   100)
        XCTAssertEqual(outcome.newDebtTotal, 0)
    }

    func testRepayMathNegativeInputsClamped() {
        let outcome = RepayMath.apply(currentBalance: -5, totalDebt: -10)
        XCTAssertEqual(outcome.amountRepaid, 0)
        XCTAssertEqual(outcome.newBalance,   0)
        XCTAssertEqual(outcome.newDebtTotal, 0)
    }

    // MARK: - NotificationMath

    func testNotificationMathSchedulesBothWhenPlenty() throws {
        let times = try XCTUnwrap(NotificationMath.compute(currentBalance: 60, ratePerSecond: 0.1))
        let warning = try XCTUnwrap(times.warningInSeconds)
        XCTAssertEqual(warning,             300, accuracy: 0.001)
        XCTAssertEqual(times.alarmInSeconds, 600, accuracy: 0.001)
    }

    func testNotificationMathSkipsWarningAt5MinExactly() throws {
        let times = try XCTUnwrap(NotificationMath.compute(currentBalance: 30, ratePerSecond: 0.1))
        XCTAssertNil(times.warningInSeconds)
        XCTAssertEqual(times.alarmInSeconds, 300, accuracy: 0.001)
    }

    func testNotificationMathSkipsWarningWhenTooShort() throws {
        let times = try XCTUnwrap(NotificationMath.compute(currentBalance: 12, ratePerSecond: 0.1))
        XCTAssertNil(times.warningInSeconds)
        XCTAssertEqual(times.alarmInSeconds, 120, accuracy: 0.001)
    }

    func testNotificationMathReturnsNilForEmptyBalance() {
        XCTAssertNil(NotificationMath.compute(currentBalance: 0,  ratePerSecond: 0.1))
        XCTAssertNil(NotificationMath.compute(currentBalance: -5, ratePerSecond: 0.1))
    }

    func testNotificationMathReturnsNilForZeroRate() {
        XCTAssertNil(NotificationMath.compute(currentBalance: 50, ratePerSecond: 0))
    }
}
