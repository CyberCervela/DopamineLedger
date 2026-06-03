// PrivacyPolicyView.swift
// Renders the privacy policy as native SwiftUI — no network required.
// Mirrors the content in docs/privacy.html exactly.
// A "View on GitHub" link at the bottom opens the hosted version.

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.theme)   private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text("Privacy Policy")
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colors.textPrimary)
                    Spacer()
                    NeuTextButton(
                        title:      "Done",
                        font:       theme.typography.bodyStrong,
                        foreground: theme.colors.accent,
                        action:     { dismiss() }
                    )
                }
                .padding(.horizontal, theme.spacing.lg)
                .padding(.top,        theme.spacing.md)
                .padding(.bottom,     theme.spacing.sm)

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.xl) {
                    header
                    Divider().overlay(theme.colors.divider)
                    section("Data we collect") {
                        bodyText("**None.** Dopamine Ledger does not collect, transmit, or share any data with anyone, including the developer.")
                    }
                    section("Data that lives on your device") {
                        bodyText("The app stores the following data locally using Apple's SwiftData framework (a local SQLite database that never leaves your device):")
                        VStack(alignment: .leading, spacing: theme.spacing.xs) {
                            bullet("Activities you create (name, icon, type, credit rate)")
                            bullet("Sessions you start and stop")
                            bullet("Your credit ledger (balance history, debt)")
                            bullet("Quests you create and complete")
                            bullet("Your in-app settings (theme, language, chill mode)")
                        }
                        bodyText("This data is yours. It is never uploaded anywhere. If you delete the app, all data is deleted with it.")
                    }
                    section("Notifications") {
                        bodyText("If you grant notification permission, the app schedules local notifications (a 5-minute warning and a zero-balance alarm during spender sessions). These are scheduled entirely on your device using Apple's UserNotifications framework. No notification content or schedule is ever sent to a server.")
                    }
                    section("Live Activities") {
                        bodyText("During a spender or charger session, the app can show a Live Activity on your Lock Screen and Dynamic Island. Live Activity data (session name, elapsed time, remaining balance) is processed entirely on your device by Apple's ActivityKit framework. It is not transmitted to any server.")
                    }
                    section("Third-party SDKs and analytics") {
                        bodyText("Dopamine Ledger contains no third-party SDKs, analytics libraries, crash reporters, or advertising frameworks. The app has no runtime dependencies beyond Apple's own frameworks.")
                    }
                    section("iCloud") {
                        bodyText("The app does not use iCloud sync. Data does not transfer between devices.")
                    }
                    section("Children") {
                        bodyText("Dopamine Ledger does not collect any data from any user, including children under 13.")
                    }
                    section("Changes to this policy") {
                        bodyText("If a future version of the app introduces any form of data collection, this policy will be updated before that version ships, and the change will be noted in the App Store release notes.")
                    }
                    Divider().overlay(theme.colors.divider)
                    section("Contact") {
                        bodyText("Questions about this policy:")
                        Link("cibercervela@pm.me", destination: URL(string: "mailto:cibercervela@pm.me")!)
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.accent)
                    }
                    githubLink
                }
                .padding(theme.spacing.lg)
            }
        }
        .presentationBackground(theme.colors.background)
    }

    // MARK: - Sub-views

    private var header: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text("Privacy Policy")
                .font(theme.typography.title)
                .foregroundStyle(theme.colors.textPrimary)
            Text("Dopamine Ledger — Last updated: 25 May 2026")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
            Text("Dopamine Ledger is a personal time-budget tracker. It runs entirely on your device. This policy explains exactly what data exists, where it lives, and who can see it.")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
        }
    }

    private var githubLink: some View {
        Link(destination: URL(string: "https://cybercervela.github.io/DopamineLedger/privacy.html")!) {
            HStack(spacing: theme.spacing.sm) {
                Image(systemName: "safari")
                    .font(.system(size: 15))
                Text("View on GitHub")
                    .font(theme.typography.bodyStrong)
            }
            .foregroundStyle(theme.colors.accent)
            .frame(maxWidth: .infinity)
            .padding(theme.spacing.md)
            .neuCard(.sm)
        }
        .padding(.bottom, theme.spacing.md)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func section(_ heading: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text(heading)
                .font(theme.typography.bodyStrong)
                .foregroundStyle(theme.colors.textPrimary)
            content()
        }
    }

    private func bodyText(_ text: String) -> some View {
        Text(.init(text))
            .font(theme.typography.body)
            .foregroundStyle(theme.colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: theme.spacing.sm) {
            Text("•")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
            Text(text)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    PrivacyPolicyView()
        .environment(\.theme, NeuTheme())
}
