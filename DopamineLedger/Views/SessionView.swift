// SessionView.swift
// The active-session sheet. Shown while a session is running; the only way
// out is the STOP button (swipe-to-dismiss is disabled so users can't
// orphan a running session by accident).
//
// Timing model: the `Session` model computes elapsed seconds from
// timestamps on every read (see Session.elapsed). That means we don't run
// a background timer — we just re-render the view once per second via
// TimelineView, and the elapsed value is naturally accurate. Backgrounding
// the app, locking the screen, killing the process — none of it loses time.

import SwiftUI
import SwiftData

struct SessionView: View {
    @Environment(\.theme)        private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    let session:  Session
    let activity: Activity

    // Bound by the parent so we can clear it after STOP — dismiss() alone
    // won't suffice because the sheet is item-driven.
    @Binding var presented: Session?

    private var kindColor: Color {
        activity.kind == .charger ? theme.colors.positive : theme.colors.negative
    }

    private var verb: String {
        activity.kind == .charger ? "earned" : "spent"
    }

    var body: some View {
        // TimelineView re-evaluates its closure on a schedule. Combined with
        // session.elapsed (which derives from Date() on every read), the
        // clock face ticks each second without a manual Timer.
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            content
        }
    }

    private var content: some View {
        // While paused, session.elapsed is frozen at the pause instant, so
        // both the clock and the credits readout naturally stop ticking.
        let elapsed       = session.elapsed
        let creditsMoved  = activity.ratePerSecond * elapsed
        let paused        = session.isPaused

        return VStack(spacing: theme.spacing.xxl) {

            Spacer()

            // Header — activity name + kind icon in a neumorphic disc.
            VStack(spacing: theme.spacing.md) {
                ZStack {
                    Circle()
                        .fill(theme.colors.surface)
                        .frame(width: 72, height: 72)
                        .shadow(color: theme.colors.shadowLight, radius: 10, x: -6, y: -6)
                        .shadow(color: theme.colors.shadowDark,  radius: 10, x:  6, y:  6)
                    theme.icon(activity.kind == .charger ? .charger : .spender)
                        .font(.system(size: 28))
                        .foregroundStyle(kindColor)
                }
                Text(activity.name)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(paused
                     ? "Paused"
                     : (activity.kind == .charger ? "Charging" : "Spending"))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                    .kerning(2)
                    .textCase(.uppercase)
            }

            // Big elapsed-time clock. Dims to secondary text colour while
            // paused so the freeze is visually obvious in addition to the
            // text not advancing.
            Text(formatElapsed(elapsed))
                .font(.system(size: 64, weight: .light, design: .rounded).monospacedDigit())
                .foregroundStyle(paused ? theme.colors.textSecondary : theme.colors.textPrimary)
                .padding(.vertical, theme.spacing.md)

            // Live credits readout. Format with one decimal to make the
            // motion visible second-to-second (rate is per-second so each
            // tick changes the fractional digit, signalling "this is live").
            VStack(spacing: theme.spacing.xs) {
                Text("\(creditsMoved, format: .number.precision(.fractionLength(1))) credits \(verb)")
                    .font(theme.typography.bodyStrong)
                    .foregroundStyle(paused ? theme.colors.textSecondary : kindColor)
                Text("at \(activity.ratePerSecond * 60, format: .number.precision(.fractionLength(1))) cr / min")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }

            Spacer()

            // Actions: PAUSE/RESUME above STOP. Pause is secondary visual
            // weight (raised neumorphic, not filled) so STOP keeps the
            // primary affordance.
            VStack(spacing: theme.spacing.md) {
                Button(action: togglePause) {
                    Text(paused ? "RESUME" : "PAUSE")
                        .font(theme.typography.button.weight(.semibold))
                        .kerning(4)
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
                    Text("STOP")
                        .font(theme.typography.button.weight(.bold))
                        .kerning(4)
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
        // Disable swipe-down-to-dismiss so an in-progress session can't be
        // orphaned by accident. STOP is the only exit.
        .interactiveDismissDisabled()
    }

    // MARK: - Actions

    private func togglePause() {
        if session.isPaused {
            session.resume()
            // Reschedule spender notifications against the *remaining* balance.
            // Ledger.balance is untouched during a session (SessionFinalizer
            // applies the delta only on stop), so subtracting credits-spent-
            // so-far from the current balance gives us the right remaining time.
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
        } else {
            session.pause()
            // Cancel scheduled notifications — they'd otherwise fire at the
            // original wall-clock time, ignoring the pause.
            NotificationScheduler.cancelSession(sessionId: session.id)
        }
    }

    private func stop() {
        SessionFinalizer.finalize(session: session, in: context)
        // Clear the parent's binding to drop the sheet. dismiss() alone
        // wouldn't be enough since the sheet is item-driven on this binding.
        presented = nil
        dismiss()
    }

    // Format seconds as HH:MM:SS, dropping the hour segment under an hour
    // so a short session reads "12:34" instead of "00:12:34" — feels less
    // medical / more conversational.
    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h     = total / 3600
        let m     = (total % 3600) / 60
        let s     = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}
