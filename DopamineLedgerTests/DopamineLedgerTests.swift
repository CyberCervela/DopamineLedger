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

    // MARK: - Export / Import round-trip
    // Creates an in-memory store, inserts one of each model with EVERY field set to a
    // non-default value, runs the full export → encode → decode → import cycle, then
    // asserts field-by-field equality. If you add a model field and forget to update
    // DataExporter, the imported value will be the default and this test will fail.
    @MainActor
    func testExportImportRoundTrip() throws {
        let schema = Schema([Activity.self, Session.self, Quest.self,
                             ActivityDebt.self, Ledger.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let ctx = container.mainContext

        // Activity — all fields non-default
        let act = Activity(name: "Test", kind: .charger, ratePerMinute: 6.0,
                           iconName: "bolt.fill", category: .focusLearning)
        act.isArchived      = true
        act.linkedAppScheme = "notion://"
        act.linkedAppName   = "Notion"
        ctx.insert(act)

        // Session — all fields non-default
        let sess = Session(activityId: act.id)
        sess.endedAt            = Date(timeIntervalSinceNow: 300)
        sess.pausedAt           = nil
        sess.totalPausedSeconds = 45
        sess.timeMultiplier     = 1.5
        sess.creditsMoved       = 30.0
        ctx.insert(sess)

        // Quest — all fields non-default, recurring
        let q = Quest(name: "Make Bed", payoffCredits: 5.0, iconName: "star",
                      category: .movement, recurringCadence: .daily)
        q.isCompleted     = true
        q.completedAt     = Date(timeIntervalSinceNow: -3600)
        q.isArchived      = true
        q.availableAt     = Date(timeIntervalSinceNow: 86400)
        ctx.insert(q)

        // Debt — all fields non-default
        let debt = ActivityDebt(activityId: act.id, amount: 12.5)
        debt.originalAmount = 25.0
        debt.repaidAt       = Date(timeIntervalSinceNow: -1800)
        ctx.insert(debt)

        // Ledger
        let ledger = Ledger.fetchOrCreate(in: ctx)
        ledger.balance = 420.5

        try ctx.save()

        // ---- Export ----
        guard let url = DataExporter.exportToFile(context: ctx) else {
            XCTFail("exportToFile returned nil"); return
        }
        guard let exported = DataExporter.decodeBackup(from: url) else {
            XCTFail("decodeBackup returned nil"); return
        }

        // ---- Import into a fresh store ----
        let container2 = try ModelContainer(for: schema, configurations:
            ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx2 = container2.mainContext
        try DataExporter.applyImport(exported, context: ctx2)

        // ---- Assert Activity fields ----
        let acts = try ctx2.fetch(FetchDescriptor<Activity>())
        XCTAssertEqual(acts.count, 1)
        let a2 = acts[0]
        XCTAssertEqual(a2.id,              act.id)
        XCTAssertEqual(a2.name,            act.name)
        XCTAssertEqual(a2.kind,            act.kind)
        XCTAssertEqual(a2.ratePerSecond,   act.ratePerSecond, accuracy: 0.0001)
        XCTAssertEqual(a2.iconName,        act.iconName)
        XCTAssertEqual(a2.category,        act.category)
        XCTAssertEqual(a2.isArchived,      act.isArchived)
        XCTAssertEqual(a2.linkedAppScheme, act.linkedAppScheme)
        XCTAssertEqual(a2.linkedAppName,   act.linkedAppName)
        XCTAssertEqual(a2.createdAt.timeIntervalSince1970,
                       act.createdAt.timeIntervalSince1970, accuracy: 1.0)

        // ---- Assert Session fields ----
        let sessions = try ctx2.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(sessions.count, 1)
        let s2 = sessions[0]
        XCTAssertEqual(s2.id,                 sess.id)
        XCTAssertEqual(s2.activityId,         sess.activityId)
        XCTAssertEqual(s2.totalPausedSeconds, sess.totalPausedSeconds, accuracy: 0.01)
        XCTAssertEqual(s2.timeMultiplier,     sess.timeMultiplier, accuracy: 0.0001)
        XCTAssertEqual(s2.creditsMoved,       sess.creditsMoved, accuracy: 0.0001)
        XCTAssertNil(s2.pausedAt)
        XCTAssertNotNil(s2.endedAt)

        // ---- Assert Quest fields ----
        let quests = try ctx2.fetch(FetchDescriptor<Quest>())
        XCTAssertEqual(quests.count, 1)
        let q2 = quests[0]
        XCTAssertEqual(q2.id,               q.id)
        XCTAssertEqual(q2.name,             q.name)
        XCTAssertEqual(q2.payoffCredits,    q.payoffCredits, accuracy: 0.0001)
        XCTAssertEqual(q2.iconName,         q.iconName)
        XCTAssertEqual(q2.category,         q.category)
        XCTAssertEqual(q2.isCompleted,      q.isCompleted)
        XCTAssertEqual(q2.isArchived,       q.isArchived)
        XCTAssertEqual(q2.recurringCadence, q.recurringCadence)
        XCTAssertNotNil(q2.completedAt)
        XCTAssertNotNil(q2.availableAt)

        // ---- Assert Debt fields ----
        let debts = try ctx2.fetch(FetchDescriptor<ActivityDebt>())
        XCTAssertEqual(debts.count, 1)
        let d2 = debts[0]
        XCTAssertEqual(d2.id,             debt.id)
        XCTAssertEqual(d2.activityId,     debt.activityId)
        XCTAssertEqual(d2.amount,         debt.amount, accuracy: 0.0001)
        XCTAssertEqual(d2.originalAmount, debt.originalAmount, accuracy: 0.0001)
        XCTAssertNotNil(d2.repaidAt)

        // ---- Assert Ledger balance ----
        let l2 = Ledger.fetchOrCreate(in: ctx2)
        XCTAssertEqual(l2.balance, 420.5, accuracy: 0.0001)
    }

    // MARK: - SessionFinalizer integration tests
    //
    // These tests spin up a real in-memory SwiftData store and call
    // SessionFinalizer.finalize() the way the app does — verifying that the
    // Ledger balance, session.creditsMoved, and debt rows are all correct
    // after the call. The pure math is covered by SessionMath tests above;
    // these tests cover the glue that writes the results to the database.

    // A charger session that runs for 60 s at 6 cr/min (0.1 cr/s) should add
    // exactly 6 credits to the ledger, stamp a positive creditsMoved, and
    // create no debt row.
    @MainActor
    func testFinalizerChargerCreditsLedger() throws {
        let schema = Schema([Activity.self, Session.self, Quest.self,
                             ActivityDebt.self, Ledger.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let ctx = container.mainContext

        let activity = Activity(name: "Reading", kind: .charger, ratePerMinute: 6.0)
        ctx.insert(activity)

        let ledger = Ledger.fetchOrCreate(in: ctx)
        ledger.balance = 100.0

        // Build a session with a known 60-second elapsed time.
        let session = Session(activityId: activity.id)
        let t0 = session.startedAt
        session.endedAt = t0.addingTimeInterval(60)
        ctx.insert(session)

        SessionFinalizer.finalize(session: session, in: ctx)

        XCTAssertEqual(ledger.balance, 106.0, accuracy: 0.001)   // 100 + 6
        XCTAssertEqual(session.creditsMoved, 6.0, accuracy: 0.001) // positive = earned
        let debts = try ctx.fetch(FetchDescriptor<ActivityDebt>())
        XCTAssertTrue(debts.isEmpty, "charger overrun should create no debt")
    }

    // A spender session that runs 120 s at 6 cr/min on a 5-credit balance should
    // drain the balance to zero, accrue 7 credits of debt (the 2× overrun on the
    // 3.5 s of overrun... actually: 5 cr balance / 0.1 cr/s = 50 s covered;
    // remaining 70 s at 2× debt rate = 70 × 0.1 × 2 = 14 cr debt), stamp a
    // negative creditsMoved, and insert exactly one debt row.
    @MainActor
    func testFinalizerSpenderOverrunCreatesDebt() throws {
        let schema = Schema([Activity.self, Session.self, Quest.self,
                             ActivityDebt.self, Ledger.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let ctx = container.mainContext

        let activity = Activity(name: "Doomscrolling", kind: .spender, ratePerMinute: 6.0)
        ctx.insert(activity)

        let ledger = Ledger.fetchOrCreate(in: ctx)
        ledger.balance = 5.0   // only 50 s of runway at 0.1 cr/s

        let session = Session(activityId: activity.id)
        let t0 = session.startedAt
        session.endedAt = t0.addingTimeInterval(120)  // 70 s of overrun
        ctx.insert(session)

        SessionFinalizer.finalize(session: session, in: ctx)

        // Balance floors at zero (SessionMath never goes negative).
        XCTAssertEqual(ledger.balance, 0.0, accuracy: 0.001)
        // creditsMoved is negative for spenders.
        XCTAssertLessThan(session.creditsMoved, 0)
        // Overrun: 70 s × 0.1 cr/s × 2× debt rate = 14 cr debt.
        let debts = try ctx.fetch(FetchDescriptor<ActivityDebt>())
        XCTAssertEqual(debts.count, 1, "one debt row should be inserted on overrun")
        XCTAssertEqual(debts[0].amount, 14.0, accuracy: 0.001)
    }

    // Starting with 20 cr balance and a single 30-cr debt row, calling the repay
    // logic should drain the full 20 cr from the ledger, reduce the debt row to
    // 10 cr, and leave repaidAt nil (row is only partially repaid).
    @MainActor
    func testRepayReducesDebtAndBalance() throws {
        let schema = Schema([Activity.self, Session.self, Quest.self,
                             ActivityDebt.self, Ledger.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let ctx = container.mainContext

        let activityId = UUID()
        let debt = ActivityDebt(activityId: activityId, amount: 30.0)
        ctx.insert(debt)

        let ledger = Ledger.fetchOrCreate(in: ctx)
        ledger.balance = 20.0

        // Replicate the repay logic from DebtView / ActivityMenuView exactly.
        let rows   = [debt]
        let total  = rows.reduce(0.0) { $0 + $1.amount }
        let outcome = RepayMath.apply(currentBalance: ledger.balance, totalDebt: total)

        guard outcome.amountRepaid > 0 else {
            XCTFail("expected a partial repayment"); return
        }

        ledger.balance = outcome.newBalance
        let newAmounts = RepayMath.split(outcome.amountRepaid, across: rows.map(\.amount))
        for (row, newAmount) in zip(rows, newAmounts) {
            row.amount = newAmount
            if newAmount == 0 { row.repaidAt = Date() }
        }

        XCTAssertEqual(ledger.balance, 0.0,  accuracy: 0.001)  // fully spent on repay
        XCTAssertEqual(debt.amount,    10.0, accuracy: 0.001)  // 30 − 20 = 10 remaining
        XCTAssertNil(debt.repaidAt, "partial repay should not stamp repaidAt")
    }

    // MARK: - Double(userInput:) — locale-tolerant numeric parsing
    //
    // Guards the editor sheets' rate/payoff parsing (AddActivityView,
    // AddQuestView). The plain `Double(_:)` initialiser only accepts dot
    // decimals, which locks out French/German/Spanish users whose decimal pad
    // types "," — these tests pin down the tolerant behaviour. Note: the > 0 /
    // negative / zero guards live at the call sites, so this helper itself only
    // parses; it does not reject negatives or zero.

    func testUserInputParsesDotDecimal() {
        XCTAssertEqual(Double(userInput: "2.5"), 2.5)
    }

    func testUserInputParsesCommaDecimal() {
        // The flagship fix: "2,5" (FR/DE/ES decimal pad) must parse to 2.5.
        XCTAssertEqual(Double(userInput: "2,5"), 2.5)
    }

    func testUserInputTrimsWhitespace() {
        XCTAssertEqual(Double(userInput: "  3.0  "), 3.0)
        XCTAssertEqual(Double(userInput: " 4,5 "),  4.5)
    }

    func testUserInputParsesPlainInteger() {
        XCTAssertEqual(Double(userInput: "1000"), 1000.0)
    }

    // Documented consequence of the comma→dot swap: a literal "1,000" becomes
    // "1.000" = 1.0, NOT one thousand. This is acceptable because the decimal
    // pad has no grouping-separator key (users can't type "1,000" by hand), and
    // AddQuestView now seeds the field grouping-free so the round-trip is clean.
    func testUserInputGroupingSeparatorBecomesDecimal() {
        XCTAssertEqual(Double(userInput: "1,000"), 1.0)
    }

    func testUserInputRejectsEmptyString() {
        XCTAssertNil(Double(userInput: ""))
        XCTAssertNil(Double(userInput: "   "))
    }

    func testUserInputRejectsNonFinite() {
        // Double("inf")/Double("nan") parse successfully and would slip past a
        // `> 0` guard, so the helper must reject non-finite values itself.
        XCTAssertNil(Double(userInput: "inf"))
        XCTAssertNil(Double(userInput: "nan"))
    }

    // The helper parses negatives and zero (sign/zero filtering is the call
    // site's job via its `> 0` guard) — pin that contract so a future refactor
    // doesn't accidentally move the responsibility.
    func testUserInputParsesNegativeAndZero() {
        XCTAssertEqual(Double(userInput: "-2,5"), -2.5)
        XCTAssertEqual(Double(userInput: "0"), 0.0)
    }

    // MARK: - Malformed-import hardening (F-13 / QA-30)
    //
    // The Import flow (Settings → Danger Zone → Import) is reachable by an App
    // Store reviewer, so it must survive any file a reviewer might point it at:
    // empty, non-JSON, truncated, valid-JSON-wrong-schema, or huge. The contract
    // is: decodeBackup(from:) returns nil for anything it can't parse (the UI then
    // shows a friendly localized error), and applyImport never partially imports.
    // These tests feed DataExporter real files on disk via the temporary directory,
    // matching how the live document picker hands it a URL. Note decodeBackup calls
    // startAccessingSecurityScopedResource(), which returns false for plain temp
    // files — that's expected; its `defer` guard only stops accessing if it started.

    // Helper: write `data` to a unique temp file and return its URL. Each test is
    // responsible for removing the file it creates (we do so via addTeardownBlock
    // so cleanup still runs if an assertion fails mid-test).
    private func makeTempFile(_ data: Data, ext: String = "json") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-import-test-\(UUID().uuidString)")
            .appendingPathExtension(ext)
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    // 1. Empty file (0 bytes) → JSONDecoder has nothing to decode → nil.
    func testDecodeBackupEmptyFileReturnsNil() throws {
        let url = try makeTempFile(Data())
        XCTAssertNil(DataExporter.decodeBackup(from: url))
    }

    // 2. Non-JSON text → decode fails → nil.
    func testDecodeBackupNonJSONReturnsNil() throws {
        let url = try makeTempFile(Data("hello world".utf8), ext: "txt")
        XCTAssertNil(DataExporter.decodeBackup(from: url))
    }

    // 3. Truncated JSON: take a valid export and cut it in half. The first half
    // is no longer parseable JSON, so decode must fail rather than partially
    // populate an ExportData.
    @MainActor
    func testDecodeBackupTruncatedJSONReturnsNil() throws {
        // Build a real export to truncate so the test stays honest if the schema
        // changes (a hand-written string could drift out of sync).
        let schema = Schema([Activity.self, Session.self, Quest.self,
                             ActivityDebt.self, Ledger.self])
        let container = try ModelContainer(for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext
        ctx.insert(Activity(name: "X", kind: .charger, ratePerMinute: 6.0,
                            iconName: "bolt.fill", category: .focusLearning))
        try ctx.save()

        guard let validURL = DataExporter.exportToFile(context: ctx),
              let validData = try? Data(contentsOf: validURL) else {
            XCTFail("could not produce a valid export to truncate"); return
        }
        let half = validData.prefix(validData.count / 2)
        let url = try makeTempFile(Data(half))
        XCTAssertNil(DataExporter.decodeBackup(from: url))
    }

    // 4. Valid JSON, wrong schema: parses as JSON but is missing every required
    // ExportData key, so Decodable throws keyNotFound → nil.
    func testDecodeBackupWrongSchemaReturnsNil() throws {
        let url = try makeTempFile(Data(#"{"foo": 1}"#.utf8))
        XCTAssertNil(DataExporter.decodeBackup(from: url))
    }

    // 5. Huge file smoke test: a structurally valid ExportData carrying 50,000
    // sessions must decode AND import without crashing or blowing the runtime
    // budget. This exercises the loop in applyImport at scale, not just the parser.
    @MainActor
    func testHugeImportDoesNotCrash() throws {
        let activityId = UUID()
        let sessions: [SessionExport] = (0..<50_000).map { i in
            SessionExport(
                id: UUID(),
                activityId: activityId,
                startedAt: Date(timeIntervalSince1970: TimeInterval(i)),
                endedAt: nil,
                pausedAt: nil,
                totalPausedSeconds: 0,
                timeMultiplier: 1.0,
                creditsMoved: 0
            )
        }
        let big = ExportData(
            version: 1,
            exportedAt: Date(),
            balance: 0,
            activities: [],
            sessions: sessions,
            quests: [],
            debts: []
        )

        // Round-trip through JSON on disk so we exercise the real decode path,
        // then import into a fresh in-memory store.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(big)
        let url = try makeTempFile(data)

        guard let decoded = DataExporter.decodeBackup(from: url) else {
            XCTFail("huge but valid backup failed to decode"); return
        }
        XCTAssertEqual(decoded.sessions.count, 50_000)

        let schema = Schema([Activity.self, Session.self, Quest.self,
                             ActivityDebt.self, Ledger.self])
        let container = try ModelContainer(for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext
        try DataExporter.applyImport(decoded, context: ctx)

        let imported = try ctx.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(imported.count, 50_000)
    }

    // 6. Existing data untouched on decode failure: this documents the end-to-end
    // contract. When decodeBackup returns nil, the UI never calls applyImport, so
    // the store is never wiped. We assert that explicitly: garbage decodes to nil
    // AND the pre-existing row is still present (because applyImport was, correctly,
    // never reached).
    @MainActor
    func testDecodeFailureLeavesExistingDataUntouched() throws {
        let schema = Schema([Activity.self, Session.self, Quest.self,
                             ActivityDebt.self, Ledger.self])
        let container = try ModelContainer(for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext
        let known = Activity(name: "Keep Me", kind: .charger, ratePerMinute: 6.0,
                             iconName: "bolt.fill", category: .focusLearning)
        ctx.insert(known)
        try ctx.save()

        // Attempt to decode garbage — must fail, so applyImport is never invoked.
        let url = try makeTempFile(Data("not json at all".utf8), ext: "txt")
        XCTAssertNil(DataExporter.decodeBackup(from: url))

        let acts = try ctx.fetch(FetchDescriptor<Activity>())
        XCTAssertEqual(acts.count, 1)
        XCTAssertEqual(acts.first?.name, "Keep Me")
    }

    // 7. Rollback-on-throw (Part 1): forcing applyImport to throw requires
    // injecting a failing ModelContext, which the current API does not allow.
    // Per the packet, we deliberately do NOT refactor DataExporter for
    // testability here, so this path is left unverified by an automated test.
    // The rollback guard is exercised manually/by reasoning: any throw inside
    // applyImport now calls context.rollback() before rethrowing, discarding the
    // staged wipe so autosave cannot persist a partial import.
}
