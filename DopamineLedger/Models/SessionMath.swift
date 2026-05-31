// Transplanted from round 1. Cleaned 2026-05-23.
// Test coverage: 6 cases in DopamineLedgerTests
// (testSessionMath* — charger, spender within balance, exact-empty,
//  overrun at 2x, starts-at-zero, zero-elapsed guard).

import Foundation

// The pure-function home for the credit/debt math that runs when a session
// ends. Keeping it separate from views and from SwiftData makes it trivial
// to unit-test — feed in numbers, get numbers back, no mocks needed.
//
// Why a separate type instead of a method on Activity? Two reasons:
// 1. The math involves Activity AND the global balance — neither owns it
//    cleanly.
// 2. We can call it without touching SwiftData at all in tests, which keeps
//    tests fast and deterministic.

// The result of applying a session to the ledger.
struct SessionOutcome: Equatable {
    // Balance after the session is applied. Never negative.
    var newBalance: Double
    // Debt freshly accrued by this session (0 if none).
    // The locked rule: spender overruns past zero create debt at 2× rate.
    var debtAccrued: Double
}

enum SessionMath {

    // Apply one session's worth of elapsed time to a starting balance.
    //
    // - For chargers: credits add to the balance, no debt possible.
    // - For spenders: the session first depletes the balance; any remaining
    //   time (the overrun) accrues debt at TWICE the effective rate.
    // - multiplier: the peak-hours bonus stamped on the session at start time
    //   (1.0 = normal, 1.5 = peak). Scales the effective rate so both the
    //   credits moved and any debt penalty reflect the same multiplier.
    static func apply(
        kind:           ActivityKind,
        ratePerSecond:  Double,
        elapsed:        TimeInterval,
        currentBalance: Double,
        multiplier:     Double = 1.0
    ) -> SessionOutcome {

        // Safety: a zero or negative rate would mean infinite-time-until-zero
        // or division by zero. Treat it as a no-op.
        guard ratePerSecond > 0, elapsed > 0 else {
            return SessionOutcome(newBalance: currentBalance, debtAccrued: 0)
        }

        // The effective rate already bakes in the peak multiplier, so all
        // downstream math (credits, debt threshold, debt amount) is consistent.
        let effectiveRate = ratePerSecond * multiplier
        let credits       = effectiveRate * elapsed

        switch kind {
        case .charger:
            return SessionOutcome(
                newBalance:  currentBalance + credits,
                debtAccrued: 0
            )

        case .spender:
            // If we have enough balance, just subtract — no debt.
            if currentBalance >= credits {
                return SessionOutcome(
                    newBalance:  currentBalance - credits,
                    debtAccrued: 0
                )
            }

            // Otherwise: balance drains to zero, the remaining time creates
            // debt at the 2× penalty rate (applied to the effective rate so
            // the penalty is proportional to the peak bonus the user received).
            let timeUntilZero = max(0, currentBalance / effectiveRate)
            let overrun       = max(0, elapsed - timeUntilZero)
            let debt          = overrun * effectiveRate * 2

            return SessionOutcome(
                newBalance:  0,
                debtAccrued: debt
            )
        }
    }
}
