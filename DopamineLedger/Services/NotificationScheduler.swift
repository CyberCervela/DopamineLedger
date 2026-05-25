// Transplanted from round 1. Cleaned 2026-05-23.
// No direct test coverage — system-layer wrapper; the math behind it is
// tested via NotificationMath.

import Foundation
import UserNotifications

// MARK: - Foreground delivery

// iOS suppresses notifications silently when the app is in the foreground
// unless a UNUserNotificationCenterDelegate is wired up. This delegate
// opts in to banner + sound delivery for every notification that fires
// while the app is open — the primary case being the debt alarm firing
// while the user is watching SessionView.
//
// Set as delegate once in DopamineLedgerApp.init() via:
//   UNUserNotificationCenter.current().delegate = NotificationCenterDelegate.shared
final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCenterDelegate()
    private override init() {}

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// Wraps UNUserNotificationCenter for our specific use case: scheduling
// the 5-min warning + zero alarm at session start, and cancelling them
// on session stop.
//
// Why a thin wrapper?
// 1. Keeps SessionView free of UN boilerplate — call sites are clean.
// 2. Identifiers are namespaced consistently (warning./alarm. prefixes),
//    so we can cancel by sessionId without juggling strings in the view.
// 3. The pure math lives in NotificationMath; this layer is just the
//    glue to the system. Easier to reason about each piece.
enum NotificationScheduler {

    // Identifier prefixes — combined with a session UUID, they make
    // unique-per-session notification IDs we can cancel later.
    private static let warningPrefix = "session.warning."
    private static let alarmPrefix   = "session.alarm."

    // MARK: - Permission

    // Ask for permission if we haven't already. Returns true if we end up
    // authorized (either previously or just now). Safe to call repeatedly;
    // the system only shows the prompt the first time.
    static func ensurePermission() async -> Bool {
        let center   = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Scheduling

    // Schedule both notifications for a spender session.
    // Silently no-ops if math returns nil (e.g., zero balance) or if the
    // user has previously denied permission.
    static func scheduleSpenderSession(
        sessionId:     UUID,
        activityName:  String,
        balance:       Double,
        ratePerSecond: Double
    ) async {
        guard await ensurePermission() else { return }

        guard let times = NotificationMath.compute(
            currentBalance: balance,
            ratePerSecond:  ratePerSecond
        ) else { return }

        let center = UNUserNotificationCenter.current()

        // Zero alarm — always scheduled when we get past the math guard.
        let alarmContent = UNMutableNotificationContent()
        alarmContent.title = "\(activityName) balance hit zero"
        alarmContent.body  = "You're now spending at 2× the rate as debt."
        alarmContent.sound = .default
        // TODO: swap to a theme-aware sound when SoundPlayer lands.

        let alarmRequest = UNNotificationRequest(
            identifier: alarmPrefix + sessionId.uuidString,
            content:    alarmContent,
            trigger:    UNTimeIntervalNotificationTrigger(
                            timeInterval: max(1, times.alarmInSeconds),
                            repeats: false
                        )
        )
        try? await center.add(alarmRequest)

        // 5-minute warning — only if there's room for it.
        if let warningTime = times.warningInSeconds {
            let warningContent = UNMutableNotificationContent()
            warningContent.title = "\(activityName) — 5 minutes left"
            warningContent.body  = "Wrap up soon or you'll start accruing debt."
            warningContent.sound = .default

            let warningRequest = UNNotificationRequest(
                identifier: warningPrefix + sessionId.uuidString,
                content:    warningContent,
                trigger:    UNTimeIntervalNotificationTrigger(
                                timeInterval: max(1, warningTime),
                                repeats: false
                            )
            )
            try? await center.add(warningRequest)
        }
    }

    // MARK: - Cancellation

    // Cancel any pending warning + alarm for a specific session.
    // Idempotent — safe to call on sessions that never scheduled anything
    // (e.g., charger sessions, denied permission).
    static func cancelSession(sessionId: UUID) {
        let identifiers = [
            warningPrefix + sessionId.uuidString,
            alarmPrefix   + sessionId.uuidString,
        ]
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
