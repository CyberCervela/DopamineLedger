// SettingsView.swift
// First-pass settings sheet. Covers the three items that change app
// behaviour today:
//   1. Chill mode — gates "Start session anyway" when a spender has debt
//   2. Stop current session — global escape hatch (only when one is active)
//   3. Wipe all data — destructive reset for testing / fresh starts
//
// Future passes will add: theme switcher, notification permission status,
// IOT integration, friend sharing (see memory/step6_backlog.md).

import SwiftUI
import SwiftData

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.xl) {
                    behaviourSection
                    if !activeSessions.isEmpty {
                        activeSessionSection
                    }
                    dangerZoneSection
                }
                .padding(theme.spacing.lg)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
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
