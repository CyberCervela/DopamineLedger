// Transplanted from round 1. Cleaned 2026-05-23.
// Test coverage: testDebtRepaidFlag in DopamineLedgerTests.

import Foundation
import SwiftData

// Tracks credit debt for one activity.
//
// How debt is created: when a spender session overruns the global credit balance
// past zero, the overrun portion accrues at 2× the activity's rate. Each
// overrun creates a new ActivityDebt row for that activity.
//
// Repayment is always explicit — the user taps the Repay button. Debt is never
// cleared automatically.
@Model
final class ActivityDebt {
    var id:         UUID
    // Denormalised copy — same predicate-safety reason as Session.activityId.
    var activityId: UUID
    // Positive value = credits owed. Set to 0 when repaid.
    var amount:     Double
    var createdAt:  Date

    init(activityId: UUID, amount: Double) {
        self.id         = UUID()
        self.activityId = activityId
        self.amount     = amount
        self.createdAt  = Date()
    }

    var isRepaid: Bool { amount <= 0 }
}
