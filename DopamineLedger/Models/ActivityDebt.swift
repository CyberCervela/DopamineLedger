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
    var id:             UUID
    // Denormalised copy — same predicate-safety reason as Session.activityId.
    var activityId:     UUID
    // Positive value = credits owed. Set to 0 when repaid.
    var amount:         Double
    // Frozen snapshot of the debt at creation. Never mutated — used by
    // DashboardStats to know how much was owed even after amount reaches 0.
    // Default 0 so SwiftData lightweight migration leaves pre-existing rows
    // intact (they'll contribute 0 to debtRepaid stats, which is acceptable
    // since we have no historical record of their original value).
    var originalAmount: Double = 0
    var createdAt:      Date
    // Stamped by the repay flow when this row's amount reaches 0.
    // nil means the debt is still (at least partially) outstanding.
    // Used by DashboardStats to scope repayment events to a time window.
    var repaidAt:       Date?

    init(activityId: UUID, amount: Double) {
        self.id             = UUID()
        self.activityId     = activityId
        self.amount         = amount
        self.originalAmount = amount
        self.createdAt      = Date()
        self.repaidAt       = nil
    }

    var isRepaid: Bool { amount <= 0 }
}
