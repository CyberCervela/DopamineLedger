// ContentView.swift
// Root of the navigation hierarchy.
//
// Round 2 implementation order from CLAUDE.md:
//   Step 2 smoke test: both themes render something on screen.
//   Step 4 onward: replaced by ActivityListView once the data layer is wired.
//
// Everything here goes through the theme — no hard-coded colors, fonts, or icons.

import SwiftUI

struct ContentView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            theme.colors.background.ignoresSafeArea()

            VStack(spacing: theme.spacing.xl) {
                theme.icon(.balance)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .foregroundStyle(theme.colors.accent)

                Text("Dopamine Ledger")
                    .font(theme.typography.title)
                    .foregroundStyle(theme.colors.textPrimary)

                Text("Round 2 scaffold — both themes render this screen.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacing.xl)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.theme, PixelArtTheme())
}
