// Transplanted from round 1. Cleaned 2026-05-23.
// Test coverage: 5 cases in DopamineLedgerTests
// (testNotificationMath* — both-when-plenty, skips-warning-at-5min-exactly,
//  skips-when-too-short, nil-for-empty-balance, nil-for-zero-rate).

import Foundation

// Pure-function math for "when should the warning and alarm fire for a
// spender session?" — same pattern as SessionMath and RepayMath. Keeping
// the time computation separate from UNUserNotificationCenter calls means
// we can unit-test the schedule decisions without touching the system layer.

struct NotificationTimes: Equatable {
    // Seconds-from-now until the 5-minute warning should fire.
    // nil = don't schedule a warning (e.g., session would zero out in <5min).
    var warningInSeconds: TimeInterval?
    // Seconds-from-now until the zero-balance alarm should fire.
    var alarmInSeconds:   TimeInterval
}

enum NotificationMath {

    // The warning fires WARNING_LEAD_SECONDS before the alarm.
    static let warningLeadSeconds: TimeInterval = 5 * 60   // 5 minutes

    // Returns scheduling times for a spender session, or nil if no
    // notifications should be scheduled at all (defensive — current product
    // rules prevent reaching the nil-returning cases, but the function is
    // robust to bad inputs).
    //
    // - Pre-condition (enforced by SessionView's empty-balance block):
    //   currentBalance > 0 when a spender session starts. If this is
    //   violated we return nil rather than scheduling negative-time alarms.
    static func compute(
        currentBalance: Double,
        ratePerSecond:  Double
    ) -> NotificationTimes? {
        // Defensive: bad inputs → no scheduling.
        guard currentBalance > 0, ratePerSecond > 0 else { return nil }

        // The alarm fires exactly when the balance would hit zero.
        let timeUntilZero = currentBalance / ratePerSecond

        // The warning fires 5 minutes earlier — IF there's room for it.
        // If the session would zero out in less than 5 minutes, skip the
        // warning entirely (we don't want a notification firing in the past
        // or simultaneously with the alarm).
        let warningTime = timeUntilZero - warningLeadSeconds

        return NotificationTimes(
            warningInSeconds: warningTime > 0 ? warningTime : nil,
            alarmInSeconds:   timeUntilZero
        )
    }
}
