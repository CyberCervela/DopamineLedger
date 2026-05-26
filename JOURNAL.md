# DopamineLedger — Session Journal

> **Read this before starting a session** to understand decisions already made,
> bugs already fixed, and things already tried. Don't re-litigate closed items.

---

## Session 7 — 2026-05-26

**Focus:** Dashboard / Stats — Steps 2–5 (model, UI, strings, seeder).

**Status:** All four steps complete. Dashboard is fully functional.

**Shipped:**

- `Models/DashboardStats.swift` (new) — `DashboardScope` enum (Today / This Week / All Time), `ActivitySummary`, `CompletedQuestEntry`, `DashboardStats.compute()`. Pure struct, no SwiftUI, no `@Model`. Follows SessionMath / RepayMath pattern.
- `Models/ActivityDebt.swift` — added `originalAmount: Double = 0` (frozen at creation for stats history) and `repaidAt: Date?` (stamped when debt row reaches zero). Default `= 0` on `originalAmount` keeps lightweight migration safe for existing installs.
- `Views/DebtView.swift` + `Views/ActivityMenuView.swift` — one-liner each: stamp `repaidAt = now` when a debt row hits zero in the repay loop.
- `Views/DashboardView.swift` (full implementation) — `ScopePicker`, `SummaryCard` (NET delta headline + four breakdown rows + outstanding debt), `ActivityStatsSection`, `QuestHistorySection`. All values from `DashboardStats.compute()`. Pure presentation, no business logic.
- `Localization/Localizable.xcstrings` — 16 new keys × 7 languages: `scope.*`, `stats.*`.
- `DopamineLedger/Debug/DebugSeeder.swift` (new) — `#if DEBUG` only. Seeds 4 activities, 6 sessions, 4 quests, 2 debts, and a 420 cr balance on first launch when the store is empty. Auto-runs via `.task` in `ContentView`. Wipe the simulator app to trigger it.
- `DopamineLedgerTests/DopamineLedgerTests.swift` — 11 new `DashboardStats` test cases (33 total, all passing).
- `kit-for-next-claude/WORKFLOW.md` — added "Handing off to the user for testing" section with the `✅ READY TO TEST` block convention.

**Decisions and gotchas:**

- `netDelta` uses base rate × elapsed for spender sessions — intentionally overstates spend for overrun sessions (the overrun becomes debt, not a direct balance draw-down). Backlog item added. Accurate for within-balance sessions.
- `debtRepaid` uses `ActivityDebt.originalAmount` filtered by `repaidAt`. Partial repayments across multiple sessions are attributed to the session that zeroed the row — acceptable for MVP.
- `DashboardScope.thisWeek` anchors to the locale's first weekday via `calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)`. This respects the device region (Monday in Europe, Sunday in US).
- `RelativeDateTimeFormatter` on quest dates follows system locale, not the in-app language switcher — acceptable for MVP.
- `formatDuration` is now duplicated in three files (ActivityListView, SessionView, DashboardView). Backlog item exists for consolidation.
- The `#if DEBUG` seeder guard means `DebugSeeder.swift` is excluded from Release/App Store builds at the compiler level.

**What to pick up next:**
- Step 5 (project.yml glob check) was already confirmed — no changes needed.
- Next work: user testing of the Dashboard, then App Store submission prep (see BACKLOG.md).

---

## Session 6 — 2026-05-25

**Focus:** Dashboard / Stats — concept design phase.

**Status:** Step 1 complete. Steps 2–5 pending next session.

**Implementation plan:**
- Step 1: `ContentView.swift` → wrap in `TabView`; two tabs: Home (`house`) and Stats (`chart.bar`); localized tab labels.
- Step 2: `Models/DashboardStats.swift` (new) → pure struct, no SwiftUI; takes `[Session]`, `[Quest]`, `[Activity]` + scope; returns aggregates (credits earned/spent, net delta, quests + payoff, per-activity summary). Unit-testable.
- Step 3: `Views/DashboardView.swift` (new) → root container + four internal subviews: `ScopePicker` (Today/Week/All time toggle), `SummaryCard` (neumorphic raised card), `ActivityStatsSection` (per-activity rows, chargers first), `QuestHistorySection` (reverse-chron completed quests, with empty state).
- Step 4: `Localizable.xcstrings` → ~10 new keys × 7 languages (`tab.home`, `tab.stats`, scope labels, section headers, stat labels).
- Step 5: Confirm `project.yml` globs cover new files before running `make generate` (expected: no edits needed).
- No changes to `ActivityListView`, `SessionView`, any model, or any service. Fully additive.

