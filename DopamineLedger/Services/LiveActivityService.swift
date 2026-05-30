// LiveActivityService.swift
// Manages the one Live Activity that mirrors an active session.
//
// All methods are unconditionally callable — they silently no-op when
// Live Activities are unavailable or the device doesn't support them.
// The rest of the app never needs to guard before calling in.
//
// We track the active Live Activity by its ID in UserDefaults rather than
// using .activities.first. Two reasons:
//   1. The ID survives an app kill — if the user force-quits mid-session and
//      relaunches, we can still find and end the correct activity.
//   2. If a previous session's activity wasn't cleaned up, .activities can
//      contain multiple entries; .first would target the wrong one, causing
//      update() and end() to silently no-op on the correct activity while
//      it keeps ticking forever via Text(.timer).

import ActivityKit
import Foundation

@MainActor
enum LiveActivityService {

    // MARK: - Private state

    private static let idKey = "LiveActivityService.currentID"

    // The ID of the Live Activity we own. Stored in UserDefaults so it
    // survives force-kills and relaunches.
    private static var currentID: String? {
        get { UserDefaults.standard.string(forKey: idKey) }
        set {
            if let v = newValue { UserDefaults.standard.set(v, forKey: idKey) }
            else                { UserDefaults.standard.removeObject(forKey: idKey) }
        }
    }

    // Looks up the tracked activity by its stored ID. Returns nil if the ID
    // is absent (never started, or already ended) or if ActivityKit no longer
    // has an activity with that ID (e.g., user dismissed it from the lock screen).
    private static var currentActivity: ActivityKit.Activity<SessionActivityAttributes>? {
        guard let id = currentID else { return nil }
        return ActivityKit.Activity<SessionActivityAttributes>.activities.first { $0.id == id }
    }

    // True when we currently own a Live Activity that is still running.
    // Used by the recovery path in ActivityListView: if a session was started
    // via Siri while the app was backgrounded, Activity.request() fails silently
    // (platform restriction — foreground only). On next foreground transition
    // ActivityListView checks this flag and calls start() again.
    static var hasActiveActivity: Bool { currentActivity != nil }

    // MARK: - Start

    // Called when a new session begins. Immediately ends any orphaned Live
    // Activities from previous sessions, then requests a fresh one and stores
    // its ID. The immediate dismissal prevents old activities from lingering
    // on the lock screen while the new session is already underway (Bug 3).
    static func start(
        activityName:  String,
        activityKind:  ActivityKind,
        ratePerSecond: Double,
        startedAt:     Date
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // End all existing activities of this type immediately. Any activity
        // left here is an orphan — either from a crash, a missed end() call,
        // or the 30-second dismissal window of the previous session.
        for orphan in ActivityKit.Activity<SessionActivityAttributes>.activities {
            Task { await orphan.end(nil, dismissalPolicy: .immediate) }
        }
        currentID = nil

        let attributes = SessionActivityAttributes(
            activityName:  activityName,
            activityKind:  activityKind.rawValue,
            ratePerSecond: ratePerSecond
        )
        let initialState = SessionActivityAttributes.ContentState(
            adjustedStart: startedAt,   // no pauses yet — adjustedStart == startedAt
            isPaused:      false,
            pausedElapsed: 0,
            creditsMoved:  0
        )

        guard let activity = try? ActivityKit.Activity<SessionActivityAttributes>.request(
            attributes: attributes,
            content:    ActivityContent(state: initialState, staleDate: nil)
        ) else { return }

        currentID = activity.id
    }

    // MARK: - Update

    // Called on pause and resume. Updates the clock origin and paused state.
    // Parameters:
    //   adjustedStart  — session.startedAt + session.totalPausedSeconds
    //                    (the "virtual" start that accounts for all pauses)
    //   isPaused       — whether the session clock is frozen
    //   pausedElapsed  — the frozen elapsed value shown while paused
    //   creditsMoved   — credits at the time of this push (shown in expanded DI)
    static func update(
        adjustedStart: Date,
        isPaused:      Bool,
        pausedElapsed: TimeInterval,
        creditsMoved:  Double
    ) {
        guard let activity = currentActivity else { return }
        let state = SessionActivityAttributes.ContentState(
            adjustedStart: adjustedStart,
            isPaused:      isPaused,
            pausedElapsed: pausedElapsed,
            creditsMoved:  creditsMoved
        )
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    // MARK: - End

    // Called when the session stops. Shows a frozen summary for 30 seconds,
    // then the Live Activity dismisses itself.
    static func end(finalElapsed: TimeInterval, creditsMoved: Double) {
        guard let activity = currentActivity else { return }
        // Clear the stored ID immediately — before the async Task runs — so
        // any subsequent update() or end() call during the 30-second dismissal
        // window correctly no-ops rather than targeting the ending activity.
        currentID = nil
        // isPaused = true freezes the timer display in the 30-second summary.
        let finalState = SessionActivityAttributes.ContentState(
            adjustedStart: Date(),          // not used when isPaused = true
            isPaused:      true,
            pausedElapsed: finalElapsed,
            creditsMoved:  creditsMoved
        )
        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: ActivityUIDismissalPolicy.after(Date().addingTimeInterval(30))
            )
        }
    }
}
