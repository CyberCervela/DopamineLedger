# DESIGN_SYSTEM.md — Theming, semantic roles, and what views are allowed to know

The single most important structural change from round 1. Read this
before writing any view code.

---

## The principle: roles, not values

A view never asks for a *value* (a hex code, a font name, an SF Symbol
string, an asset path). It asks for a *role*:

- "the color of primary text on this surface"
- "the typography for a numeric balance display"
- "the icon meaning 'charger'"
- "the sound that plays when a session ends"

The active `Theme` answers the question. That answer can change between
themes (e.g. `PixelArtTheme` returns a pixel-art asset for `.charger`;
`SystemTheme` returns `Image(systemName: "bolt.fill")`) without the view
caring.

If a view would need a switch statement on theme to do its job, the role
catalog is missing a role — extend the protocol instead of branching in
the view.

---

## What lives where

```
Theme protocol  ─────► what roles exist
ThemeColors     ─────► the catalog of color roles
ThemeTypography ─────► the catalog of typography roles
ThemeSpacing    ─────► the catalog of spacing roles
SemanticIcon    ─────► the catalog of icon roles
SemanticSound   ─────► the catalog of sound roles
PixelArtTheme   ─────► concrete answers, pixel-art-flavored
SystemTheme     ─────► concrete answers, system-flavored
IconResolver    ─────► implementation detail of `theme.icon(...)`
SoundPlayer     ─────► implementation detail of `theme.sound(...)`
```

---

## The role catalogs

These are starting points. Add roles as views need them; do not pre-add
every possible knob.

### `ThemeColors`
```swift
struct ThemeColors {
    let background:      Color   // app/screen background
    let surface:         Color   // cards, sheets
    let surfaceElevated: Color   // pop-up panels, alerts
    let textPrimary:     Color
    let textSecondary:   Color
    let textOnAccent:    Color
    let accent:          Color   // primary brand/action color
    let positive:        Color   // chargers, earned credits, repaid debt
    let negative:        Color   // debt, blocked state, warnings
    let neutral:         Color   // quests, default chips
    let divider:         Color
    let shadow:          Color
}
```

### `ThemeTypography`
```swift
struct ThemeTypography {
    let display:    Font   // huge balance number on BalanceCard
    let title:      Font   // screen titles, sheet titles
    let headline:   Font   // section headers, list group titles
    let body:       Font   // standard reading text
    let bodyStrong: Font   // emphasized body
    let caption:    Font   // captions, helper text
    let mono:       Font   // numeric displays inside cards
    let button:     Font   // primary button label
}
```

> ⚠ **PixelArtTheme silent-fallback gotcha.** Round 1 found that
> `.weight(.semibold)` on Monogram and `.monospacedDigit()` on Abaddon
> silently fell back to the system font. Build the `Font` values **once**
> in the theme and never let view code modify weight or digit style on a
> pixel-art font. See `LESSONS_LEARNED.md`.

### `ThemeSpacing`
```swift
struct ThemeSpacing {
    let xxs: CGFloat // 2
    let xs:  CGFloat // 4
    let sm:  CGFloat // 8
    let md:  CGFloat // 12
    let lg:  CGFloat // 16
    let xl:  CGFloat // 24
    let xxl: CGFloat // 32
    let cornerRadius: CGFloat
}
```

`PixelArtTheme` may use larger numbers than `SystemTheme` because pixel
fonts read at a different size. That's the point of having two themes.

### `SemanticIcon`
```swift
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
```

Concrete examples (round 1's experience):
- `SystemTheme.icon(.charger)` → `Image(systemName: "bolt.fill")`
- `PixelArtTheme.icon(.charger)` → `Image("pixel.charger")` from asset
  catalog (a 32×32 yellow pixel-art bolt)

The `IconResolver` file owns the mapping tables for both themes so the
catalogs are easy to read at a glance.

### `SemanticSound`
```swift
enum SemanticSound {
    case sessionStart, sessionStop, debtAccrued, debtRepaid, questDone
}

struct SoundAsset {
    let resourceName: String
    let fileExtension: String   // "wav", "mp3"
    let volume: Float            // 0..1
}
```

`SystemTheme.sound(...)` may return `nil` for some roles (system UI sounds
or silence is fine). `PixelArtTheme.sound(...)` returns themed assets
where available; the scaffolded `SoundPlayer` is the playback engine.

---

## Theme selection

```swift
// Theme.swift
private struct ThemeKey: EnvironmentKey {
    static let defaultValue: any Theme = SystemTheme()
}
extension EnvironmentValues {
    var theme: any Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
```

The app root injects the active theme:

```swift
@main
struct DopamineLedgerApp: App {
    @AppStorage("themeId") private var themeId: String = "pixelArt"
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.theme, themeForId(themeId))
        }
        .modelContainer(for: [...])
    }
}
```

`SettingsView` flips `themeId`. AppStorage persists across launches.

---

## What's allowed and not allowed in view code

| Allowed                                          | Not allowed                                       |
|--------------------------------------------------|---------------------------------------------------|
| `theme.colors.accent`                            | `Color(hex: "#5BD9A8")`                           |
| `theme.typography.display`                       | `.font(.system(size: 48, weight: .bold))`         |
| `theme.icon(.charger)`                           | `Image(systemName: "bolt.fill")`                  |
| `theme.spacing.lg`                               | `.padding(16)` for layout (one-off `.padding(2)` for visual nudges is fine) |
| `theme.sound(.questDone)` via `SoundPlayer.play` | `AVAudioPlayer(...)` directly in a view           |

When in doubt: if the value would have to change between themes, it's a
role and belongs in `Theme`. If it's truly geometry-only and theme-agnostic,
inline literals are okay — but err on the side of extracting.

---

## Migration recipe for the next Claude

When you copy a view-layer idea from round 1's repo into round 2:

1. Replace every `Color(...)` literal with a `theme.colors.<role>` lookup.
2. Replace every `.font(...)` with `theme.typography.<role>`.
3. Replace every `Image(systemName:)` with `theme.icon(<role>)`.
4. Replace every hard-coded padding/spacing with `theme.spacing.<role>`.
5. If a needed role doesn't exist, add it to the appropriate catalog and
   give both `SystemTheme` and `PixelArtTheme` an answer. Don't ship a
   half-themed view.

The first view you migrate will feel slow. By the fourth, the catalogs
will be stable and migration is mechanical.
