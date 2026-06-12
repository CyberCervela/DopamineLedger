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

    @AppStorage("chillMode")       private var chillMode:       Bool   = false
    @AppStorage("themeId")         private var themeId:         String = "neu"
    // Writing languageCode here re-injects the bundle in DopamineLedgerApp,
    // so the whole view hierarchy re-renders in the new language immediately.
    @AppStorage("languageCode")    private var languageCode:    String = "en"
    @AppStorage("peakEnabled")     private var peakEnabled:     Bool   = false
    @AppStorage("peakStartHour")   private var peakStartHour:   Int    = 6
    @AppStorage("peakStartMinute") private var peakStartMinute: Int    = 0

    @Query(filter: #Predicate<Session> { $0.endedAt == nil })
                                      private var activeSessions: [Session]

    @State private var showPrivacyPolicy: Bool = false
    @State private var activeAlert: SettingsAlert? = nil
    @State private var isSharePresented: Bool   = false
    @State private var shareURL:         URL?   = nil
    @State private var isImporting:      Bool   = false
    @State private var pendingImport:    ExportData? = nil

    private enum SettingsAlert: Identifiable {
        case wipe, mailFallback, importConfirm, importError
        #if DEBUG
        case debugSeed
        #endif
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
                        peakHoursSection
                        notificationsSection
                        if !activeSessions.isEmpty {
                            activeSessionSection
                        }
                        aboutSection
                        legalSection
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
        // Share sheet for export — UIActivityViewController wrapped in SwiftUI
        .sheet(isPresented: $isSharePresented, onDismiss: { shareURL = nil }) {
            if let url = shareURL {
                ShareSheetView(url: url)
            }
        }
        // File picker for import — .json type filter matches our backup files
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                if let data = DataExporter.decodeBackup(from: url) {
                    pendingImport = data
                    activeAlert = .importConfirm
                } else {
                    activeAlert = .importError
                }
            case .failure:
                activeAlert = .importError
            }
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .mailFallback:
                return Alert(
                    title: Text(lBundle.l("alert.feedback.title")),
                    message: Text("cibercervela@pm.me"),
                    primaryButton: .default(Text(lBundle.l("alert.feedback.copy"))) {
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
            case .importConfirm:
                return Alert(
                    title: Text(lBundle.l("alert.import.title")),
                    message: Text(lBundle.l("alert.import.message")),
                    primaryButton: .destructive(Text(lBundle.l("alert.import.confirm"))) {
                        guard let data = pendingImport else { return }
                        do {
                            try DataExporter.applyImport(data, context: context)
                            dismiss()
                        } catch {
                            pendingImport = nil
                            activeAlert = .importError
                        }
                    },
                    secondaryButton: .cancel(Text(lBundle.l("common.cancel")))
                )
            case .importError:
                return Alert(
                    title: Text(lBundle.l("alert.import.error")),
                    message: Text(lBundle.l("alert.import.error.message")),
                    dismissButton: .default(Text(lBundle.l("common.done")))
                )
            #if DEBUG
            case .debugSeed:
                return Alert(
                    title: Text("Load Test Data?"),
                    message: Text("This will replace all current data with the built-in seed dataset."),
                    primaryButton: .destructive(Text("Load")) {
                        do { try DebugSeeder.forceSeed(in: context) } catch {}
                    },
                    secondaryButton: .cancel(Text(lBundle.l("common.cancel")))
                )
            #endif
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
    // All seven languages — including the three CJK ones — are active in the
    // picker. CJK was activated after PM review (DECISIONS.md D-007): the user, a
    // native French speaker fluent in two of the three CJK languages, reviewed and
    // accepted the translation quality.
    private let visibleLanguages: [SupportedLanguage] = [.en, .fr, .de, .es, .zhHans, .ja, .ko]

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

    // Maps the two integer @AppStorage keys (peakStartHour, peakStartMinute)
    // to a single Date for DatePicker, then unpacks on write. Using a Binding
    // avoids a separate @State mirror that could drift out of sync.
    private var peakStartBinding: Binding<Date> {
        Binding(
            get: {
                var comps        = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                comps.hour       = peakStartHour
                comps.minute     = peakStartMinute
                comps.second     = 0
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { date in
                peakStartHour   = Calendar.current.component(.hour,   from: date)
                peakStartMinute = Calendar.current.component(.minute, from: date)
            }
        )
    }

    private var peakHoursSection: some View {
        let end = PeakHoursService.peakEnd(startHour: peakStartHour, startMinute: peakStartMinute)
        let endStr   = String(format: "%02d:%02d", end.hour, end.minute)
        let startStr = String(format: "%02d:%02d", peakStartHour, peakStartMinute)
        return sectionCard(title: lBundle.l("settings.section.peak_hours")) {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                Toggle(isOn: $peakEnabled) {
                    Text(lBundle.l("settings.peak.title"))
                        .font(theme.typography.bodyStrong)
                        .foregroundStyle(theme.colors.textPrimary)
                }
                .tint(theme.colors.accent)

                if peakEnabled {
                    Divider()
                    // Compact hour-and-minute picker. The wheel style would take
                    // too much vertical space inside the card.
                    DatePicker("", selection: peakStartBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    Text(String(format: lBundle.l("settings.peak.window"), startStr, endStr))
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.positive)
                }

                Text(lBundle.l("settings.peak.nudge"))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
            VStack(spacing: 0) {
                // Export
                Button {
                    if let url = DataExporter.exportToFile(context: context) {
                        shareURL = url
                        isSharePresented = true
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                            Text(lBundle.l("settings.export.title"))
                                .font(theme.typography.bodyStrong)
                                .foregroundStyle(theme.colors.textPrimary)
                            Text(lBundle.l("settings.export.caption"))
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().padding(.vertical, theme.spacing.sm)

                // Import
                Button { isImporting = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                            Text(lBundle.l("settings.import.title"))
                                .font(theme.typography.bodyStrong)
                                .foregroundStyle(theme.colors.textPrimary)
                            Text(lBundle.l("settings.import.caption"))
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().padding(.vertical, theme.spacing.sm)

                // DEBUG: Load Test Data — reads seed-data.json from the app bundle
                // via the same import code path as a real user restore. Only compiled
                // in DEBUG builds; never visible to App Store users.
                #if DEBUG
                Button {
                    activeAlert = .debugSeed
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                            Text("Load Test Data")
                                .font(theme.typography.bodyStrong)
                                .foregroundStyle(theme.colors.accent)
                            Text("DEBUG — replaces all data with seed-data.json")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "ladybug")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.colors.accent)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().padding(.vertical, theme.spacing.sm)
                #endif

                // Wipe (existing)
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
                    // We deliberately do NOT gate this on `canOpenURL`. Since iOS 9
                    // that check returns false for any scheme not declared in
                    // LSApplicationQueriesSchemes, and `mailto` isn't declared here —
                    // so it always failed and every user got the fallback alert.
                    // `open(_:options:completionHandler:)` needs no such declaration;
                    // it actually attempts the launch and reports success async on the
                    // main queue, so we only fall back to copy-the-address when it can't
                    // open (e.g. Mail uninstalled). Setting @State here is safe — the
                    // completion runs on main.
                    UIApplication.shared.open(url, options: [:]) { success in
                        if !success {
                            activeAlert = .mailFallback
                        }
                    }
                } label: {
                    aboutLinkRow(lBundle.l("settings.about.contact"))
                }
                .buttonStyle(.plain)

                Divider()

                Link(destination: URL(string: "https://github.com/CyberCervela/DopamineLedger")!) {
                    aboutLinkRow(lBundle.l("settings.about.repo"))
                }
            }
        }
    }

    // Legal section: disclaimer notice + privacy policy link.
    // Separated from About so the About card stays focused on version/contact/repo
    // and the legal text has its own clearly-labelled home — easier for Apple review
    // and users to find.
    private var legalSection: some View {
        sectionCard(title: lBundle.l("settings.section.legal")) {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                Text(lBundle.l("settings.legal.disclaimer"))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Button { showPrivacyPolicy = true } label: {
                    aboutLinkRow(lBundle.l("settings.about.privacy"))
                }
                .buttonStyle(.plain)
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
                .neuCard()
        }
    }

    // MARK: - Actions

    private func stopActiveSession() {
        guard let session = activeSessions.first else { return }
        SessionFinalizer.finalize(session: session, in: context)
        dismiss()
    }

    private func wipeAllData() {
        // F-11: a wipe that just deletes the Session rows leaves orphaned system UI
        // behind — the Live Activity keeps ticking on the Lock Screen forever, and the
        // scheduled "balance empty" notifications still fire later against data that no
        // longer exists. So before deleting anything, tear that system UI down.
        //
        // We deliberately do NOT route this through SessionFinalizer: finalize() would
        // APPLY this partial session's credits to the ledger — but that ledger is about
        // to be deleted, so those writes are pointless, and the user asked to delete
        // everything, not to bank an in-flight session. Cancel notifications + end the
        // Live Activity + delete is the honest reading of "delete all data".
        let activeFetch = FetchDescriptor<Session>(predicate: #Predicate { $0.endedAt == nil })
        if let active = try? context.fetch(activeFetch) {
            for session in active {
                // cancelSession is idempotent, so a stale/duplicate id is harmless.
                NotificationScheduler.cancelSession(sessionId: session.id)
            }
        }
        // One end() call tears down whichever single Live Activity is live (safe no-op
        // if none). finalElapsed/creditsMoved are 0 because nothing is being banked.
        LiveActivityService.end(finalElapsed: 0, creditsMoved: 0)

        do {
            try context.delete(model: Session.self)
            try context.delete(model: ActivityDebt.self)
            try context.delete(model: Quest.self)
            try context.delete(model: Activity.self)
            try context.delete(model: Ledger.self)
            try context.save()
        } catch {
            // Keep the console quiet in release builds (QA-11); this is only a
            // development aid for diagnosing a failed wipe.
            #if DEBUG
            print("SettingsView.wipeAllData failed: \(error)")
            #endif
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

// Thin UIKit wrapper — UIActivityViewController can't be used directly in SwiftUI.
// Only used for export; import goes through the native .fileImporter modifier.
private struct ShareSheetView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
