// SettingsView.swift
// Settings sheet. Covers:
//   1. Appearance — theme picker
//   2. Language — in-app language switcher (takes effect instantly, no restart)
//   3. Behaviour — chill mode toggle
//   4. Notifications — permission status + path to iOS Settings
//   5. Active Session — global stop escape hatch
//   6. Danger Zone — destructive data wipe

import SwiftUI
import SwiftData
import UserNotifications
import UIKit

struct SettingsView: View {
    @Environment(\.theme)          private var theme
    @Environment(\.modelContext)   private var context
    @Environment(\.dismiss)        private var dismiss
    @Environment(\.languageBundle) private var lBundle

    @AppStorage("chillMode")    private var chillMode:    Bool   = false
    @AppStorage("themeId")      private var themeId:      String = "neu"
    // Writing languageCode here re-injects the bundle in DopamineLedgerApp,
    // so the whole view hierarchy re-renders in the new language immediately.
    @AppStorage("languageCode") private var languageCode: String = "en"

    @Query(filter: #Predicate<Session> { $0.endedAt == nil })
                                      private var activeSessions: [Session]

    @State private var showPrivacyPolicy: Bool = false
    @State private var activeAlert: SettingsAlert? = nil

    private enum SettingsAlert: Identifiable {
        case wipe, mailFallback
        var id: Self { self }
    }
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text(lBundle.l("settings.title"))
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colors.textPrimary)
                    Spacer()
                    NeuTextButton(
                        title:      lBundle.l("common.done"),
                        font:       theme.typography.bodyStrong,
                        foreground: theme.colors.accent,
                        action:     { dismiss() }
                    )
                }
                .padding(.horizontal, theme.spacing.lg)
                .padding(.top,        theme.spacing.md)
                .padding(.bottom,     theme.spacing.sm)

                ScrollView {
                    VStack(spacing: theme.spacing.xl) {
                        appearanceSection
                        languageSection
                        behaviourSection
                        notificationsSection
                        if !activeSessions.isEmpty {
                            activeSessionSection
                        }
                        aboutSection
                        dangerZoneSection
                    }
                    .padding(theme.spacing.lg)
                }
        }
        .presentationBackground(theme.colors.background)
        .task { await refreshNotificationStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshNotificationStatus() }
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .mailFallback:
                return Alert(
                    title: Text("Send feedback"),
                    message: Text("cibercervela@pm.me"),
                    primaryButton: .default(Text("Copy address")) {
                        UIPasteboard.general.string = "cibercervela@pm.me"
                    },
                    secondaryButton: .cancel(Text(lBundle.l("common.cancel")))
                )
            case .wipe:
                return Alert(
                    title: Text(lBundle.l("alert.wipe.title")),
                    message: Text(lBundle.l("alert.wipe.message")),
                    primaryButton: .destructive(Text(lBundle.l("alert.wipe.confirm"))) { wipeAllData() },
                    secondaryButton: .cancel(Text(lBundle.l("common.cancel")))
                )
            }
        }
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        sectionCard(title: lBundle.l("settings.section.appearance")) {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                ForEach(availableThemes, id: \.id) { themeOption in
                    themeRow(themeOption)
                }
            }
        }
    }

    private var availableThemes: [any Theme] {
        ThemeRegistry.all.filter { $0.id != "pixelArt" }
    }

    @ViewBuilder
    private func themeRow(_ option: any Theme) -> some View {
        let isActive = option.id == themeId
        Button {
            themeId = option.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                    Text(option.displayName)
                        .font(theme.typography.bodyStrong)
                        .foregroundStyle(theme.colors.textPrimary)
                    Text(captionForTheme(option))
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.colors.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func captionForTheme(_ t: any Theme) -> String {
        switch t.id {
        case "neu":      return lBundle.l("settings.theme.neu")
        case "system":   return lBundle.l("settings.theme.system")
        case "pixelArt": return lBundle.l("settings.theme.pixelart")
        default:         return ""
        }
    }

    // Language picker. Each row shows the language's native name so the user
    // can recognise their target language even before switching. Writing to
    // @AppStorage("languageCode") propagates back to DopamineLedgerApp, which
    // re-injects the bundle and re-renders the whole hierarchy — instant switch.
    // CJK languages are prepared in the string catalog but hidden from the
    // picker until a native speaker can verify the translations.
    private let visibleLanguages: [SupportedLanguage] = [.en, .fr, .de, .es]

    private var languageSection: some View {
        sectionCard(title: lBundle.l("settings.section.language")) {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                ForEach(visibleLanguages) { lang in
                    languageRow(lang)
                }
            }
        }
    }

    @ViewBuilder
    private func languageRow(_ lang: SupportedLanguage) -> some View {
        let isActive = lang.rawValue == languageCode
        Button {
            languageCode = lang.rawValue
        } label: {
            HStack {
                Text(lang.displayName)
                    .font(theme.typography.bodyStrong)
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.colors.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var behaviourSection: some View {
        sectionCard(title: lBundle.l("settings.section.behaviour")) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Toggle(isOn: $chillMode) {
                    Text(lBundle.l("settings.chill.title"))
                        .font(theme.typography.bodyStrong)
                        .foregroundStyle(theme.colors.textPrimary)
                }
                .tint(theme.colors.accent)
                Text(lBundle.l(chillMode ? "settings.chill.on" : "settings.chill.off"))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }
        }
    }

    private var notificationsSection: some View {
        sectionCard(title: lBundle.l("settings.section.notifications")) {
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
                Text(lBundle.l("settings.notif.caption"))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }
        }
    }

    private var notifStatusLabel: String {
        switch notifStatus {
        case .authorized, .provisional, .ephemeral: return lBundle.l("settings.notif.enabled")
        case .denied:                                return lBundle.l("settings.notif.disabled")
        case .notDetermined:                         return lBundle.l("settings.notif.not_determined")
        @unknown default:                            return lBundle.l("settings.notif.unknown")
        }
    }

    private var notifStatusColor: Color {
        switch notifStatus {
        case .authorized, .provisional, .ephemeral: return theme.colors.positive
        case .denied:                                return theme.colors.negative
        default:                                     return theme.colors.textPrimary
        }
    }

    private struct NotifAction { let label: String; let handler: () -> Void }
    private var notifAction: NotifAction? {
        switch notifStatus {
        case .notDetermined:
            return NotifAction(label: lBundle.l("settings.notif.request")) {
                Task {
                    _ = await NotificationScheduler.ensurePermission()
                    await refreshNotificationStatus()
                }
            }
        case .denied:
            return NotifAction(label: lBundle.l("settings.notif.open_settings"),
                               handler: openSystemSettings)
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
        sectionCard(title: lBundle.l("settings.section.active_session")) {
            Button {
                stopActiveSession()
            } label: {
                HStack {
                    Text(lBundle.l("settings.active_session.stop"))
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
        sectionCard(title: lBundle.l("settings.section.danger_zone")) {
            Button {
                activeAlert = .wipe
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                        Text(lBundle.l("settings.wipe.title"))
                            .font(theme.typography.bodyStrong)
                            .foregroundStyle(theme.colors.negative)
                        Text(lBundle.l("settings.wipe.caption"))
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

    private var aboutSection: some View {
        sectionCard(title: lBundle.l("settings.section.about")) {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                HStack {
                    Text(lBundle.l("settings.about.version"))
                        .font(theme.typography.bodyStrong)
                        .foregroundStyle(theme.colors.textPrimary)
                    Spacer()
                    Text(appVersion)
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)
                }

                Divider()

                Button {
                    let url = URL(string: "mailto:cibercervela@pm.me")!
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        activeAlert = .mailFallback
                    }
                } label: {
                    aboutLinkRow(lBundle.l("settings.about.contact"))
                }
                .buttonStyle(.plain)

                Divider()

                Button { showPrivacyPolicy = true } label: {
                    aboutLinkRow(lBundle.l("settings.about.privacy"))
                }
                .buttonStyle(.plain)

                Divider()

                Link(destination: URL(string: "https://github.com/CyberCervela/DopamineLedger")!) {
                    aboutLinkRow(lBundle.l("settings.about.repo"))
                }
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
        return "\(v) (\(b))"
    }

    @ViewBuilder
    private func aboutLinkRow(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(theme.typography.bodyStrong)
                .foregroundStyle(theme.colors.textPrimary)
            Spacer()
            Text("›")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
        }
        .contentShape(Rectangle())
    }

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

    private func wipeAllData() {
        do {
            try context.delete(model: Session.self)
            try context.delete(model: ActivityDebt.self)
            try context.delete(model: Quest.self)
            try context.delete(model: Activity.self)
            try context.delete(model: Ledger.self)
            try context.save()
        } catch {
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
