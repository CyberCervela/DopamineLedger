# DopamineLedger — Backlog

Items deferred from active development. Verify or ship when ready.

---

## UI polish — post-MVP

| Item | Notes |
|---|---|
| Sheet header buttons (Cancel / Save / Done) neumorphic styling | Buttons have correct pill shape but the header row sits slightly above the scroll content with a visible seam. Root cause: `.presentationBackground` + plain VStack doesn't fully match the navigation bar treatment. Investigate `UISheetPresentationController` background or a sticky-header approach inside the ScrollView. Low priority — buttons are functional and legible. |
| Consolidate `formatDuration` helper | Duplicated in `ActivityListView.swift` and `SessionView.swift`. Extract to a shared `DurationFormatter.swift` or extension on `TimeInterval`. Zero user-visible impact — purely internal cleanup. |

---

## Next session — priority order

| # | Item | Notes |
|---|---|---|
| 1 | **App Store screenshots — fix & retake** | `Settings.png` captured mid-scroll (top cut off). `Create quest.png` has large empty lower half. `Dashboard.png` is 1320×2868 (6.9") while all others are 1206×2622 (6.3") — needs a consistent set. Retake on the same simulator before submission. |
| 2 | **App Store submission** | Blocked on Apple Developer Program approval (applied, awaiting email). Once Team ID is in hand: set `DEVELOPMENT_TEAM` in Xcode, archive, upload, screenshots, listing copy from `kit-for-next-claude/APP_STORE_LISTING.md`. |
| 3 | **Decimal display for sub-1 credit amounts** | Show "0.4 cr" instead of "0 cr". Formatting-only change in one or two display sites. |

---

## Post-MVP features

| Item | Notes |
|---|---|
| **Dashboard / stats** | Done — Sessions 6–7. See JOURNAL.md. |
| **`netDelta` accuracy for overrun sessions** | Currently uses base rate × elapsed for spenders; doesn't reflect the 2× debt penalty on overrun. Fix requires storing `balanceAtSessionStart` on `Session` and replaying `SessionMath.apply()` in `DashboardStats.compute()`. Low urgency (stats are directionally correct). Block on before any "weekly summary" notification or export feature. |
| **Consolidate `formatDuration`** | Duplicated in `ActivityListView.swift`, `SessionView.swift`, and `DashboardView.swift`. Extract to `DurationFormatter.swift` or a `TimeInterval` extension. Zero user-visible impact. |
| **History screen** | Chronological log of completed sessions and — most importantly — completed quests. Quests are big rewarding life milestones (e.g. "Publish Dopamine Ledger") and deserve their own timeline view. Think: a scrollable journal of achievements, date-stamped, showing the quest name, payoff earned, and date completed. Could live inside the Dashboard or as its own tab. |
| Decimal display for sub-1 credit amounts | e.g. show "0.4 cr" instead of "0 cr" |
| Shortcut / HealthKit auto-session triggers | Start/stop sessions via Shortcuts app or HealthKit workout events |
| Pixel-art theme (Step 7) | Assets not generated; fonts wired but no pixel-art icons yet |

---

## Technical debt / architecture improvements

From the Session 9 codebase audit (2026-05-26). The audit found **no ship-blockers** —
all items below are post-launch cleanup. Ordered roughly by value. None should delay
App Store submission.

### High value

| Item | Detail |
|---|---|
| **Extract a `.neuCard()` view modifier** | The neumorphic card chain (`.background(theme.colors.surface)` → `.clipShape(RoundedRectangle(cornerRadius:))` → `.shadow(shadowLight, x:-,y:-)` → `.shadow(shadowDark, x:+,y:+)`) is copy-pasted 15+ times across every view. Single biggest duplication in the codebase; a shadow-radius tweak today means editing ~15 sites. Extract to a `ViewModifier` (`.neuCard()` / `.neuRaised()`). **Risk: Med** — do as its own PR and screenshot-verify each screen, since a site may have an intentional radius/offset difference. |
| **Integration tests for ledger-mutating flows** | The pure math (`SessionMath`/`RepayMath`) is well-tested, but the *glue* that applies it to SwiftData has zero coverage: `SessionFinalizer.finalize` (balance write + debt-row insert) and the repay flows in `DebtView.repay`/`ActivityMenuView.repay` (`RepayMath.split` + `repaidAt` stamping). These are the highest-consequence mutations in the app. Add tests with an in-memory `ModelContainer`. Additive, low risk. |

