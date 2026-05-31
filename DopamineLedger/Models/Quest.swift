// Transplanted from round 1. Cleaned 2026-05-23.
// No direct test coverage — straightforward CRUD model; exercised
// through the view layer.

import Foundation
import SwiftData

// How often a recurring quest resets after completion.
// Stored as a String raw value so SwiftData persists it as a plain column.
enum RecurringCadence: String, Codable, CaseIterable {
    case daily, weekly, monthly

    // Localization key used in the cadence picker and QuestRow badge.
    var labelKey: String {
        switch self {
        case .daily:   return "quest.cadence.daily"
        case .weekly:  return "quest.cadence.weekly"
        case .monthly: return "quest.cadence.monthly"
        }
    }

    // Start of the current active period. A pending instance whose availableAt
    // is before this date belongs to a past period and should be swept.
    // Weekly anchors to Monday — consistent with DashboardStats.thisWeek logic.
    var currentPeriodStart: Date {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .daily:
            return cal.startOfDay(for: now)
        case .weekly:
            var c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            c.weekday = 2 // Monday
            return cal.date(from: c) ?? cal.startOfDay(for: now)
        case .monthly:
            var c = cal.dateComponents([.year, .month], from: now)
            c.day = 1
            return cal.date(from: c) ?? cal.startOfDay(for: now)
        }
    }

    // Start of the next period after `date` — stored as availableAt on the
    // newly-spawned instance so it stays hidden until the cycle rolls over.
    func nextPeriodStart(from date: Date) -> Date {
        let cal = Calendar.current
        switch self {
        case .daily:
            return cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: date)!)
        case .weekly:
            var c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            c.weekday = 2
            let thisMonday = cal.date(from: c) ?? date
            return cal.date(byAdding: .weekOfYear, value: 1, to: thisMonday)!
        case .monthly:
            var c = cal.dateComponents([.year, .month], from: date)
            c.month! += 1
            c.day = 1
            return cal.date(from: c) ?? date
        }
    }
}

// A user-defined goal. Unlike Activities (which earn or spend credits over
// time), a Quest pays out a lump-sum reward the moment the user taps "Done".
//
// One-shot quests (recurringCadence == nil): soft-archived on completion;
// appear in History as a completed entry.
//
// Recurring quests: on completion a new instance is inserted for the next
// period (hidden via availableAt > now); the completed instance stays as a
// history entry. If a period passes without completion the stale instance is
// hard-deleted silently on next app open and a fresh one created for today —
// no stacking, no guilt. See ActivityListView.sweepExpiredRecurringQuests().
@Model
final class Quest {
    var id:            UUID
    var name:          String
    // Credit reward when this quest is marked Done. User-defined per quest.
    var payoffCredits: Double
    var iconName:      String
    // Optional so SwiftData stores NULL for rows that predate this field.
    var category:      ActivityCategory?
    var createdAt:     Date
    // false = active and visible in the list; true = completed, filtered out.
    var isCompleted:   Bool
    var completedAt:   Date?
    // Soft-delete flag. Completed quests are never hard-deleted — the payoff
    // credit already moved and the history entry should remain. Incomplete
    // quests (no credits moved) can be hard-deleted safely. Default false
    // keeps lightweight migration safe for existing rows.
    var isArchived:    Bool = false

    // nil = one-shot (default). Non-nil = recurring with this cadence.
    // Safe lightweight migration — optional with nil default.
    var recurringCadence: RecurringCadence? = nil

    // nil = immediately visible (all pre-recurring quests and one-shot quests).
    // Non-nil = hidden until this date (next-period instances after completion).
    var availableAt: Date? = nil

    init(name: String, payoffCredits: Double, iconName: String = "star",
         category: ActivityCategory = .other, recurringCadence: RecurringCadence? = nil) {
        self.id               = UUID()
        self.name             = name
        self.payoffCredits    = payoffCredits
        self.iconName         = iconName
        self.category         = category
        self.createdAt        = Date()
        self.isCompleted      = false
        self.completedAt      = nil
        self.recurringCadence = recurringCadence
        // currentPeriodStart ≤ now, so a freshly-created recurring quest is
        // immediately visible. The *next* instance after completion overrides
        // this with nextPeriodStart(from:) to hide it until the cycle rolls.
        self.availableAt      = recurringCadence?.currentPeriodStart
    }
}
