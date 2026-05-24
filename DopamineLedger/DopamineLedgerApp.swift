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

@main
struct DopamineLedgerApp: App {

    // Persists the user's theme choice across launches.
    // Default is "neu" (light neumorphic) — the primary round-2 experience.
    @AppStorage("themeId") private var themeId: String = "neu"

    var body: some Scene {
        WindowGroup {
            // Resolve once per evaluation so the .environment and the
            // .preferredColorScheme see the same theme value.
            let theme = ThemeRegistry.theme(forId: themeId)
            ContentView()
                .environment(\.theme, theme)
                // Each theme declares its colour-scheme preference. NeuTheme
                // forces .light, PixelArtTheme forces .dark, SystemTheme
                // returns nil so the device's Dark Mode setting wins.
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
