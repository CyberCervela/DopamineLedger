// DopamineLedgerApp.swift
// Round 2 entry point.
//
// Key decisions baked in here:
//
// 1. Theme injection via @Environment — every view in the hierarchy can read
//    `@Environment(\.theme)` without explicit passing. The active theme
//    persists across launches via @AppStorage("themeId").
//
// 2. ModelContainer covers all five persistent types. If you add a new @Model,
//    add it to this list and the migration is automatic on first launch.
//
// 3. The segmented filter picker is a custom SwiftUI view (FilterPicker), NOT
//    a system Picker(.segmented). This avoids UIAppearance fights where SwiftUI
//    overrides text-color settings silently. See TOOLING.md.

import SwiftUI
import SwiftData
import UserNotifications

@main
struct DopamineLedgerApp: App {

    init() {
        // Wire up the delegate so notifications display as banners even while
        // the app is in the foreground (e.g., the debt alarm firing during a
        // spender session in SessionView). Without this, iOS silently drops them.
        UNUserNotificationCenter.current().delegate = NotificationCenterDelegate.shared
    }

    // Persists the user's theme choice across launches.
    // Default is "neu" (light neumorphic) — the primary round-2 experience.
    @AppStorage("themeId")      private var themeId:      String = "neu"
    // Persists the user's in-app language choice. Default "en".
    // Changing this immediately re-injects a different .lproj Bundle, so
    // every view re-renders in the new language without an app restart.
    @AppStorage("languageCode") private var languageCode: String = "en"

    var body: some Scene {
        WindowGroup {
            let theme  = ThemeRegistry.theme(forId: themeId)
            let bundle = languageBundle(for: languageCode)
            ContentView()
                .environment(\.theme, theme)
                .environment(\.languageBundle, bundle)
                .preferredColorScheme(theme.preferredColorScheme)
        }
        .modelContainer(for: [
            Activity.self,
            Session.self,
            ActivityDebt.self,
            Ledger.self,
            Quest.self,
        ])
    }
}
