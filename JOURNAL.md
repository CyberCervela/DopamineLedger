# DopamineLedger — Session Journal

> **Read this before starting a session** to understand decisions already made,
> bugs already fixed, and things already tried. Don't re-litigate closed items.

---

## Session 5 — 2026-05-25

**Focus:** Burn-down feature ("How long can I keep going?") on spender rows.

**Shipped:**
- `ActivityListView.swift` — `ActivityRow` now shows "Can run for X h Y m" below the rate on spender rows when the activity is idle and balance > 0. Hidden when the activity is already active or balance is zero. Balance is passed in from the parent `ActivityListView` (queries `ledger?.balance`).
- `SessionView.swift` — same burn-down label shown inside the open session sheet, live-updating as the timer runs. Colour inherits the red overrun state below 20% balance.
- `Localizable.xcstrings` — new `row.activity.burndown` key added and localised across all 7 languages.
- `BACKLOG.md` — priority list updated; burn-down moved from backlog to done; History screen added as a new post-MVP idea.

**Decisions:**
- `formatDuration` helper is duplicated in both `ActivityListView.swift` and `SessionView.swift` — accepted for now, logged in backlog for a future cleanup pass.
- Burn-down shows "< 1 min" when remaining time rounds to zero rather than hiding — prevents a confusing flash-to-gone at very low balances.
- SessionView burn-down inherits the red colour when below 20% of starting balance, giving it an urgent feel as time runs out.

**Known:**
- `formatDuration` is duplicated in two files. Backlog item added for consolidation into a shared utility.
- App Store screenshots exist in `AppStore Pictures/` but have a size mismatch: `Dashboard.png` is 1320×2868 (iPhone 16 Pro Max / 6.9") while the other five are 1206×2622 (iPhone 16 / 6.3"). Needs a consistent set before submission.
- `Settings.png` was captured scrolled down — the theme section header is partially cut off. Should be retaken from the top.
- `Create quest.png` has a lot of empty space in the lower half — may want to retake or replace with a more visually rich screen.

---

## Session 4 — 2026-05-25

**Focus:** App icon.

**Shipped:**
- `AppIcon-1024.png` — neumorphic DL monogram, generated via Gemini web UI, converted and wired into `AppIcon.appiconset/Contents.json`.
- `scripts/generate_app_icon.py` — Python/Pillow generator for the neumorphic lightning bolt (kept as a reference/fallback; not the active icon).
- `scripts/generate_dl_icons.py` — Python/Pillow generator for 3 DL letter variants (also kept as reference).
- `scripts/generate_ai_icons.py` — Imagen 4 Ultra generation script; requires a paid Google AI Studio key to run (free tier quota is 0 for all image models).

**Decisions:**
- Gemini web UI produced a better result than Pillow-generated icons — the neumorphic card with raised DL letters reads clearly at home-screen size.
- Active icon: `AppIcon-1024.png` (Gemini-generated, 1024×1024 RGB PNG, no alpha).
- The icon has Gemini's pre-rounded corners inside an outer background — Apple's squircle mask clips the outer area cleanly in production.

**Known:**
- Tiny Gemini ✦ watermark in bottom-right corner — invisible at 60×60 home-screen size.
- Google API key used during this session should be rotated (was shared in conversation).

---

## Session 3 — 2026-05-25

**Focus:** MVP polish pass — four backlog features + two bug fixes.

