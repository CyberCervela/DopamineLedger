// SessionView.swift
// The active-session sheet. Shown while a session is running. The sheet can be
// swiped down to dismiss — doing so does NOT stop the session; it keeps running
// in the background and can be reopened from the pinned ACTIVE row.

import SwiftUI
import SwiftData

struct SessionView: View {
    @Environment(\.theme)          private var theme
    @Environment(\.modelContext)   private var context
    @Environment(\.dismiss)        private var dismiss
    @Environment(\.languageBundle) private var lBundle

    let session:  Session
    let activity: Activity

    @Binding var presented: Session?

    @State private var showNotInstalledAlert = false
    @State private var appStoreURL:           URL?

    @Query private var ledgers: [Ledger]
    // Balance at session start — the Ledger is only updated on finalize,
    // so this is the pre-session value throughout the session's lifetime.
    private var sessionStartBalance: Double { ledgers.first?.balance ?? 0 }

    private var kindColor: Color {
        activity.kind == .charger ? theme.colors.positive : theme.colors.negative
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            content
        }
    }

    private var content: some View {
        let elapsed       = session.elapsed
        // Use the session's frozen multiplier so the live display matches what
        // SessionFinalizer will compute at stop time.
        let creditsMoved  = activity.ratePerSecond * elapsed * session.timeMultiplier
        let paused        = session.isPaused
        let creditsCaptionKey = activity.kind == .charger ? "session.credits_earned_caption" : "session.credits_spent_caption"
        let statusKey     = paused ? "session.paused" : (activity.kind == .charger ? "session.charging" : "session.spending")

        // Spender live balance: how much of the starting balance is left, and
        // how much debt is accumulating at the 2× rate if we've gone past zero.
        let spenderRemaining = max(0, sessionStartBalance - creditsMoved)
        let spenderLiveDebt  = creditsMoved > sessionStartBalance
            ? (creditsMoved - sessionStartBalance) * 2
            : 0
        let isOverrun = activity.kind == .spender && creditsMoved > sessionStartBalance

        return VStack(spacing: theme.spacing.xxl) {

            Spacer()

            VStack(spacing: theme.spacing.md) {
                ZStack {
                    Circle()
                        .fill(theme.colors.surface)
                        .frame(width: 72, height: 72)
                        .shadow(color: theme.colors.shadowLight, radius: 10, x: -6, y: -6)
                        .shadow(color: theme.colors.shadowDark,  radius: 10, x:  6, y:  6)
                    // Mirror the ActivityRow fallback: use the chosen icon, or fall
                    // back to the semantic kind icon for pre-icon-picker activities.
                    (activity.iconName == "circle"
                        ? theme.icon(activity.kind == .charger ? .charger : .spender)
                        : IconResolver.activityIconImage(named: activity.iconName))
                        .font(.system(size: 28))
                        .foregroundStyle(isOverrun ? theme.colors.negative : kindColor)
                }
                Text(activity.name)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(lBundle.l(statusKey))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                    .kerning(2)
                    .textCase(.uppercase)
            }

            Text(creditsMoved.abbreviated)
                .font(.system(size: 64, weight: .light, design: .rounded).monospacedDigit())
                .foregroundStyle(paused ? theme.colors.textSecondary
                                        : isOverrun ? theme.colors.negative
                                        : activity.kind == .charger ? theme.colors.positive
                                        : theme.colors.textPrimary)
                .padding(.vertical, theme.spacing.md)

            VStack(spacing: theme.spacing.xs) {
                Text(lBundle.l(creditsCaptionKey).uppercased())
                    .font(theme.typography.caption)
                    .foregroundStyle(paused ? theme.colors.textSecondary : (isOverrun ? theme.colors.negative : kindColor))
                    .kerning(2)
                if session.timeMultiplier > 1.0 {
                    // Chargers: bonus (earn more) → green. Spenders: penalty (cost more) → red.
                    let peakKey = activity.kind == .charger ? "session.peak_bonus" : "session.peak_penalty"
                    Text(lBundle.l(peakKey).uppercased())
                        .font(theme.typography.caption)
                        .foregroundStyle(activity.kind == .charger ? theme.colors.positive : theme.colors.negative)
                        .kerning(2)
                }
                // Use the shared TimeInterval.formattedDuration so the elapsed
                // line matches every other duration in the app ("2 h 30 m").
                Text(elapsed.formattedDuration)
                    .font(theme.typography.bodyStrong)
                    .foregroundStyle(theme.colors.textSecondary)
                if activity.kind == .spender {
                    // Show remaining balance before zero, or live debt once overrun.
                    if isOverrun {
                        Text(String(format: lBundle.l("session.live_debt"),
                                    spenderLiveDebt.abbreviated))
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.negative)
                    } else {
                        Text(String(format: lBundle.l("session.balance_remaining"),
                                    spenderRemaining.abbreviated))
                            .font(theme.typography.caption)
                            .foregroundStyle(spenderRemaining < sessionStartBalance * 0.2
                                             ? theme.colors.negative
                                             : theme.colors.textSecondary)
                        if activity.ratePerSecond > 0 {
                            // Divide by the peak-adjusted rate so the estimate
                            // matches what SessionFinalizer will actually bill.
                            Text(String(format: lBundle.l("row.activity.burndown"),
                                        (spenderRemaining / (activity.ratePerSecond * session.timeMultiplier)).formattedDuration))
                                .font(theme.typography.caption)
                                .foregroundStyle(spenderRemaining < sessionStartBalance * 0.2
                                                 ? theme.colors.negative
                                                 : theme.colors.textSecondary)
                        }
                    }
                }
                Text(String(format: lBundle.l("session.rate"),
                            (activity.ratePerSecond * 60).abbreviated))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }

            Spacer()

            VStack(spacing: theme.spacing.md) {
                // Linked-app gatekeeper button — only shown when the activity has
                // a linked app configured. Appears above Pause/Stop so the user
                // opens the app consciously after the session is already running.
                if let scheme = activity.linkedAppScheme, !scheme.isEmpty,
                   let appName = activity.linkedAppName {
                    Button(action: openLinkedApp) {
                        HStack(spacing: theme.spacing.sm) {
                            // Arrow-up-right = "leaving to external app" convention on iOS.
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 15))
                            Text(String(format: lBundle.l("session.linked_app.open"), appName))
                                .font(theme.typography.button)
                                .kerning(2)
                                .textCase(.uppercase)
                        }
                        .foregroundStyle(theme.colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacing.md)
                        .neuCard(.sm)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: togglePause) {
                    Text(lBundle.l(paused ? "session.resume" : "session.pause"))
                        .font(theme.typography.button.weight(.semibold))
                        .kerning(4)
                        .textCase(.uppercase)
                        .foregroundStyle(paused ? theme.colors.positive : theme.colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacing.md)
                        .neuCard(.sm)
                }
                .buttonStyle(.plain)

                Button(action: stop) {
                    Text(lBundle.l("session.stop"))
                        .font(theme.typography.button.weight(.bold))
                        .kerning(4)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacing.lg)
                        .background(theme.colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
                        .shadow(color: theme.colors.shadowDark, radius: 8, x: 4, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacing.lg)
        }
        .padding(theme.spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.background.ignoresSafeArea())
        .alert(
            String(format: lBundle.l("session.linked_app.not_installed.title"),
                   activity.linkedAppName ?? ""),
            isPresented: $showNotInstalledAlert
        ) {
            if let url = appStoreURL {
                Button(lBundle.l("session.linked_app.not_installed.go")) {
                    UIApplication.shared.open(url)
                }
            }
            Button(lBundle.l("common.cancel"), role: .cancel) { }
        } message: {
            Text(lBundle.l("session.linked_app.not_installed.message"))
        }
        // Push a Live Activity credit update once per minute so the Dynamic Island
        // stays in sync between pause/resume events. Int(elapsed / 60) increments
        // each new minute; .task(id:) fires a fresh task every time id changes.
        // The guard prevents a spurious push while the session clock is frozen.
        .task(id: Int(elapsed / 60)) {
            guard !session.isPaused else { return }
            LiveActivityService.update(
                adjustedStart: session.startedAt.addingTimeInterval(session.totalPausedSeconds),
                isPaused:      false,
                pausedElapsed: 0,
                creditsMoved:  creditsMoved
            )
        }
    }

    // Opens the activity's linked app directly via its URL scheme.
    // Falls through to a "find on App Store" alert if the scheme doesn't resolve —
    // meaning the app isn't installed or the scheme changed between versions.
    private func openLinkedApp() {
        guard let schemeStr = activity.linkedAppScheme,
              let url = URL(string: schemeStr) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            appStoreURL = LinkedApp.catalog
                .first(where: { $0.id == schemeStr })
                .flatMap { URL(string: $0.appStoreURL) }
            showNotInstalledAlert = true
        }
    }

    private func togglePause() {
        if session.isPaused {
            session.resume()
            if activity.kind == .spender {
                let balance       = Ledger.fetchOrCreate(in: context).balance
                let creditsSpent  = activity.ratePerSecond * session.elapsed
                let remaining     = max(0, balance - creditsSpent)
                let sessionId     = session.id
                let activityName  = activity.name
                let rate          = activity.ratePerSecond
                Task {
                    await NotificationScheduler.scheduleSpenderSession(
                        sessionId:     sessionId,
                        activityName:  activityName,
                        balance:       remaining,
                        ratePerSecond: rate
                    )
                }
            }
            LiveActivityService.update(
                adjustedStart: session.startedAt.addingTimeInterval(session.totalPausedSeconds),
                isPaused:      false,
                pausedElapsed: 0,
                creditsMoved:  activity.ratePerSecond * session.elapsed * session.timeMultiplier
            )
        } else {
            let elapsedNow    = session.elapsed
            let adjustedStart = session.startedAt.addingTimeInterval(session.totalPausedSeconds)
            session.pause()
            NotificationScheduler.cancelSession(sessionId: session.id)
            LiveActivityService.update(
                adjustedStart: adjustedStart,
                isPaused:      true,
                pausedElapsed: elapsedNow,
                creditsMoved:  activity.ratePerSecond * elapsedNow * session.timeMultiplier
            )
        }
    }

    private func stop() {
        SessionFinalizer.finalize(session: session, in: context)
        presented = nil
        dismiss()
    }
}
