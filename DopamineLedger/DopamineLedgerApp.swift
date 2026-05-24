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
// 3. UISegmentedControl and UINavigationBar appearance overrides must happen at
//    app launch (not per-view) because UIAppearance is a global setting. We
//    apply them here when the active theme is first loaded. See TOOLING.md for
//    why SwiftUI's .font modifier doesn't reach these UIKit components.

import SwiftUI
import SwiftData

@main
struct DopamineLedgerApp: App {

    // Persists the user's theme choice across launches.
    // Default is "pixelArt" — the intended primary experience.
    @AppStorage("themeId") private var themeId: String = "pixelArt"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.theme, ThemeRegistry.theme(forId: themeId))
                .onAppear { applyUIKitAppearance(themeId: themeId) }
                .onChange(of: themeId) { _, newId in
                    applyUIKitAppearance(themeId: newId)
                }
        }
        .modelContainer(for: [
            Activity.self,
            Session.self,
            ActivityDebt.self,
            Ledger.self,
            Quest.self,
        ])
    }

    // UIAppearance overrides for components SwiftUI can't style directly
    // (segmented pickers, nav bar). Re-called whenever the theme changes.
    // Note: UIAppearance changes don't hot-swap perfectly at runtime — the
    // nav bar may keep the old theme's look until the next view push. This
    // is a known UIKit limitation documented in TOOLING.md.
    private func applyUIKitAppearance(themeId: String) {
        let theme = ThemeRegistry.theme(forId: themeId)
        // Segmented control font — SwiftUI's .font() modifier is ignored here.
        // We use UIFont.systemFont as a fallback for custom fonts until the
        // font files are loaded; PixelArtTheme's Monogram can't be expressed
        // as a UIFont without a registered name lookup.
        let segmentFont: UIFont = themeId == "pixelArt"
            ? (UIFont(name: "Monogram", size: 18) ?? .systemFont(ofSize: 18))
            : .systemFont(ofSize: 15, weight: .semibold)

        UISegmentedControl.appearance().setTitleTextAttributes(
            [.font: segmentFont], for: .normal
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.font: segmentFont], for: .selected
        )

        // Tint the segmented control to the active theme's accent.
        UISegmentedControl.appearance().selectedSegmentTintColor =
            UIColor(theme.colors.accent)
    }
}
