// Theme.swift
// FRESH for round 2 — not transplanted.
//
// The single most important structural change from round 1: theming
// is now a protocol with at least two implementations (PixelArtTheme
// and SystemTheme), injected via @Environment(\.theme). No view ever
// hard-codes a color, font, icon, or sound — it always asks the active
// theme for a semantic role.
//
// Read DESIGN_SYSTEM.md before extending the role catalogs.

import SwiftUI

// MARK: - Catalog: semantic roles
//
// The catalogs are the *vocabulary* views can use. They are small on
// purpose. Add a role only when a view needs one — and add the answer
// to BOTH themes in the same change. Half-themed views are how round 1
// got into trouble.

// Color roles. Concrete colors live in each Theme implementation.
struct ThemeColors {
    let background:      Color
    let surface:         Color
    let surfaceElevated: Color
    let textPrimary:     Color
    let textSecondary:   Color
    let textOnAccent:    Color
    let accent:          Color
    let positive:        Color   // chargers, earned credits, repaid debt
    let negative:        Color   // debt, blocked state, warnings
    let neutral:         Color   // quests, default chips
    let divider:         Color
    // Neumorphism needs two shadow directions: a dark shadow (bottom-right
    // gives "height") and a light highlight (top-left catches the "light").
    // SystemTheme and PixelArtTheme carry both too — they just use subtler values.
    let shadowDark:      Color
    let shadowLight:     Color
}

// Typography roles. Pre-built Font values — views must not apply
// .weight, .monospacedDigit, .italic, etc. on a pixel-art font (round 1
// proved those modifiers cause a silent fallback to the system font).
struct ThemeTypography {
    let display:    Font   // huge balance number on BalanceCard
    let title:      Font   // screen titles, sheet titles
    let headline:   Font   // section headers
    let body:       Font
    let bodyStrong: Font
    let caption:    Font
    let mono:       Font   // numeric displays inside cards
    let button:     Font
}

struct ThemeSpacing {
    let xxs: CGFloat
    let xs:  CGFloat
    let sm:  CGFloat
    let md:  CGFloat
    let lg:  CGFloat
    let xl:  CGFloat
    let xxl: CGFloat
    let cornerRadius: CGFloat
}

enum SemanticIcon {
    // activity kinds
    case charger, spender, quest
    // chrome
    case add, edit, delete, settings, back, close, info
    // economy
    case balance, debt, repay
    // session
    case play, stop, timer, bell
}

enum SemanticSound {
    case sessionStart, sessionStop, debtAccrued, debtRepaid, questDone
}

struct SoundAsset: Equatable {
    let resourceName:  String
    let fileExtension: String   // "wav", "mp3"
    let volume:        Float    // 0...1
}

// MARK: - Theme protocol

protocol Theme {
    var id: String { get }       // stable identifier — used in AppStorage
    var displayName: String { get }

    var colors:     ThemeColors      { get }
    var typography: ThemeTypography  { get }
    var spacing:    ThemeSpacing     { get }

    func icon(_ named: SemanticIcon) -> Image
    func sound(_ named: SemanticSound) -> SoundAsset?

    var usesPixelArtRendering: Bool { get }
}

// MARK: - Environment plumbing

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: any Theme = SystemTheme()
}

extension EnvironmentValues {
    var theme: any Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - SystemTheme
//
// The "normal iOS app" theme. System fonts, semantic system colors,
// SF Symbols. Looks at home next to other iOS apps. Also a great
// fallback for accessibility / Dynamic Type users.
struct SystemTheme: Theme {
    let id          = "system"
    let displayName = "System"

    let colors = ThemeColors(
        background:      Color(.systemBackground),
        surface:         Color(.secondarySystemBackground),
        surfaceElevated: Color(.tertiarySystemBackground),
        textPrimary:     Color(.label),
        textSecondary:   Color(.secondaryLabel),
        textOnAccent:    .white,
        accent:          .accentColor,
        positive:        .green,
        negative:        .red,
        neutral:         .blue,
        divider:         Color(.separator),
        shadowDark:      Color.black.opacity(0.15),
        shadowLight:     Color.white.opacity(0.7)
    )

    let typography = ThemeTypography(
        display:    .system(size: 56, weight: .bold,    design: .rounded),
        title:      .system(size: 22, weight: .semibold, design: .default),
        headline:   .system(size: 17, weight: .semibold, design: .default),
        body:       .system(size: 17, weight: .regular,  design: .default),
        bodyStrong: .system(size: 17, weight: .semibold, design: .default),
        caption:    .system(size: 13, weight: .regular,  design: .default),
        mono:       .system(size: 17, weight: .regular,  design: .monospaced),
        button:     .system(size: 17, weight: .semibold, design: .default)
    )

