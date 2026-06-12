# Phase A — Full Code Review Findings (Resubmission QA)

Reviewed: every file under `DopamineLedger/`, `DopamineLedgerWidgets/`,
`DopamineLedgerTests/`, plus `project.yml`, both `Info.plist`s, the asset
catalogs, `LaunchScreen.storyboard`, and `Localizable.xcstrings` (programmatic
audit). Reviewed against CLAUDE.md locked rules, RESUBMISSION-CHECKLIST.md,
FEATURES.md privacy commitments, JOURNAL.md Sessions 40–51, and DECISIONS.md.

**Baseline (2026-06-12):** `make generate && make build` → BUILD SUCCEEDED.
Full test suite → 46/46 passed, 0 failed. Privacy URL
(`https://cybercervela.github.io/DopamineLedger/privacy.html`) → HTTP 200.
String catalog: 214 keys; every `lBundle` key has non-empty values in all
7 languages (the only "missing" entries are Xcode-auto-extracted raw literals,
covered by findings below).

Severity: `blocker` = could plausibly trigger a reviewer · `fix` = should fix,
low risk · `accept` = note and leave (justified) · `conflict` = repo
contradicts checklist/docs — PM arbitrates.

---

## Blockers

| ID | Location | Category | Severity | Finding & proposed fix | Risk of fix |
|---|---|---|---|---|---|
| F-01 | `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` | placeholder | **blocker** | **QA-01.** Visually confirmed: AI watermark (✦ sparkle) in the bottom-right corner at 100% zoom. Format is otherwise compliant (1024×1024, RGB, no alpha). PM supplies a clean regenerated asset; CC wires it in and re-verifies all four corners. | None (asset swap) |
| F-02 | `DopamineLedger/Info.plist:43-45`, `DopamineLedgerWidgets/Info.plist:19-22` | release-config | **blocker** | **QA-02.** Both targets still at `CFBundleShortVersionString` 1.0 / `CFBundleVersion` 1. Bump both **in sync** (mismatched versions between app and extension are rejected at upload). PM to confirm 1.0.1 vs 1.1 — recommend **1.0.1** (polish-only build, matches the review-notes template). | None |
| F-03 | App Store listing (PM-held; draft at `kit-for-next-claude/APP_STORE_LISTING.md:107-113`) | metadata-mismatch | **blocker** | **QA-14.** The live listing's "COMING IN FUTURE UPDATES" lists *Siri & Shortcuts* — but Siri shipped in this build (5 intents, FEATURES.md `done`). Stale metadata is its own rejection class (2.3). PM edits the listing; CC drafts the corrected section. PM should also paste the current live listing into `docs/appstore-listing.md` so the rest of QA-14 can be verified against reality. | None (text edit in ASC) |

## Fix (should fix before resubmission — low risk)

