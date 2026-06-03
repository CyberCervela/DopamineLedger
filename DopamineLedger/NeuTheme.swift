// NeuTheme.swift
// The primary round-2 theme: light neumorphic.
//
// Design decisions locked before implementation:
//   - Background: cool off-white gray (#E8E8EE). Elements share this exact
//     hue — depth comes from dual shadows alone, never from fill differences.
//   - Accent: dark charcoal (#2D2D3E) for interactive elements (buttons,
//     active states). NOT red — red is reserved for negative/debt/warnings only.
//   - Negative: matte red (#CC2D2D) for debt rows, blocks, overrun warnings.
//   - Positive: medium green (#3A9E6E) for chargers, earned credits, repaid debt.
//   - Typography: SF Rounded throughout — rounded terminals pair naturally
//     with the soft, tactile neumorphic shape language. No custom font files.
//   - Shadows: white highlight top-left + blue-gray shadow bottom-right.
//     The slight blue tint on the dark shadow matches the cool background hue.

import SwiftUI

struct NeuTheme: Theme {
    let id          = "neu"
    let displayName = "Dopamine"

    let colors = ThemeColors(
        background:      Color(red: 0.910, green: 0.910, blue: 0.933),
        surface:         Color(red: 0.910, green: 0.910, blue: 0.933), // same — depth via shadow only
        surfaceElevated: Color(red: 0.945, green: 0.945, blue: 0.960), // sheets, modals
        textPrimary:     Color(red: 0.110, green: 0.110, blue: 0.180),
        textSecondary:   Color(red: 0.480, green: 0.480, blue: 0.560),
        textOnAccent:    .white,
        accent:          Color(red: 0.180, green: 0.180, blue: 0.243), // dark charcoal
        positive:        Color(red: 0.227, green: 0.620, blue: 0.431), // medium green
        negative:        Color(red: 0.800, green: 0.176, blue: 0.176), // matte red
        neutral:         Color(red: 0.480, green: 0.480, blue: 0.560),
        divider:         Color(red: 0.820, green: 0.820, blue: 0.850),
        // Blue-gray shadow matches the cool background hue better than pure black.
        shadowDark:      Color(red: 0.660, green: 0.660, blue: 0.720).opacity(0.60),
        shadowLight:     Color.white.opacity(0.90)
    )

    let typography = ThemeTypography(
        display:    .system(size: 56, weight: .bold,     design: .rounded),
        title:      .system(size: 22, weight: .semibold, design: .rounded),
        headline:   .system(size: 17, weight: .semibold, design: .rounded),
        body:       .system(size: 17, weight: .regular,  design: .rounded),
        bodyStrong: .system(size: 17, weight: .semibold, design: .rounded),
        caption:    .system(size: 13, weight: .regular,  design: .rounded),
        mono:       .system(size: 20, weight: .medium,   design: .rounded),
        button:     .system(size: 17, weight: .semibold, design: .rounded)
    )

    let spacing = ThemeSpacing(
        xxs: 2, xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32,
        cornerRadius: 20  // soft, generous radius — matches neumorphic roundness
    )

    let usesPixelArtRendering = false
    let preferredColorScheme: ColorScheme? = .light   // palette is tuned for light backgrounds

    func icon(_ named: SemanticIcon) -> Image {
        // NeuTheme uses SF Symbols, same as SystemTheme. The symbols are
        // legible at any weight against the light background.
        Image(systemName: IconResolver.systemSymbolName(for: named))
    }

    func sound(_ named: SemanticSound) -> SoundAsset? {
        // No custom sounds for the minimal theme — system haptics are enough.
        return nil
    }
}
