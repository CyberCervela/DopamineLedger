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
    var createdAt:     Date

    init(name: String, kind: ActivityKind, ratePerMinute: Double, iconName: String = "circle") {
        self.id            = UUID()
        self.name          = name
        self.kind          = kind
        self.ratePerSecond = ratePerMinute / 60.0
        self.iconName      = iconName
        self.createdAt     = Date()
    }

    // Credits earned or spent for a given duration of this activity.
    func credits(for duration: TimeInterval) -> Double {
        ratePerSecond * duration
    }
}
