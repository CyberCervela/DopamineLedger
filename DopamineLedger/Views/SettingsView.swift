// SettingsView.swift
// First-pass settings sheet. Covers the items that change app behaviour
// today:
//   1. Chill mode — gates "Start session anyway" when a spender has debt
//   2. Notifications — permission status + path back when denied
//   3. Stop current session — global escape hatch (only when one is active)
//   4. Wipe all data — destructive reset for testing / fresh starts
//
// Future passes will add: theme switcher, IOT integration, friend sharing.
// See memory/step6_backlog.md for the roadmap and memory/notification_strategy.md
// for the design constraints around the notification row in particular.

import SwiftUI
import SwiftData
import UserNotifications
import UIKit

struct SettingsView: View {
    @Environment(\.theme)        private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    // Persisted via UserDefaults under the key "chillMode" — survives
    // launches, observed by any view that reads the same @AppStorage key.
    @AppStorage("chillMode") private var chillMode: Bool = false

    // Live queries so the Stop-session row appears only when there's
    // actually a running session, and the wipe action sees current state.
    @Query(filter: #Predicate<Session> { $0.endedAt == nil })
                                      private var activeSessions: [Session]

    // Confirmation alert for the destructive wipe. Two-step interaction
    // (tap row → confirm in alert) so a thumb-bump doesn't nuke data.
    @State private var showWipeConfirm: Bool = false

    // Cached notification authorization. Refreshed when the sheet appears
    // and whenever the app returns to the foreground (the user might have
    // toggled it in iOS Settings while we were backgrounded).
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined

    // Used to re-check notifStatus when the user comes back from iOS
    // Settings via the deep link — the app transitions through .active
    // again, which fires this observer.
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.xl) {
                    behaviourSection
                    notificationsSection
                    if !activeSessions.isEmpty {
                        activeSessionSection
                    }
                    dangerZoneSection
                }
                .padding(theme.spacing.lg)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .task { await refreshNotificationStatus() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await refreshNotificationStatus() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(theme.typography.bodyStrong)
                        .foregroundStyle(theme.colors.accent)
                }
            }
            .alert("Wipe all data?", isPresented: $showWipeConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Wipe everything", role: .destructive) { wipeAllData() }
            } message: {
                Text("This deletes every activity, session, debt, and quest, and resets your balance to 0. This cannot be undone.")
            }
        }
    }

    // MARK: - Sections

    private var behaviourSection: some View {
        sectionCard(title: "BEHAVIOUR") {
            // Toggle row. The caption explains the consequence in plain
            // language so the user doesn't have to remember what "chill"
            // means from the documentation.
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Toggle(isOn: $chillMode) {
                    Text("Chill mode")
                        .font(theme.typography.bodyStrong)
                        .foregroundStyle(theme.colors.textPrimary)
                }
                .tint(theme.colors.accent)
                Text(chillMode
                     ? "You can start a spender that's already in debt. Debt accrues at 2× rate."
                     : "Starting a spender with debt is blocked — repay first.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }
        }
    }

    // Notifications row. Three states based on the live UN authorization
    // status; the row always shows *something* actionable so a denied
    // state never leaves the user stuck without a path back. Copy is
    // intentionally generic ("Notifications") and purpose-oriented in
    // the caption, because the set of categories will grow as Health /
    // IOT / screen-time integrations land — see notification_strategy.md.
    private var notificationsSection: some View {
        sectionCard(title: "NOTIFICATIONS") {
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                HStack {
                    Text(notifStatusLabel)
                        .font(theme.typography.bodyStrong)
                        .foregroundStyle(notifStatusColor)
                    Spacer()
                    if let action = notifAction {
                        Button(action: action.handler) {
                            Text(action.label)
                                .font(theme.typography.button.weight(.semibold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, theme.spacing.md)
                                .padding(.vertical,   theme.spacing.sm)
                                .background(theme.colors.accent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Used to alert you about credit, debt, and connected-device events.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }
        }
    }

    // MARK: Notifications — derived display state

    private var notifStatusLabel: String {
        switch notifStatus {
        case .authorized, .provisional, .ephemeral: return "Notifications: Enabled"
        case .denied:                                return "Notifications: Disabled"
        case .notDetermined:                         return "Notifications: Not requested"
        @unknown default:                            return "Notifications: Unknown"
        }
    }

    private var notifStatusColor: Color {
        switch notifStatus {
        case .authorized, .provisional, .ephemeral: return theme.colors.positive
        case .denied:                                return theme.colors.negative
        default:                                     return theme.colors.textPrimary
        }
    }

    // Action button shown next to the status, or nil when no action is
    // applicable (e.g., already authorized).
    private struct NotifAction { let label: String; let handler: () -> Void }
    private var notifAction: NotifAction? {
        switch notifStatus {
        case .notDetermined:
            return NotifAction(label: "Request") {
                Task {
                    _ = await NotificationScheduler.ensurePermission()
                    await refreshNotificationStatus()
                }
            }
        case .denied:
            // iOS does not allow re-prompting once the user has denied.
            // The only path back is the system Settings app — deep-link
            // straight to our app's row so they don't have to scroll.
            return NotifAction(label: "Open iOS Settings", handler: openSystemSettings)
        default:
            return nil
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notifStatus = settings.authorizationStatus
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private var activeSessionSection: some View {
        sectionCard(title: "ACTIVE SESSION") {
            Button {
                stopActiveSession()
            } label: {
                HStack {
                    Text("Stop current session")
                        .font(theme.typography.bodyStrong)
                        .foregroundStyle(theme.colors.textPrimary)
                    Spacer()
                    Image(systemName: "stop.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(theme.colors.accent)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var dangerZoneSection: some View {
        sectionCard(title: "DANGER ZONE") {
            Button {
                showWipeConfirm = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                        Text("Wipe all data")
                            .font(theme.typography.bodyStrong)
                            .foregroundStyle(theme.colors.negative)
                        Text("Resets every activity, session, debt, quest, and balance.")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.colors.negative)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // Section chrome — small uppercase label + raised neumorphic card.
    // Pulled out so adding sections later stays a one-liner.
    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text(title)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .kerning(2)
            content()
                .padding(theme.spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
                .shadow(color: theme.colors.shadowLight, radius: 8, x: -5, y: -5)
                .shadow(color: theme.colors.shadowDark,  radius: 8, x:  5, y:  5)
        }
    }

    // MARK: - Actions

    private func stopActiveSession() {
        guard let session = activeSessions.first else { return }
        SessionFinalizer.finalize(session: session, in: context)
        dismiss()
    }

    // Delete every row of every user-facing model. The Ledger row is
    // deleted too; the home screen's .task runs fetchOrCreate(in:) on
    // next launch (and again on appearance), so a fresh zero-balance
    // ledger is recreated automatically.
    private func wipeAllData() {
        do {
            try context.delete(model: Session.self)
            try context.delete(model: ActivityDebt.self)
            try context.delete(model: Quest.self)
            try context.delete(model: Activity.self)
            try context.delete(model: Ledger.self)
            try context.save()
        } catch {
            // Wipe is best-effort; if SwiftData throws there's not much
            // we can recover at the view layer. Surface to the console
            // for debugging rather than crashing the app.
            print("SettingsView.wipeAllData failed: \(error)")
        }
        dismiss()
    }
}

#Preview {
    SettingsView()
        .environment(\.theme, NeuTheme())
        .modelContainer(for: [Activity.self, Session.self, ActivityDebt.self, Ledger.self, Quest.self],
                        inMemory: true)
}
