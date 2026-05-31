// SessionView.swift
// The active-session sheet. Shown while a session is running; the only way
// out is the STOP button (swipe-to-dismiss is disabled so users can't
// orphan a running session by accident).

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
        let creditsKey        = activity.kind == .charger ? "session.credits_earned" : "session.credits_spent"
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

            Text(creditsMoved.formatted(.number.precision(.fractionLength(0...1))))
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
                Text(formatElapsed(elapsed))
                    .font(theme.typography.bodyStrong)
                    .foregroundStyle(theme.colors.textSecondary)
                if activity.kind == .spender {
                    // Show remaining balance before zero, or live debt once overrun.
                    if isOverrun {
                        Text(String(format: lBundle.l("session.live_debt"),
                                    spenderLiveDebt.formatted(.number.precision(.fractionLength(0...1)))))
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.negative)
                    } else {
                        Text(String(format: lBundle.l("session.balance_remaining"),
                                    spenderRemaining.formatted(.number.precision(.fractionLength(0...1)))))
                            .font(theme.typography.caption)
                            .foregroundStyle(spenderRemaining < sessionStartBalance * 0.2
                                             ? theme.colors.negative
                                             : theme.colors.textSecondary)
                        if activity.ratePerSecond > 0 {
                            Text(String(format: lBundle.l("row.activity.burndown"),
                                        formatDuration(spenderRemaining / activity.ratePerSecond)))
                                .font(theme.typography.caption)
                                .foregroundStyle(spenderRemaining < sessionStartBalance * 0.2
                                                 ? theme.colors.negative
                                                 : theme.colors.textSecondary)
                        }
                    }
                }
                Text(String(format: lBundle.l("session.rate"),
                            (activity.ratePerSecond * 60).formatted(.number.precision(.fractionLength(0...1)))))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }

            Spacer()

            VStack(spacing: theme.spacing.md) {
                Button(action: togglePause) {
                    Text(lBundle.l(paused ? "session.resume" : "session.pause"))
                        .font(theme.typography.button.weight(.semibold))
                        .kerning(4)
                        .textCase(.uppercase)
                        .foregroundStyle(paused ? theme.colors.positive : theme.colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacing.md)
                        .background(theme.colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
                        .shadow(color: theme.colors.shadowLight, radius: 6, x: -4, y: -4)
                        .shadow(color: theme.colors.shadowDark,  radius: 6, x:  4, y:  4)
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

    private func formatDuration(_ seconds: Double) -> String {
        let totalMins = Int(seconds / 60)
        if totalMins < 1 { return "< 1 min" }
        if totalMins < 60 { return "\(totalMins) min" }
        let hours = totalMins / 60
        let mins  = totalMins % 60
        return mins == 0 ? "\(hours) h" : "\(hours) h \(mins) m"
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h     = total / 3600
        let m     = (total % 3600) / 60
        if h > 0 { return m > 0 ? "\(h)h \(m) min" : "\(h)h" }
        return m > 0 ? "\(m) min" : "< 1 min"
    }
}
