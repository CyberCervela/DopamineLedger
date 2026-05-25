// NeuTextButton.swift
// Pill-shaped text button with bilateral neumorphic shadows.
// Use in toolbar leading/trailing items wherever a Cancel / Save / Done
// label is needed. Mirrors the raised-surface look of NeuIconButton.

import SwiftUI

struct NeuTextButton: View {
    @Environment(\.theme) private var theme

    let title:      String
    let font:       Font
    let foreground: Color
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .foregroundStyle(foreground)
                .padding(.horizontal, theme.spacing.md)
                .padding(.vertical,   theme.spacing.xs)
                .background(theme.colors.surface)
                .clipShape(Capsule())
                .shadow(color: theme.colors.shadowLight, radius: 5, x: -3, y: -3)
                .shadow(color: theme.colors.shadowDark,  radius: 5, x:  3, y:  3)
        }
        .buttonStyle(.plain)
        .fixedSize()  // prevents the toolbar from compressing the pill to a circle
    }
}
