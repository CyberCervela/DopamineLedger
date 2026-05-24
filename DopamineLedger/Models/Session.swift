// Transplanted from round 1. Cleaned 2026-05-23.
// Test coverage: testSessionElapsed, testSessionClosedElapsed in DopamineLedgerTests.

import Foundation
import SwiftData

// One start-to-stop usage of an activity.
// Timing is computed from timestamps on every read, so the app can be
// backgrounded without losing accuracy — no timers or ticks involved.
@Model
final class Session {
    var id:          UUID
    // Denormalised copy of the activity's UUID — avoids SwiftData predicate
    // issues with nested property access (see TOOLING.md "SwiftData #Predicate
    // gotcha").
    var activityId:  UUID
    var startedAt:   Date
    // nil while the session is running; set when the user taps Stop.
    var endedAt:     Date?

    init(activityId: UUID) {
        self.id         = UUID()
        self.activityId = activityId
        self.startedAt  = Date()
        self.endedAt    = nil
    }

    // Elapsed seconds. Uses Date() for open sessions so the value updates
    // in real time without any background work.
    var elapsed: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }

    var isActive: Bool { endedAt == nil }
}
