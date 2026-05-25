// SessionActivityAttributes.swift
// Compiled into both the main app and the DopamineLedgerWidgets extension.
//
// This file is the data contract between the two processes. The main app
// populates it from SwiftData models; the extension renders from it —
// extensions have no SwiftData access, so everything they need must arrive
// through these structs.

import ActivityKit
import Foundation

struct SessionActivityAttributes: ActivityAttributes {

    // Static — set at session start, unchanged for the session's lifetime.
    let activityName:  String
    let activityKind:  String   // ActivityKind.rawValue — "charger" or "spender"
    let ratePerSecond: Double

    struct ContentState: Codable, Hashable {

        // "Clock origin" the extension uses to compute live elapsed time:
        //   elapsed = Date.now − adjustedStart
        //           = (Date.now − session.startedAt) − session.totalPausedSeconds
        //
        // This value only changes when a pause ends: on resume(), the
        // main app pushes a new adjustedStart shifted forward by the
        // pause duration so the extension's math stays in sync.
        let adjustedStart: Date

        // While paused, the timer should freeze. The extension shows
        // pausedElapsed as a static string instead of computing from adjustedStart.
        let isPaused:      Bool
        let pausedElapsed: TimeInterval

        // Credits at the time of this push — displayed in the expanded
        // Dynamic Island. Updated on pause/resume events; slightly stale
        // between them, which is acceptable for a glanceable summary.
        let creditsMoved:  Double
    }
}
