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

    // While paused, elapsed freezes at the pause instant — repeated reads
    // return the same value regardless of wall-clock drift.
    func testSessionPauseFreezesElapsed() {
        let session = Session(activityId: UUID())
        let t0      = session.startedAt
        session.pause(at: t0.addingTimeInterval(10))
        XCTAssertTrue(session.isPaused)
        XCTAssertEqual(session.elapsed, 10, accuracy: 0.001)
        // A small real-time delay shouldn't budge the frozen value.
        Thread.sleep(forTimeInterval: 0.05)
        XCTAssertEqual(session.elapsed, 10, accuracy: 0.001)
    }

    // Resuming records the pause segment in totalPausedSeconds so future
    // elapsed reads subtract it.
    func testSessionResumeSubtractsPauseTime() {
        let session = Session(activityId: UUID())
        let t0      = session.startedAt
        session.pause(at:  t0.addingTimeInterval(10))
        session.resume(at: t0.addingTimeInterval(30))   // 20s spent paused
        XCTAssertFalse(session.isPaused)
        session.endedAt = t0.addingTimeInterval(60)
        XCTAssertEqual(session.elapsed, 40, accuracy: 0.001) // 60 wall - 20 paused
    }

    // Multiple pause cycles sum correctly.
    func testSessionMultiplePauseCycles() {
        let session = Session(activityId: UUID())
        let t0      = session.startedAt
        session.pause(at:  t0.addingTimeInterval(10))
        session.resume(at: t0.addingTimeInterval(15))   // 5s
        session.pause(at:  t0.addingTimeInterval(25))
        session.resume(at: t0.addingTimeInterval(30))   // 5s (total 10s)
        session.endedAt = t0.addingTimeInterval(40)
        XCTAssertEqual(session.elapsed, 30, accuracy: 0.001) // 40 wall - 10 paused
    }

    // Stopping while paused (the finalizer flow) must record the open pause
    // segment so it doesn't count as working time.
    func testSessionStopWhilePausedDoesNotCountPauseTime() {
        let session = Session(activityId: UUID())
        let t0      = session.startedAt
        session.pause(at: t0.addingTimeInterval(10))
        // Mirror SessionFinalizer's order: read elapsed (frozen at 10),
        // resume to record the pause segment, then stamp endedAt.
        let billed = session.elapsed
        session.resume(at: t0.addingTimeInterval(30))
        session.endedAt  = t0.addingTimeInterval(30)
        XCTAssertEqual(billed, 10, accuracy: 0.001)
        // After stamping endedAt, elapsed should agree with what we billed.
        XCTAssertEqual(session.elapsed, 10, accuracy: 0.001)
    }

    // pause()/resume() are no-ops in invalid states so callsites stay safe.
    func testSessionPauseResumeGuards() {
        let session = Session(activityId: UUID())
        let t0      = session.startedAt
        // Double-pause shouldn't move pausedAt.
        session.pause(at: t0.addingTimeInterval(10))
        session.pause(at: t0.addingTimeInterval(20))
        XCTAssertEqual(session.elapsed, 10, accuracy: 0.001)
        // Resume when not paused is also a no-op.
        session.resume(at: t0.addingTimeInterval(30))
        session.resume(at: t0.addingTimeInterval(40))
        XCTAssertFalse(session.isPaused)
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

    // Split zeroes oldest-first: 17 paid across [5, 10, 15] fully clears
    // the first two and partially repays the third (leaving 13).
    func testRepayMathSplitDistributesOldestFirst() {
        let new = RepayMath.split(17, across: [5, 10, 15])
        XCTAssertEqual(new, [0, 0, 13])
    }

    // If repayment equals total debt, all rows zero out.
    func testRepayMathSplitFullyClears() {
        let new = RepayMath.split(30, across: [5, 10, 15])
        XCTAssertEqual(new, [0, 0, 0])
    }

    // Repayment of 0 leaves rows untouched.
    func testRepayMathSplitZeroIsNoOp() {
        let new = RepayMath.split(0, across: [5, 10, 15])
        XCTAssertEqual(new, [5, 10, 15])
    }

    // Negative inputs are clamped (defensive — shouldn't happen, but stays safe).
    // A negative row amount counts as 0 debt for that row, so the repayment
    // flows entirely to the next row (rather than being absorbed into the
    // negative).
    func testRepayMathSplitClampsNegatives() {
        let new = RepayMath.split(-5, across: [10, 20])
        XCTAssertEqual(new, [10, 20])
        let new2 = RepayMath.split(10, across: [-5, 20])
        XCTAssertEqual(new2, [0, 10])
    }

    // MARK: - DashboardStats

    func testDashboardStatsEmpty() {
        let stats = DashboardStats.compute(sessions: [], quests: [], activities: [], debts: [], scope: .allTime)
        XCTAssertEqual(stats.creditsEarned, 0)
        XCTAssertEqual(stats.creditsSpent, 0)
        XCTAssertEqual(stats.questPayoff, 0)
        XCTAssertEqual(stats.debtRepaid, 0)
        XCTAssertEqual(stats.netDelta, 0)
        XCTAssertEqual(stats.totalOutstandingDebt, 0)
        XCTAssertTrue(stats.categoryGroups.isEmpty)
    }

    func testDashboardStatsChargerEarns() {
        let activity = Activity(name: "Reading", kind: .charger, ratePerMinute: 6.0)
        let session  = Session(activityId: activity.id)
        session.endedAt = session.startedAt.addingTimeInterval(60) // 6 credits earned
        let stats = DashboardStats.compute(sessions: [session], quests: [], activities: [activity], debts: [], scope: .allTime)
        XCTAssertEqual(stats.creditsEarned, 6.0, accuracy: 0.001)
        XCTAssertEqual(stats.creditsSpent, 0)
        XCTAssertEqual(stats.netDelta, 6.0, accuracy: 0.001)
        let chargers = stats.categoryGroups.flatMap { $0.chargers }
        XCTAssertEqual(chargers.count, 1)
        XCTAssertEqual(chargers[0].sessionCount, 1)
    }

    func testDashboardStatsSpenderSpends() {
        let activity = Activity(name: "Phone", kind: .spender, ratePerMinute: 6.0)
        let session  = Session(activityId: activity.id)
        session.endedAt = session.startedAt.addingTimeInterval(60) // 6 credits spent
        let stats = DashboardStats.compute(sessions: [session], quests: [], activities: [activity], debts: [], scope: .allTime)
        XCTAssertEqual(stats.creditsEarned, 0)
        XCTAssertEqual(stats.creditsSpent, 6.0, accuracy: 0.001)
        XCTAssertEqual(stats.netDelta, -6.0, accuracy: 0.001)
    }

    func testDashboardStatsQuestPayoff() {
        let quest         = Quest(name: "File taxes", payoffCredits: 100)
        quest.isCompleted = true
        quest.completedAt = Date()
        let stats = DashboardStats.compute(sessions: [], quests: [quest], activities: [], debts: [], scope: .allTime)
        XCTAssertEqual(stats.questPayoff, 100.0, accuracy: 0.001)
        XCTAssertEqual(stats.netDelta, 100.0, accuracy: 0.001)
        let quests = stats.categoryGroups.flatMap { $0.quests }
        XCTAssertEqual(quests.count, 1)
        XCTAssertEqual(quests[0].name, "File taxes")
    }

    // An active session (no endedAt) must not appear in stats — its credits
    // haven't hit the ledger yet and including it would cause flickering numbers.
    func testDashboardStatsActiveSessionExcluded() {
        let activity = Activity(name: "Exercise", kind: .charger, ratePerMinute: 6.0)
        let session  = Session(activityId: activity.id) // endedAt stays nil
        let stats = DashboardStats.compute(sessions: [session], quests: [], activities: [activity], debts: [], scope: .allTime)
        XCTAssertEqual(stats.creditsEarned, 0)
        XCTAssertTrue(stats.categoryGroups.isEmpty)
    }

    // Sessions started before the scope window must not count.
    func testDashboardStatsScopeFiltersOldSessions() {
        let activity = Activity(name: "Reading", kind: .charger, ratePerMinute: 6.0)

        let oldSession       = Session(activityId: activity.id)
        oldSession.startedAt = Date().addingTimeInterval(-8 * 86400) // 8 days ago — outside "this week"
        oldSession.endedAt   = oldSession.startedAt.addingTimeInterval(60)

        let recentSession    = Session(activityId: activity.id) // startedAt ≈ now
        recentSession.endedAt = recentSession.startedAt.addingTimeInterval(60)

        let stats = DashboardStats.compute(
            sessions: [oldSession, recentSession], quests: [], activities: [activity], debts: [], scope: .thisWeek
        )
        XCTAssertEqual(stats.creditsEarned, 6.0, accuracy: 0.001) // only the recent session
    }

    // Sessions whose activity was deleted must be silently skipped.
    func testDashboardStatsOrphanedSessionSkipped() {
        let session  = Session(activityId: UUID()) // no matching activity
        session.endedAt = session.startedAt.addingTimeInterval(60)
        let stats = DashboardStats.compute(sessions: [session], quests: [], activities: [], debts: [], scope: .allTime)
        XCTAssertEqual(stats.creditsEarned, 0)
        XCTAssertEqual(stats.creditsSpent, 0)
    }

    // A fully-repaid debt in scope must appear in debtRepaid and reduce netDelta.
    func testDashboardStatsDebtRepaidInScope() {
        let debt        = ActivityDebt(activityId: UUID(), amount: 30)
        debt.amount     = 0          // cleared
        debt.repaidAt   = Date()     // repaid now — within any scope
        let stats = DashboardStats.compute(sessions: [], quests: [], activities: [], debts: [debt], scope: .allTime)
        XCTAssertEqual(stats.debtRepaid, 30.0, accuracy: 0.001)
        XCTAssertEqual(stats.netDelta, -30.0, accuracy: 0.001)
        XCTAssertEqual(stats.totalOutstandingDebt, 0)
    }

    // A debt repaid outside the scope window must not appear in debtRepaid.
    func testDashboardStatsDebtRepaidOutsideScopeExcluded() {
        let debt        = ActivityDebt(activityId: UUID(), amount: 20)
        debt.amount     = 0
        debt.repaidAt   = Date().addingTimeInterval(-8 * 86400) // 8 days ago — outside "this week"
        let stats = DashboardStats.compute(sessions: [], quests: [], activities: [], debts: [debt], scope: .thisWeek)
        XCTAssertEqual(stats.debtRepaid, 0)
    }

    // An unrepaid debt must show in totalOutstandingDebt but not in debtRepaid.
    func testDashboardStatsOutstandingDebtIsUnscoped() {
        let debt = ActivityDebt(activityId: UUID(), amount: 50) // repaidAt stays nil
        let stats = DashboardStats.compute(sessions: [], quests: [], activities: [], debts: [debt], scope: .today)
        XCTAssertEqual(stats.totalOutstandingDebt, 50.0, accuracy: 0.001)
        XCTAssertEqual(stats.debtRepaid, 0)
    }

    // Full integration: charger + spender + quest + repaid debt → correct netDelta.
    func testDashboardStatsNetDeltaCombinesAll() {
        let charger = Activity(name: "Exercise",    kind: .charger, ratePerMinute: 6.0)
        let spender = Activity(name: "Doomscroll",  kind: .spender, ratePerMinute: 6.0)

        let chargerSession    = Session(activityId: charger.id)
        chargerSession.endedAt = chargerSession.startedAt.addingTimeInterval(120) // 12 credits earned

        let spenderSession    = Session(activityId: spender.id)
        spenderSession.endedAt = spenderSession.startedAt.addingTimeInterval(60)  // 6 credits spent

        let quest         = Quest(name: "Do laundry", payoffCredits: 10)
        quest.isCompleted = true
        quest.completedAt = Date()

        let debt        = ActivityDebt(activityId: spender.id, amount: 8)
        debt.amount     = 0
        debt.repaidAt   = Date() // cleared today

        // netDelta = 12 (earned) + 10 (quest) - 6 (spent) - 8 (repaid) = 8
        let stats = DashboardStats.compute(
            sessions:   [chargerSession, spenderSession],
            quests:     [quest],
            activities: [charger, spender],
            debts:      [debt],
            scope:      .allTime
        )
        XCTAssertEqual(stats.creditsEarned, 12.0, accuracy: 0.001)
        XCTAssertEqual(stats.creditsSpent,  6.0,  accuracy: 0.001)
        XCTAssertEqual(stats.questPayoff,   10.0, accuracy: 0.001)
        XCTAssertEqual(stats.debtRepaid,    8.0,  accuracy: 0.001)
        XCTAssertEqual(stats.netDelta,      8.0,  accuracy: 0.001)
        // Both activities default to .other category; chargers and spenders are separate arrays.
        let group = stats.categoryGroups.first { $0.category == .other }
        XCTAssertEqual(group?.chargers.count, 1)
        XCTAssertEqual(group?.spenders.count, 1)
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
