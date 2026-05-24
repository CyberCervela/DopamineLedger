// Transplanted from round 1. Cleaned 2026-05-23.
// No direct test coverage — exercised through view-level integration tests
// (which round 1 deferred; consider adding for round 2).

import Foundation
import SwiftData

// Shared helper for "end this session" logic.
//
// Both SessionView (when the user taps Stop) and SettingsView (when the
// user picks "Stop active session" from the global reset menu) need to do
// the exact same work:
//   1. Cancel pending notifications for this session
//   2. Stamp endedAt
//   3. Look up the activity for the session
//   4. Apply credit/debt math via SessionMath
//   5. Update the ledger
//   6. Insert a debt row if the session overran
//
// Extracting it here keeps the two call sites consistent — fix a bug here
// and both flows get it for free.

// Returned when a session is finalized. Lets the caller (typically
// SessionView) build a feedback toast without redoing the math.
struct FinalizedSession {
    let outcome:        SessionOutcome
    let activityKind:   ActivityKind
    let balanceBefore:  Double
}

enum SessionFinalizer {

    @MainActor
    @discardableResult
    static func finalize(session: Session, in context: ModelContext) -> FinalizedSession? {
        // Always cancel notifications first — once stopping, the scheduled
        // warning/alarm are no longer relevant. Idempotent for chargers.
        NotificationScheduler.cancelSession(sessionId: session.id)

        // Read elapsed BEFORE resume() — while paused, `elapsed` is frozen
        // at the pause point, which is the correct value to bill against.
        // Then resume() to fold the in-progress pause segment into
        // totalPausedSeconds (so future reads of `elapsed` on this finished
        // session stay correct), then stamp endedAt.
        let elapsed = session.elapsed
        session.resume()
        session.endedAt = Date()

        // Resolve the activity for this session (could be any activity).
        // SwiftData #Predicate gotcha: extract id to a local first; nested
        // property access in a predicate closure breaks compilation. See
        // TOOLING.md.
        let sessionActivityId = session.activityId
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate<Activity> { $0.id == sessionActivityId }
        )
        guard let activity = try? context.fetch(descriptor).first else {
            // Activity was deleted mid-session — session is closed, no math.
            return nil
        }

        let ledger = Ledger.fetchOrCreate(in: context)
        let balanceBefore = ledger.balance

        let outcome = SessionMath.apply(
            kind:           activity.kind,
            ratePerSecond:  activity.ratePerSecond,
            elapsed:        elapsed,
            currentBalance: balanceBefore
        )

        ledger.balance   = outcome.newBalance
        ledger.updatedAt = Date()

        if outcome.debtAccrued > 0 {
            context.insert(
                ActivityDebt(activityId: activity.id, amount: outcome.debtAccrued)
            )
        }

        return FinalizedSession(
            outcome:       outcome,
            activityKind:  activity.kind,
            balanceBefore: balanceBefore
        )
    }
}
