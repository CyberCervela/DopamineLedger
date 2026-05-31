// Transplanted from round 1. Cleaned 2026-05-23.
// Test coverage: testActivityCreditRate, testCreditsScaleLinearly in DopamineLedgerTests.

import Foundation
import SwiftData

// Whether an activity earns credits over time (charger) or spends them (spender).
enum ActivityKind: String, Codable, CaseIterable {
    case charger
    case spender
}

// Represents one type of activity the user can track.
// ratePerSecond is stored internally; the UI works in per-minute rates
// because "10 credits/minute" is easier to reason about than "0.166.../second".
@Model
final class Activity {
    var id:            UUID
    var name:          String
    var kind:          ActivityKind
    // Credits earned (charger) or spent (spender) per second of elapsed time.
    var ratePerSecond: Double
    // Theme-agnostic semantic icon key; resolved via IconResolver against the
    // active Theme. NOT a raw asset path or SF Symbol name.
    var iconName:      String
    // Optional so SwiftData stores NULL for rows that predate this field.
    // Non-optional Codable enum defaults crash on migration for existing stores
    // (SwiftData's transformer can't fill old rows). Read via ?? .other.
    var category:      ActivityCategory?
    // Soft-delete flag. True = activity removed from the home list but kept in the
    // DB so its historical sessions remain attributed and visible in Stats + History.
    // Never hard-delete an Activity — credits already moved at session finalize time
    // and cannot be retroactively erased. Default false keeps lightweight migration safe.
    var isArchived:    Bool = false
    // Optional URL scheme ("youtube://") or https URL for linked-app gatekeeper.
    // Nil means no linked app. Set at activity creation/edit; read by SessionView
    // to show the "Open [App] →" button during a running session.
    var linkedAppScheme: String?
    var linkedAppName:   String?
    var createdAt:     Date

    init(name: String, kind: ActivityKind, ratePerMinute: Double, iconName: String = "circle", category: ActivityCategory = .other) {
        self.id            = UUID()
        self.name          = name
        self.kind          = kind
        self.ratePerSecond = ratePerMinute / 60.0
        self.iconName      = iconName
        self.category      = category  // always set; nil only possible for pre-migration rows
        self.createdAt     = Date()
    }

    // Credits earned or spent for a given duration of this activity.
    func credits(for duration: TimeInterval) -> Double {
        ratePerSecond * duration
    }
}