    let spacing = ThemeSpacing(
        xxs: 2, xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32,
        cornerRadius: 12
    )

    let usesPixelArtRendering = false

    func icon(_ named: SemanticIcon) -> Image {
        // SystemTheme answers every role with an SF Symbol.
        Image(systemName: IconResolver.systemSymbolName(for: named))
    }

    func sound(_ named: SemanticSound) -> SoundAsset? {
        // SystemTheme is intentionally quiet. Sounds belong to the
        // pixel-art experience. Return nil here; the SoundPlayer
        // service treats nil as "silence is fine."
        return nil
    }
}

// MARK: - PixelArtTheme
//
// The intended primary experience: dark navy palette, Monogram and
// AbaddonBold custom fonts, pixel-art assets, themed sound effects.
// Fonts are pre-built once with their final modifiers applied — see
// LESSONS_LEARNED.md for why .weight() and .monospacedDigit() can't
// be applied at the call site without falling back to system.
struct PixelArtTheme: Theme {
    let id          = "pixelArt"
    let displayName = "Pixel Art"

    let colors = ThemeColors(
        background:      Color(red: 0.08, green: 0.10, blue: 0.18), // deep navy
        surface:         Color(red: 0.12, green: 0.15, blue: 0.24),
        surfaceElevated: Color(red: 0.16, green: 0.20, blue: 0.30),
        textPrimary:     Color(red: 0.95, green: 0.96, blue: 0.98),
        textSecondary:   Color(red: 0.70, green: 0.74, blue: 0.82),
        textOnAccent:    Color(red: 0.08, green: 0.10, blue: 0.18),
        accent:          Color(red: 0.36, green: 0.85, blue: 0.66),  // mint
        positive:        Color(red: 0.36, green: 0.85, blue: 0.66),
        negative:        Color(red: 0.95, green: 0.40, blue: 0.45),
        neutral:         Color(red: 0.55, green: 0.65, blue: 0.95),
        divider:         Color(red: 0.20, green: 0.24, blue: 0.34),
        shadowDark:      Color.black.opacity(0.35),
        shadowLight:     Color.white.opacity(0.08)   // barely visible on dark bg
    )

    // NB: font sizes are larger than SystemTheme's because pixel fonts
    // read at a different size — the same nominal pixel grid renders
    // smaller than San Francisco.
    let typography = ThemeTypography(
        display:    .custom("AbaddonBold", size: 64),
        title:      .custom("Monogram",    size: 28),
        headline:   .custom("Monogram",    size: 22),
        body:       .custom("Monogram",    size: 20),
        bodyStrong: .custom("AbaddonBold", size: 20),
        caption:    .custom("Monogram",    size: 16),
        mono:       .custom("AbaddonBold", size: 22),
        button:     .custom("Monogram",    size: 22)
    )

    let spacing = ThemeSpacing(
        xxs: 2, xs: 4, sm: 10, md: 14, lg: 20, xl: 28, xxl: 40,
        cornerRadius: 8   // pixel art prefers small or zero corner radius
    )

    let usesPixelArtRendering = true

    func icon(_ named: SemanticIcon) -> Image {
        // PixelArtTheme answers from the asset catalog. Names follow
        // the convention "pixel.<role>" (see IconResolver).
        IconResolver.pixelArtImage(for: named)
    }

    func sound(_ named: SemanticSound) -> SoundAsset? {
        // Wired to themed assets in the bundle. Returning nil for an
        // unmapped role is fine — SoundPlayer treats nil as silence.
        switch named {
        case .sessionStart: return SoundAsset(resourceName: "sfx_session_start", fileExtension: "wav", volume: 0.6)
        case .sessionStop:  return SoundAsset(resourceName: "sfx_session_stop",  fileExtension: "wav", volume: 0.6)
        case .debtAccrued:  return SoundAsset(resourceName: "sfx_debt_accrued",  fileExtension: "wav", volume: 0.7)
        case .debtRepaid:   return SoundAsset(resourceName: "sfx_debt_repaid",   fileExtension: "wav", volume: 0.7)
        case .questDone:    return SoundAsset(resourceName: "sfx_quest_done",    fileExtension: "wav", volume: 0.7)
        }
    }
}

// MARK: - Convenience: theme lookup by id
//
// Used by the app root reading the @AppStorage("themeId") value to
// instantiate the right theme.

enum ThemeRegistry {
    static let all: [any Theme] = [NeuTheme(), PixelArtTheme(), SystemTheme()]

    static func theme(forId id: String) -> any Theme {
        all.first(where: { $0.id == id }) ?? NeuTheme()
    }
}
