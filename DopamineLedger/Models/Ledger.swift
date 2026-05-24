// Transplanted from round 1. Cleaned 2026-05-23.
// No direct test coverage — exercised indirectly through SessionFinalizer
// and RepayMath integration tests.

import Foundation
import SwiftData

// The global credit balance. Per the locked product rules, there's a single
// shared balance across all activities — so this model is effectively a
// singleton (one row in the database, ever).
//
// SwiftData doesn't have a built-in "singleton" concept, so we enforce it
// by convention: always go through `fetchOrCreate(in:)` to read or update.
// On first call we insert one row; on every subsequent call we return the
// existing one.
@Model
final class Ledger {
    var balance:   Double
    var updatedAt: Date

    init(balance: Double = 0) {
        self.balance   = balance
        self.updatedAt = Date()
    }
}

extension Ledger {

    // Returns the singleton Ledger row, creating it on first access.
    // All balance reads and writes should funnel through this.
    @MainActor
    static func fetchOrCreate(in context: ModelContext) -> Ledger {
        let descriptor = FetchDescriptor<Ledger>()
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let new = Ledger()
        context.insert(new)
        return new
    }
}
