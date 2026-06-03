// NeuCardModifier.swift
// Single source of truth for the neumorphic raised-card look:
//   background(surface) → clipShape(RoundedRectangle) → bilateral shadows.
//
// Why this exists: the same four-modifier chain was copy-pasted 25+ times,
// meaning a shadow-radius tweak or a dark-mode colour change required editing
// every call site. One modifier = one edit for the whole app.
//
// Three sizes mirror the visual hierarchy:
//   .lg  radius 10 / offset ±6 — hero cards (BalanceCard, sheet overlays)
//   .md  radius  8 / offset ±5 — standard list/section cards (default)
//   .sm  radius  6 / offset ±4 — compact buttons and smaller blocks
//
// NOT used for:
//   • Circle icon bubbles (shadow on Circle().fill, not a view-modifier chain)
//   • NeuTextButton / NeuIconButton (Capsule + dedicated files)
//   • Cards with intentional cornerRadius adjustments (e.g. cornerRadius − 2)
//   • Stateful shadows where radius/offset varies with selection or enabled state

import SwiftUI

enum NeuCardSize {
    case sm, md, lg

    var radius: CGFloat {
        switch self {
        case .sm: return 6
        case .md: return 8
        case .lg: return 10
        }
    }
    var offset: CGFloat {
        switch self {
        case .sm: return 4
        case .md: return 5
        case .lg: return 6
        }
    }
}

private struct NeuCardModifier: ViewModifier {
    @Environment(\.theme) private var theme
    let size: NeuCardSize

    func body(content: Content) -> some View {
        content
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
            .shadow(color: theme.colors.shadowLight, radius: size.radius, x: -size.offset, y: -size.offset)
            .shadow(color: theme.colors.shadowDark,  radius: size.radius, x:  size.offset, y:  size.offset)
    }
}

extension View {
    func neuCard(_ size: NeuCardSize = .md) -> some View {
        modifier(NeuCardModifier(size: size))
    }
}
