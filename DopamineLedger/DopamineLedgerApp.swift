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
            ContentView()
                .environment(\.theme, ThemeRegistry.theme(forId: themeId))
                // Color scheme follows the active theme: NeuTheme → light,
                // PixelArtTheme → dark. Overrides the per-device system setting
                // so the app always looks as designed.
                .preferredColorScheme(ThemeRegistry.theme(forId: themeId).usesPixelArtRendering ? .dark : .light)
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
