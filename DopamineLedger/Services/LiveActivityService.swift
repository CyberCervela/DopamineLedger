// LiveActivityService.swift
// Manages the one Live Activity that mirrors an active session.
//
// All methods are unconditionally callable — they silently no-op when
// Live Activities are unavailable or the device doesn't support them.
// The rest of the app never needs to guard before calling in.
//
// Exactly one Live Activity is active at a time (enforced by the
// one-session-globally rule in the main app UI), so we always operate
// on ActivityKit.Activity<SessionActivityAttributes>.activities.first.

import ActivityKit
import Foundation

@MainActor
enum LiveActivityService {

    // MARK: - Start

    // Called when a new session begins. Requests a new Live Activity.
    static func start(
        activityName:  String,
        activityKind:  ActivityKind,
        ratePerSecond: Double,
        startedAt:     Date
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

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

        try? ActivityKit.Activity<SessionActivityAttributes>.request(
            attributes: attributes,
            content:    ActivityContent(state: initialState, staleDate: nil)
        )
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
        guard let activity = ActivityKit.Activity<SessionActivityAttributes>.activities.first else { return }
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
        guard let activity = ActivityKit.Activity<SessionActivityAttributes>.activities.first else { return }
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