**Shipped:**
- Icon picker (31 SF Symbols in `IconResolver.activityIcons`; grid in `AddActivityView`; `Activity.iconName` now persisted and displayed in `ActivityRow` with kind-icon fallback for old `"circle"` default)
- Active-session indicator (pulsing `.strokeBorder` on `ActivityRow` when `isActive`)
- Per-activity debt chip (red capsule pill below rate on spender rows with debt)
- About section in Settings (version from bundle, mailto:cibercervela@pm.me, GitHub links)
- Step 7 (pixel-art polish) permanently moved to long-term backlog; excluded from MVP
- **Bug fix — foreground notifications silently dropped:** iOS suppresses notifications when the app is in the foreground unless `UNUserNotificationCenterDelegate` is set. Added `NotificationCenterDelegate.shared` wired at app init in `DopamineLedgerApp.init()`.
- **Bug fix — swipe-down blocked on SessionView:** Removed `.interactiveDismissDisabled()`. Session survives in DB on swipe; active indicator on home row; tapping the row re-opens the session (new guard in `openActivity`).
- **Live debt display in SessionView:** Spender sessions now show "X remaining" (turns red below 20% of starting balance) and "X in debt · 2× rate" once past zero. Timer and icon also turn red on overrun. Fixes user confusion about balance not updating during a session (Ledger only updates at finalize — by design — but SessionView now shows the live picture).

**Decisions:**
- `NotificationCenterDelegate` placed at the bottom of `NotificationScheduler.swift` (keeps notification logic in one file).
- `SessionView` queries `@Query var ledgers` itself for the pre-session balance; no need to pass it as a parameter since the Ledger doesn't change during a session.
- `openActivity` now checks `activeSessions.first(where: { $0.activityId == activity.id })` before the `activeSessions.isEmpty` guard, so tapping the pulsing row re-opens the sheet.

**Known remaining:**
- Privacy Policy URL in About section is the GitHub repo (placeholder). Needs a real hosted page before App Store submission.
- Pixel-art theme assets not generated. Step 7 deferred.

---

## Session 2 — 2026-05-25

**Focus:** In-app localisation + language switcher.

**Shipped:**
- Custom `\.languageBundle` environment key (`Localization/LanguageBundle.swift`)
- `Localizable.xcstrings` with 80+ keys × 7 languages (EN/FR/DE/ES/ZH/JA/KO)
- In-app language switcher in Settings; CJK hidden from picker until native-speaker review
- All views migrated to `lBundle.l("key")` pattern
- `ActivityFilter` raw values changed from display strings to localization keys (e.g. `"filter.all"`)
- `project.yml` updated with `knownRegions`

**Gotchas:**
- SwiftUI `Text(LocalizedStringKey)` ignores `.environment(\.locale)` for bundle selection — always uses `Bundle.main`. The custom environment key + `NSLocalizedString(key, bundle:, comment:)` is the only reliable fix.
- German "ausgeben" (to spend) is separable — "aus" goes to sentence end. Required two separate format-string keys (`activity.hint.earns` / `activity.hint.spends`) rather than interpolating a verb.
- Format strings with numbers need `String(format: lBundle.l("key"), formattedValue)` not `Text("\(lBundle.l("key"), value)")`.

---

## Session 1 — 2026-05-23 / 2026-05-24

**Focus:** Round 2 green-field rebuild + Live Activities.

**Shipped:**
- Full xcodegen scaffold (`project.yml`, `make generate/build/install`)
- Theme protocol: `NeuTheme` (primary), `SystemTheme`, `PixelArtTheme` (stub)
- All models + math transplanted from round 1; 22 unit tests passing
- Complete view layer: ActivityListView, BalanceCard, SessionView, AddActivityView, AddQuestView, DebtView, ActivityMenuView, SettingsView
- `DopamineLedgerWidgets` extension: Lock Screen + Dynamic Island Live Activity
- `LiveActivityService` wired into session start/pause/resume/stop
- Ghost "Test Session" Live Activity bug fixed (TEMP debug `init()` block removed from `DopamineLedgerApp`)

**Key architectural decisions:**
- `ActivityKit.Activity` must be fully qualified (`ActivityKit.Activity<...>`) — clashes with SwiftData `Activity` model.
- `ThemeRegistry.all` excludes `pixelArt` from the Settings picker (`filter { $0.id != "pixelArt" }`).
- `Session.elapsed` is a computed property that accounts for `totalPausedSeconds`.
- `SessionFinalizer` is a shared enum (not a method on SessionView) so both SessionView and SettingsView's global stop use the same path.