| ID | Location | Category | Severity | Finding & proposed fix | Risk of fix |
|---|---|---|---|---|---|
| F-04 | `Views/ActivityListView.swift:660` | localization | fix | `Text("ACTIVE")` badge resolves against the **device** language, not the in-app picker. The `ACTIVE` key already has all 7 translations (commit 91ec402 added them but never rerouted the view). With in-app language ≠ device language the badge shows the wrong language. Fix: `Text(lBundle.l("ACTIVE"))`. | One line |
| F-05 | `Views/HistoryView.swift:195` | localization | fix | `return "YESTERDAY"` is hardcoded English; "TODAY" right above it is localized. No catalog key exists. Add `history.yesterday` ×7 languages and route through `lBundle`. | One line + 7 strings |
| F-06 | `Views/TemplateGalleryView.swift:113` | localization | fix | `String(format: "%.1f cr/min", …)` — the only rate display in the app that bypasses the localized `session.rate` key and `.abbreviated`. Template gallery is on the first-launch CTA path, so a reviewer in any locale sees it. Route through `lBundle.l("session.rate")` + `.abbreviated` for consistency. | One line |
| F-07 | `Views/AddQuestView.swift:37` | crash-risk (functional dead-end) | fix | Edit-mode payoff field is seeded with locale-aware `.formatted(...)` → a quest with payoff ≥ 1 000 renders "1,000" (or "1 000" in FR), and `Double("1,000")` parses to nil → **Save permanently disabled when editing that quest**. Reviewer-reachable with big numbers; user-hostile regardless. Fix: seed with a non-grouping, dot-decimal representation. | Localized init only |
| F-08 | `Views/AddActivityView.swift:125-127`, `Views/AddQuestView.swift:46-48` | localization (input) | fix | `Double(text)` rejects comma decimals. On FR/DE/ES devices the decimal pad shows **","** — typing "2,5" disables Save with no explanation. PM is native FR and will hit this in QA-26. Fix: normalize "," → "." before parsing (single shared helper). | Small, testable |
| F-09 | `Views/AddActivityView.swift` (rate field validation) | release-config / economy | fix (in-scope: **DL-16 Path A**) | No upper bound on cr/min. Pasting "1e15" (or "inf", which passes `v > 0`) produces absurd/broken displays and a meaningless economy; extreme values can even trap `Int()` in `Double.abbreviated`. **Proposed cap: 60 cr/min** (= 1 credit/second). Rationale: the highest in-app guidance preset is 10 (high-toxicity spender), highest charger preset 6 — a 60 cap leaves 6–10× headroom for power users while keeping every display sane; it's also a clean mental unit. Enforce in `isValid` with a visible localized hint ("Maximum rate: 60 cr/min" ×7), Save disabled above cap — no silent clamping, no change to stored activities. **Needs PM sign-off on the value before implementation.** Same guard applied to the quest payoff field (propose 10 000 cap) if PM agrees. | Validation-only; no model change |
| F-10 | `Views/SettingsView.swift:550-556` | visual-defect (dead path) | fix | `canOpenURL("mailto:…")` returns false unless `mailto` is declared in `LSApplicationQueriesSchemes` (it isn't) — so **Contact developer always shows the copy-address fallback alert and never opens Mail**, even with Mail installed. A reviewer tapping Contact sees a degraded path. Fix: call `UIApplication.shared.open(url)` directly and show the fallback in the completion handler on failure (verify behaviour in simulator first). | Small; fallback already exists |
| F-11 | `Views/SettingsView.swift:635-647` (`wipeAllData`), `Services/DataExporter.swift:137` (`applyImport`) | crash-surface / visual-defect | fix | Wiping all data (or importing a backup) **while a session is running** deletes the Session rows but never ends the Live Activity or cancels the scheduled spender notifications → an orphaned Live Activity ticks on the Lock Screen indefinitely and stale "balance empty" alarms fire later. Reviewer-plausible: start session → Settings → Danger Zone → wipe. Fix: before wipe/import, finalize (or at minimum `LiveActivityService.end` + `NotificationScheduler.cancelSession`) any active session. | Contained; reuses existing services |
| F-12 | `AppIntents/DopamineLedgerIntents.swift:122-124` | consistency (behavioral) | fix | `StartSessionIntent` never stamps `session.timeMultiplier` — Siri-started sessions silently lose the Peak Hours 1.5× bonus that UI-started sessions get. One line, mirroring `ActivityListView.startSession`. | One line |
| F-13 | `Services/DataExporter.swift` + `DopamineLedgerTests/` | crash-surface | fix | **QA-30 not yet done.** No unit tests for malformed import (empty file, truncated JSON, wrong schema, huge file, non-JSON). Also note: `applyImport` **wipes before inserting** — verify a mid-import failure can't leave the store wiped (`context.delete(model:)` semantics); restructure to validate-then-replace if needed. | Additive tests; import flow change needs care |
| F-14 | `Views/SettingsView.swift:644` | release-config | fix | `print("SettingsView.wipeAllData failed…")` is not `#if DEBUG`-gated (SoundPlayer's prints are). QA-11 wants a quiet Release console. Gate or drop it. | One line |
| F-15 | `Views/SessionView.swift:287-293` | consistency / dead-code | fix (low) | Private `formatElapsed` survived the Session 51 consolidation and produces a **third** duration format ("1h 5 min") vs `.formattedDuration` ("1 h 5 m") vs History's `formatHistoryDuration` ("1h 5m"). Consolidate all three user-visible formats on `.formattedDuration`. (Unit words "min"/"h" stay Latin in CJK — see F-27.) Also fix the stale file-header comment claiming swipe-to-dismiss is disabled (it isn't; FEATURES.md says swipe-down allowed). | Cosmetic; screenshot-verify |
| F-16 | `Views/HistoryView.swift:137` | crash-risk (low) | fix (low) | `ForEach(dayGroups, id: \.header)` — headers like "MON 26 MAY" repeat across **years**, producing duplicate ForEach IDs and undefined rendering for users with >1 year of history. Not reviewer-reachable, but the fix is cheap: key groups by their `Date` instead of the formatted string. | Small |
| F-17 | `Views/ActivityListView.swift` (all 3 list surfaces) | feature (in-scope) | fix | **DL-12 follow-up (scope contract):** auto-scroll list to top on session start so the newly-pinned active row is visible when the user had scrolled down. `ScrollViewReader` + `.scrollTo` on session start; applies to All/Chargers/Spenders surfaces (one ScrollView serves all three). | Few lines; behavioral — visual gate |

## Conflict — PM arbitration required

| ID | Location | Category | Severity | Finding |
|---|---|---|---|---|
| F-18 | `Views/SettingsView.swift:232-234` vs `RESUBMISSION-CHECKLIST.md` QA-08 vs `FEATURES.md` | localization / doc-drift | **conflict** | The checklist (QA-08) and FEATURES.md say ZH/JA/KO are **hidden** from the language picker. The code shows **all 7 visible** — and that is per a recorded, PM-signed-off decision (commit f542ba4, D-007 update: "activated Session 28 after the user reviewed and accepted the translation quality"). The comment directly above the code still claims CJK is hidden. **PM decides for this submission:** (a) keep all 7 visible (then CC fixes the stale comment + FEATURES.md row + checklist line), or (b) re-hide CJK (and/or DE/ES per QA-26) as the conservative play for the flagged-account review, returning them in 1.1. Either way the three contradicting doc surfaces get aligned. |

## Accept (note and leave — justification given)

| ID | Location | Category | Severity | Finding & justification |
|---|---|---|---|---|
| F-19 | `Views/PrivacyPolicyView.swift` (entire file) | localization | accept | Whole in-app policy intentionally English-only — it mirrors `docs/privacy.html`, which is EN-only by documented backlog decision ("English version is legally valid for all locales"). Translating the in-app copy without the web copy would create drift. |
| F-20 | `DopamineLedgerWidgets/SessionLiveActivity.swift:50,53,104-106,120` | localization | accept | Live Activity strings ("Paused/Charging/Spending", "cr earned/spent", "Open app to stop", "cr/min") are EN-only. The extension has no string catalog and can't see the in-app language anyway. Apple reviews in EN; zero 5.6 surface. Backlog for v1.1 alongside Siri-phrase localization. |
| F-21 | `AppIntents/DopamineLedgerIntents.swift` (dialogs + phrases) | localization | accept | EN-only Siri dialogs/phrases — already a documented backlog item ("Siri phrases — multilingual (v1.1)"). |
| F-22 | `Models/ActivityTemplate.swift` catalog names | localization | accept | Template names ("Deep Work", "Streaming - Netflix") are EN-only by design — half are brand names; the curated-name review is an open backlog item gathering user feedback. |
| F-23 | `Image(systemName:)` outside IconResolver — `SettingsView` ×9, `BalanceCard:58`, `PrivacyPolicyView:101`, `HistoryView` ×6, `SessionView:151` | consistency (theme law) | accept | Documented watch-list item ("Tie to PixelArt work"). Both shipping themes resolve to SF Symbols, so there is zero user-visible impact; fixing now is churn without benefit and PixelArt is excluded from this submission. |
| F-24 | `Views/ActivityListView.swift:246` | visual-defect (UX) | accept | Tapping a *different* activity while a session runs silently no-ops (after dismissing the session sheet). Matches the locked one-session-at-a-time rule; the pinned ACTIVE row at position 0 explains the state. If PM wants feedback, a haptic is a 2-line follow-up — not required for resubmission. |
| F-25 | `LaunchScreen.storyboard:32` | metadata / copy | accept | "Setting things up…" subtitle is static EN copy on the launch screen. QA-31 otherwise passes: real launch screen (logo + name + accent background), no placeholder flash. Storyboard localization isn't worth the risk this close to submission. |
| F-26 | `Extensions/Double+Credits.swift:16` | visual-defect (edge) | accept | Balances 999 950–999 999 render "1000K" instead of "1M" (rounding at the K/M boundary). A 50-credit window at a magnitude no reviewer will reach; the rate cap (F-09) removes the realistic path to it. |
| F-27 | `Views/DashboardView.swift:310`, `Views/HistoryView.swift:196-198` | localization | accept | `RelativeDateTimeFormatter` / `DateFormatter` day-month headers follow the **device** locale rather than the in-app language — already documented in-code as "acceptable for MVP". Consistent, low-impact, and correct for the common case (in-app language == device language). |
| F-28 | `Views/HistoryView.swift:468-470` | dead-code | accept | `QuestHistoryRow` falls back on `iconName == "circle"` but `Quest` defaults to `"star"` — the fallback branch is unreachable. Harmless: "star" is a valid SF Symbol and renders correctly. Note for the future quest-icon work. |

## Found during Phase C visual QA (added 2026-06-12)

| ID | Location | Category | Severity | Finding |
|---|---|---|---|---|
| F-29 | `Localizable.xcstrings` key `activity.add.create.own` (fr) | localization (copy) | PM-judgment | FR value "Créer votre propre" is grammatically dangling ("create your own" with no noun — a native speaker expects e.g. "Créer la vôtre" or "Créer une activité"). Surfaced for the PM's QA-26 native FR pass; one-string fix if confirmed. |
| F-30 | Stats number formatting | localization (info) | accept | Grouping separators follow the device region (e.g. "+1'140" with a Swiss region). Locale-correct behaviour, not a bug — noted so App Store screenshots are taken with the intended region set. |
| F-31 | `Views/SettingsView.swift` export share sheet | visual-defect | **FIXED** | PM-reported on device: first Export Data tap presented a blank share sheet (boolean-driven `.sheet` raced its optional URL payload). Converted to `sheet(item:)` — cannot present without the payload. Commit 98cafcd. |
| F-32 | All themes (`Theme.swift`, `NeuTheme.swift`) | accessibility (info) | accept → backlog | QA-33 result: the app's typography uses fixed point sizes (`Font.system(size:)` without `relativeTo:`), so text does not respond to Dynamic Type at all. Consequence: nothing clips or truncates at any size (QA-33 passes trivially — verified at XXXL and the largest accessibility size on SE + iPhone 17), but users who rely on larger text don't get it. Not a rejection driver; proper support is a theme-layer project → v1.1+ backlog. |

## Checklist items verified clean during this review

| QA-ID | Status | Evidence |
|---|---|---|
| QA-05 (baseline) | PASS | `make generate && make build` → BUILD SUCCEEDED (2026-06-12) |
| QA-06 (baseline) | PASS | 46/46 tests passed, 0 failed (xcresult 2026-06-12 13:06) |
| QA-07 | PASS* | No user-visible TODO/placeholder strings. "Load Test Data" + debug seed alert are `#if DEBUG`-gated (`SettingsView:161-171, 485-508`); `DebugSeeder.swift` is wholly `#if DEBUG`. Release verification re-run lands in QA-11. |
| QA-08 | PASS* | All `lBundle` keys complete ×7 languages (214-key programmatic audit). Exceptions are F-04/F-05/F-06 raw literals + the F-18 picker conflict. |
| QA-10 | PASS | `ThemeRegistry.all` filter (`SettingsView:189`) still excludes `pixelArt`; fonts referenced only by dormant `PixelArtTheme`; no reachable pixel-art UI. |
| QA-12 | PASS | No `try!`/`fatalError`/`as!` anywhere in app or widget code. Static-URL force-unwraps (`SettingsView:551,564`, `PrivacyPolicyView:70,99`) are compile-time constants. `Quest.swift` calendar force-unwraps cannot fail for daily/weekly/monthly arithmetic. |
| QA-13 | PASS | Zero `URLSession`/`URLRequest` hits. Only `canOpenURL`/`open` (gatekeeper, contact, settings). Privacy URL curl → 200. No third-party imports. |
| QA-31 | PASS | Real launch screen: logo imageView + app name + accent background (`LaunchScreen.storyboard`). See F-25 note. |
| QA-32 (static) | PASS* | No API above the iOS 17.0 floor found (`.task(id:)`, `presentationBackground`, `contentTransition`, `fileImporter`, ActivityKit all ≤17). Runtime pass on a 17.x simulator still owed in Phase C. |

*\* = static verification done; runtime/Release re-verification scheduled in the plan below.*