**Step 1 — shipped:**
- `Views/ContentView.swift` — replaced `TabView` with a plain `ZStack` (both views always in hierarchy, switched via `opacity`). Custom `NeuTabBar` injected via `.safeAreaInset(edge: .bottom)`. `AppTab` enum defined at top level.
- `Views/DashboardView.swift` — new stub file; themed placeholder text on correct background. Will be fully implemented in Steps 2–3.
- `Theme.swift` — added `.home` and `.stats` cases to `SemanticIcon` under a new `// navigation` group.
- `IconResolver.swift` — wired `house` / `chart.bar` SF Symbol names for both cases; added `pixel.home` / `pixel.stats` stubs for the deferred PixelArt theme.
- `Localizable.xcstrings` — added `tab.home` and `tab.stats` keys across all 7 languages.

**Step 1 — decisions and gotchas:**
- `TabView` was dropped entirely. It creates a `UITabBarController` underneath; hiding its system bar with `.toolbar(.hidden, for: .tabBar)` is unreliable and `UITabBar.appearance().isHidden = true` in `onAppear` fires too late. A plain `ZStack` + `NeuTabBar` is simpler and fully owned.
- Both views kept live in the `ZStack` (not `if/else`) so `@Query` state is preserved when switching tabs.
- `NeuTabBar` uses the same dual-shadow pattern as `BalanceCard`: `shadowLight x:-6 y:-6` + `shadowDark x:6 y:6`.
- `UITabBar.appearance()` must NOT be used — sets a global UIKit appearance that can bleed into sheets and other contexts.

**Lessons documented this session (also added to WORKFLOW.md):**
- Screenshot review must check both directions: new elements present AND old elements gone. The original system tab bar was still rendering beneath the new pill and was missed in the first screenshot review.
- The starting prompt for new sessions was updated to include explicit `read` instructions for WORKFLOW.md and LESSONS_LEARNED.md (not just passive "apply" / "keep in mind").
- UI completion checklist added to WORKFLOW.md: Gate 1 (theme applied), Gate 2 (strings localised) — both must clear before a step is called done.

**Agreed design decisions:**
- Dashboard lives in a **tab bar** (two tabs: Home + Stats). Not a sheet, not a header button — a persistent destination.
- `ContentView` becomes a `TabView` wrapping `ActivityListView` and the new `DashboardView`.
- Three sections inside DashboardView: (1) Summary card scoped to the selected time range, (2) Per-activity breakdown list, (3) Quest history (reverse-chron completed quests).
- A single **time scope segmented control** at the top (Today / This week / All time) drives all three sections.
- Stats math lives in a new `DashboardStats.swift` helper (pure struct, no @Model) — follows the SessionMath / RepayMath pattern and keeps it unit-testable.
- No charts in v1 — numbers only, neumorphic cards. Charts are a follow-up.
- No streaks in v1 — consecutive-day logic is its own session.
- Feel: quiet ledger, not a gamified wall. No badges, no confetti.

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

---

**Screenshots update (same session):**
- All five screenshots retaken on iPhone 17 Pro Max / iOS 26.5 simulator → consistent 1320×2868.
- `Create quest.png` removed (too much empty space).
- `Charger (running).png` replaced by `Spending.png` — shows a live Doomscrolling session with burn-down label ("~17 min left") visible, which better showcases the feature just shipped.
- `Settings.png` retaken from the top — Appearance, Language, Behaviour, Notifications, About all visible.
- Final set: `Dashboard.png`, `Create Charger.png`, `Create Spender.png`, `Settings.png`, `Spending.png` — all 1320×2868, App Store ready.

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