### Medium value (consolidation)

| Item | Detail |
|---|---|
| **Consolidate `formatDuration` / `formatElapsed`** | `formatDuration` duplicated ×3 (`ActivityListView:347`, `SessionView:199`, `DashboardView:418`); `formatElapsed` duplicated ×2 (`SessionView:208` + widget `SessionLiveActivity:151`). Extract to a `TimeInterval` extension. Note: the widget copy lives in a separate target, so sharing it requires a file compiled into both targets (like `SessionActivityAttributes`). |
| **Consolidate `IconCircle`** | The 44×44 shadowed icon circle is defined once as a struct (`DashboardView:370`) but inlined as a raw `ZStack` in `ActivityRow`, `QuestRow`, `DebtView`, and `ActivityMenuView`. Promote the existing struct to a shared view and reuse. |
| **Consolidate the pill segmented picker** | `FilterPicker` (`ActivityListView:503`) and `ScopePicker` (`DashboardView:75`) are near-identical. Extract a generic `NeuSegmentedPicker<T>`. |
| **Localize notification strings** | `NotificationScheduler.swift:95–123` — the 5-min warning and zero alarm titles/bodies are hardcoded English. A non-English user gets English alarms during a spender session. Move to `Localizable.xcstrings`. (Only pre-submission if launching to non-English markets.) |
| **Localize `mailFallback` alert** | `SettingsView.swift:88–91` — "Send feedback" / "Copy address" hardcoded English; the contact email literal is also duplicated 3× (`SettingsView:89,91,349`) — hoist to one constant. |

### Low value (theme-law tidy)

| Item | Detail |
|---|---|
| **Route hardcoded SF Symbols through the theme** | Several `Image(systemName:)` / `Label(systemImage:)` calls bypass `IconResolver`, violating the file's own stated rule: `SettingsView:139,188,298,323`, `BalanceCard:58`, `PrivacyPolicyView:101`, `ActivityListView:430,433,492,495`. Chrome glyphs (checkmark, chevron, pencil, trash) with no semantic role. Won't theme under PixelArt. **Tie to PixelArt work.** |
| **Theme the hero session timer font** | `SessionView.swift:76` uses `.system(size:64…).monospacedDigit()` hardcoded — won't switch under PixelArt, and `.monospacedDigit()` on a custom font silently falls back (per LESSONS_LEARNED). Add a typography role or reuse `display`. **Tie to PixelArt work.** |

### Watch list (do NOT clean now — intentional / deferred)

| Item | Detail |
|---|---|
| **Dormant sound + PixelArt subsystem** | `SoundPlayer.swift` (71 lines, zero callers), `SemanticSound`, `SoundAsset`, `theme.sound()`, PixelArtTheme's sound map, the `surfaceElevated` color role, `typography.mono`, and unused icon roles (`repay`/`bell`/`timer`/`info`/`back`/`close`) are all dead today — but they're deliberate scaffolding for the deferred PixelArt theme. **Keep.** *If PixelArt is ever formally cancelled, this is ~100+ lines of safe deletion.* |
| **`ActivityListView` size (566 lines)** | Biggest file; holds session-lifecycle logic in the view. Cohesive, and splitting fights `@Query` ownership. Leave unless it keeps growing. |
| **Denormalized `activityId`** | Looks like a missing `@Relationship` but is an intentional, documented workaround for a SwiftData `#Predicate` limitation. Correct as-is. |
| **`netDelta` overrun accuracy** | Already tracked above under Post-MVP features — directionally correct, low urgency. |
