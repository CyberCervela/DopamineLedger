// SessionLiveActivity.swift
// Renders a running session in three Live Activity display contexts:
//   - Lock Screen / Notification Center banner
//   - Dynamic Island compact (the small pill)
//   - Dynamic Island expanded (long-press balloon)
//
// This file runs inside the widget extension process — it has NO access
// to SwiftData, the main app's @Environment, or the active Theme. All
// rendering uses system colors and SF Symbols via SessionActivityAttributes.

import ActivityKit
import WidgetKit
import SwiftUI

struct SessionLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in

            // Lock Screen / Notification Center view.
            // Shown on the Lock Screen while the session is active, and as
            // a banner on the home screen when the app is not in the foreground.
            LockScreenView(attrs: context.attributes, state: context.state)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

        } dynamicIsland: { context in

            DynamicIsland {
                // Expanded content — long-pressing the Dynamic Island pill.
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.activityName)
                            .font(.headline)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: context.attributes.isCharger ? "bolt.fill" : "hourglass")
                            .foregroundStyle(context.attributes.isCharger ? .green : .red)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedView(state: context.state)
                        .font(.title2.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        let isCharger = context.attributes.isCharger
                        Image(systemName: isCharger ? "plus.circle.fill" : "minus.circle.fill")
                            .foregroundStyle(isCharger ? .green : .red)
                        Text("\(context.state.creditsMoved, format: .number.precision(.fractionLength(1))) cr \(isCharger ? "earned" : "spent")")
                            .font(.subheadline)
                        Spacer()
                        Text("Open app to stop")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

            } compactLeading: {
                // Icon + activity name side-by-side. The name truncates if long;
                // the icon alone still identifies the kind when space is tight.
                HStack(spacing: 3) {
                    Image(systemName: context.attributes.isCharger ? "bolt.fill" : "hourglass")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(context.attributes.isCharger ? .green : .red)
                    Text(context.attributes.activityName)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                }

            } compactTrailing: {
                // Tiny trailing segment: elapsed time.
                ElapsedView(state: context.state)
                    .font(.caption2.monospacedDigit())

            } minimal: {
                // When two Live Activities compete for space, only the icon.
                Image(systemName: context.attributes.isCharger ? "bolt.fill" : "hourglass")
                    .foregroundStyle(context.attributes.isCharger ? .green : .red)
            }
        }
    }
}

// MARK: - Lock Screen view

private struct LockScreenView: View {
    let attrs: SessionActivityAttributes
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {

            // Left column: icon, activity name, state label.
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: attrs.isCharger ? "bolt.fill" : "hourglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(attrs.isCharger ? .green : .red)
                    Text(attrs.activityName)
                        .font(.headline)
                        .lineLimit(1)
                }
                Text(state.isPaused
                     ? "Paused"
                     : (attrs.isCharger ? "Charging" : "Spending"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(1)
            }

            Spacer()

            // Right column: elapsed timer, rate.
            VStack(alignment: .trailing, spacing: 4) {
                ElapsedView(state: state)
                    .font(.title2.monospacedDigit().weight(.light))
                // Rate is static so it never needs an update push.
                Text("\(attrs.ratePerSecond * 60, format: .number.precision(.fractionLength(1))) cr/min")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(attrs.isCharger ? .green : .red)
            }
        }
        // Tints the lock-screen banner background toward the kind color.
        .activityBackgroundTint(attrs.isCharger ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
    }
}

// MARK: - Shared elapsed view

// Switches between a live auto-ticking timer and a frozen value on pause.
// Text(date, style: .timer) is special: it updates its display autonomously
// without needing a push from the main app — it's driven by the system clock.
private struct ElapsedView: View {
    let state: SessionActivityAttributes.ContentState

    var body: some View {
        if state.isPaused {
            // Frozen value — show as plain text so it clearly isn't ticking.
            Text(formatElapsed(state.pausedElapsed))
                .foregroundStyle(.secondary)
        } else {
            // Auto-ticking: counts seconds since adjustedStart.
            // adjustedStart = session.startedAt + totalPausedSeconds, so
            // Date.now − adjustedStart equals the session's working elapsed time.
            Text(state.adjustedStart, style: .timer)
        }
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Convenience

private extension SessionActivityAttributes {
    var isCharger: Bool { activityKind == "charger" }
}
