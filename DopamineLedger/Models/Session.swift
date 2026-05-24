// Transplanted from round 1. Cleaned 2026-05-23. Pause support added 2026-05-24.
// Test coverage: testSessionElapsed, testSessionClosedElapsed,
// testSessionPause* in DopamineLedgerTests.

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
    // Set when the user pauses; nil while running or after resume.
    // Persisted so pause survives backgrounding / app kill / resume-on-launch.
    var pausedAt:    Date?
    // Sum of all *completed* pause segments. The currently in-progress pause
    // (if pausedAt != nil) is added on the fly in `elapsed`. Default 0 so
    // SwiftData additive migration leaves pre-existing rows correct.
    var totalPausedSeconds: TimeInterval = 0

    init(activityId: UUID) {
        self.id                 = UUID()
        self.activityId         = activityId
        self.startedAt          = Date()
        self.endedAt            = nil
        self.pausedAt           = nil
        self.totalPausedSeconds = 0
    }

    // Elapsed *working* seconds — wall-clock since startedAt minus all time
    // spent paused (both completed segments and any in-progress one). Uses
    // Date() while active so the value advances without a manual timer.
    var elapsed: TimeInterval {
        let endpoint   = endedAt ?? pausedAt ?? Date()
        let wallClock  = endpoint.timeIntervalSince(startedAt)
        return max(0, wallClock - totalPausedSeconds)
    }

    var isActive: Bool { endedAt == nil }
    var isPaused: Bool { endedAt == nil && pausedAt != nil }

    // Begin a pause. No-op if already paused or finished — keeps the callsite
    // safe to call defensively from button taps.
    func pause(at now: Date = Date()) {
        guard isActive, pausedAt == nil else { return }
        pausedAt = now
    }

    // End a pause; rolls the in-progress segment into totalPausedSeconds.
    // No-op if not currently paused.
    func resume(at now: Date = Date()) {
        guard let p = pausedAt else { return }
        totalPausedSeconds += now.timeIntervalSince(p)
        pausedAt = nil
    }
}
