// Transplanted from round 1. Cleaned 2026-05-23.
// Test coverage: 6 cases in DopamineLedgerTests
// (testRepayMath* — full, partial, exact, no-balance, no-debt, negative-clamp).

import Foundation

// Pure-function math for repaying an activity's debt from the global balance.
// Same shape as SessionMath: numbers in, numbers out, no SwiftData involvement.
// This makes it trivial to unit test all the edge cases (partial repayment,
// zero balance, zero debt) without spinning up a model container.

struct RepayOutcome: Equatable {
    // How many credits were actually moved from balance to debt.
    var amountRepaid: Double
    // Balance after repayment.
    var newBalance:   Double
    // Remaining debt total for the activity after repayment.
    var newDebtTotal: Double
}

enum RepayMath {

    // Repay as much of the debt as the balance can cover.
    // Inputs are clamped to >= 0 defensively (neither balance nor debt should
    // ever be negative by design, but the function stays safe if they are).
    static func apply(currentBalance: Double, totalDebt: Double) -> RepayOutcome {
        let balance = max(0, currentBalance)
        let debt    = max(0, totalDebt)
        let amount  = min(balance, debt)

        return RepayOutcome(
            amountRepaid: amount,
            newBalance:   balance - amount,
            newDebtTotal: debt - amount
        )
    }

    // Split a repayment across multiple debt rows by zeroing the oldest
    // (= earliest in the input order) first. Returns the *new* row amounts
    // in the same order. Stays pure-function and SwiftData-free so callers
    // can pass plain Doubles and the test layer doesn't need a model
    // container.
    //
    // Why oldest-first? Older debts have been pending longer; clearing them
    // first matches the user's mental model ("pay off what I owe in order").
    static func split(_ amount: Double, across rowAmounts: [Double]) -> [Double] {
        var remaining = max(0, amount)
        return rowAmounts.map { current in
            let pay = min(max(0, current), remaining)
            remaining -= pay
            return max(0, current) - pay
        }
    }
}
