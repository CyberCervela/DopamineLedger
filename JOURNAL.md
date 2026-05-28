# DopamineLedger — Session Journal

> **Read this before starting a session** to understand decisions already made,
> bugs already fixed, and things already tried. Don't re-litigate closed items.

---

## Session 15 — 2026-05-28

**Focus:** Bug fix — ghost pill button in top-right corner of choice sheet and template gallery header.

**Bug:** `ActivityAddChoiceView` and `TemplateGalleryView` both used an invisible `NeuTextButton` on the trailing side of their header `HStack` as a centering mirror. `NeuTextButton` renders a neumorphic pill (surface fill + bilateral shadows) regardless of text color, so `.foreground: .clear` hid the label but left a fully visible ghost button in the corner.

**Fix:** Replaced the mirror trick with `.overlay()` on the header `HStack`. The title centers itself across the full header width via the overlay; nothing is rendered on the trailing side.

**Files changed:** `Views/ActivityAddChoiceView.swift`, `Views/TemplateGalleryView.swift`.

**What to pick up next:** Same as Session 14 — awaiting Apple review result; History tab (D-012) is the next feature.

---

## Session 14 — 2026-05-28

**Focus:** Activity Guidance & Template System (D-013, D-014) — full implementation. Then replaced the system iOS confirmationDialog with a custom neumorphic choice sheet.

**What shipped:**

### Activity Guidance & Template System

- **`Models/ActivityTemplate.swift`** (new): `SpenderToxicity` enum (low/medium/high → 1.0/2.0/10.0 cr/min), `TemplateCategory` enum (focusLearning, movement, rest, leisure, highRisk), `ActivityTemplate` struct (static catalog of 13 presets: 8 chargers + 5 spenders). All pure value types — no SwiftData involvement.
- **`Views/AddActivityView.swift`** (enriched): Added `ActivityMode.fromTemplate(_:)` case; `onSaved: (() -> Void)?` callback for NavigationStack dismissal; Impact and Enjoyment toggles for chargers; Toxicity three-way selector for spenders; `applyGuidanceRate()` wires toggles → rate field automatically. Edit mode reverse-maps existing rate back to toggle state. Default charger rate now 3.0 (low impact + low enjoyment); default spender rate 2.0 (medium toxicity).
- **`Views/TemplateGalleryView.swift`** (new): Sheet with a NavigationStack; categories and template rows; tapping a template pushes `AddActivityView(mode: .fromTemplate(…), onSaved: { dismiss() })` inside the same sheet surface. `TemplateRow` shows 44pt icon circle + name/rate + forward chevron.
- **`Localizable.xcstrings`**: 20 new keys × 7 languages (EN/FR/DE/ES + ZH/JA/KO) covering all guidance labels, toggle hints, toxicity levels, category names, and gallery title.

### Neumorphic choice sheet

User rejected the system `.confirmationDialog` (floating in the middle of the screen, breaks neumorphic aesthetic).

- **`Views/ActivityAddChoiceView.swift`** (new): Full neumorphic modal sheet with header (Cancel / "Add Activity" / invisible mirror for centring) and two descriptive `choiceCard` rows — "Choose from Template" (star icon, accent colour, hint text) and "Create Your Own" (pencil icon, secondary colour, hint text). Fires an `onSelect: (AddActivityPath) -> Void` callback.
- **`Views/ActivityListView.swift`** (modified): `AddActivityPath` enum (`createOwn` / `fromTemplate`) added at file level; `showAddChoiceDialog` state replaced with `showAddChoice: Bool` + `pendingAddPath: AddActivityPath?`; `.confirmationDialog` replaced with `.sheet` presenting `ActivityAddChoiceView`.

**Final rate table (implemented):**

| Charger: Impact | Charger: Enjoyment | Rate |
|---|---|---|
| Low | High | 2.0 cr/min |
| Low | Low | 3.0 cr/min |
| High | High | 5.0 cr/min |
| High | Low | 6.0 cr/min |

| Spender: Toxicity | Rate |
|---|---|
| Low | 1.0 cr/min |
| Medium | 2.0 cr/min |
| High | 10.0 cr/min |

**Key patterns / gotchas:**

- **Sheet chaining via `onDismiss`**: SwiftUI won't present two sheets simultaneously. Pattern: set `pendingAddPath` before calling `showAddChoice = false`; read it in the sheet's `onDismiss` callback to open the correct next sheet. Trying to open the second sheet inside the first sheet's button action silently fails.
- **NavigationStack inside a sheet**: `TemplateGalleryView` wraps a `NavigationStack` so templates push to `AddActivityView` inside the same sheet surface (no double-modal). The `onSaved` callback lets `AddActivityView` (deep in the nav stack) dismiss the entire outer sheet by calling the gallery's `dismiss()`.
- **SourceKit false positives**: Throughout development, SourceKit reported cross-file type errors (`Cannot find ActivityKind in scope`, etc.). All were false positives — `make build` succeeded with zero errors every time.
- **Rate table doubled from design-phase sketch**: The Session 13 design document showed chargers 1.0/1.5/2.5/3.0 and spenders 1.0/2.0/4.0. After review the user adjusted the baseline so the lowest charger earns 2.0 cr/min (2× the lowest spender 1.0) and bumped high toxicity to 10.0 for genuine friction without causing rage-quits. D-013 updated to reflect the final implemented values.

**Commits:**
- `63e15af` — Add Activity Guidance & Template System (D-013, D-014)
- `f91ca09` — Replace system action sheet with neumorphic choice sheet

**Template catalog curation (same session, continuation):**

User identified a family / children use case (parents managing kids' screen time). Three new charger templates added to `ActivityTemplate.swift`:

| Name | Category | Impact | Enjoyment | Rate | Icon |
|---|---|---|---|---|---|
| Homework | Focus & Learning | High | Low | 6.0 cr/min | `pencil.and.ruler.fill` |
| Reading | Focus & Learning | High | High | 5.0 cr/min | `book.closed.fill` |
| Chores | Movement | Low | Low | 3.0 cr/min | `house.fill` |

Rationale for defaults: Chores kept at Low impact (vs High) deliberately — "if we put everything at high impact, nothing is high impact." Users can override. No new spenders added (Streaming / Gaming / Social Media already cover the family use case). No new categories added (Focus & Learning and Movement absorb all three). Final catalog: **16 presets** (10 chargers, 5 spenders → wait, 10 chargers + 5 spenders = 15... actually: 6 Focus, 3 Movement, 2 Rest = 11 chargers; 3 Leisure + 2 High-Risk = 5 spenders = 16 total).

Feedback on catalog names (whether "Homework" vs "School Work" etc.) deferred — user will gather input from parents, kids, and friends before any renames.

**What to pick up next:**
- **Release**: App still in Apple review (submitted 2026-05-27). Click "Release this version" on approval.
- **D-012 History tab** remains unbuilt — third tab exists in the locked decision but has no implementation yet.
- **Template name review**: after gathering user feedback from parents/kids/friends.

---

## Session 13 — 2026-05-28

**Focus:** Live Activity bug fix — three bugs, all in `LiveActivityService.swift`.

**Bugs fixed (confirmed on physical device):**

1. **Live Activity keeps counting after session stops.** After tapping Stop, the Dynamic Island and lock screen timer continued to auto-tick indefinitely.
2. **Live Activity keeps counting while paused.** Tapping Pause did not freeze the timer in the Dynamic Island or on the lock screen.
3. **Lag between sessions on lock screen.** Stopping one activity and immediately starting another left the old activity visible for up to 30 seconds before the new one appeared.

**Root cause — all three bugs shared one cause:**

`update()` and `end()` both used `ActivityKit.Activity<SessionActivityAttributes>.activities.first` to find the current Live Activity. This is fragile in two ways:

- **App-kill scenario:** If the app is force-killed mid-session, the in-memory activity reference is lost. On relaunch, `activities.first` can return nil, so `end()` silently no-ops and the Live Activity runs forever.
- **Multiple activities scenario:** If a previous session's Live Activity wasn't ended cleanly (e.g., its async `Task` was delayed at the time), `request()` in `start()` creates a *second* activity. `activities.first` then targets the old one for `update()` and `end()`, while the new one keeps auto-ticking via `Text(state.adjustedStart, style: .timer)` — which the system drives autonomously without any app involvement.

Bug 3 had an additional cause: `end()` used a 30-second dismissal window, and `start()` did nothing to clear old activities, so both the old and new sessions overlapped on the lock screen for up to 30 seconds.

**Fix — `DopamineLedger/Services/LiveActivityService.swift`:**

- Track the current Live Activity by its **ID stored in `UserDefaults`** (key: `LiveActivityService.currentID`). This survives app kills and relaunches.
- `currentActivity` computed property finds the activity by that specific ID — never `.first`.
- `start()` now **immediately ends all existing activities** (`.immediate` dismissal) before calling `request()`. This kills orphans and fixes Bug 3.
- `end()` clears `currentID` **before** the async `Task` runs, so nothing can mistakenly target the ending activity during its 30-second dismissal window.
- No changes to callers (`SessionFinalizer`, `SessionView`, `ActivityListView`).

**What to pick up next:**
- App is still in Apple review (submitted 2026-05-27). Wait for review result; click "Release" on approval.
- Post-launch v1.1 planning: tip jar, Siri/App Intents, History screen.
- **Next feature: Activity Guidance & Template System** (see below — full design locked this session).

---

### Session 13 continued — Activity Guidance & Template System (design phase)

**No code written. Full design locked. Ready to implement next session.**

**The problem being solved:** New users open the app and face a blank "0.0 cr/min" rate field with no intuition for what a sensible rate looks like, or what the right balance between charger and spender rates is. The philosophy is powerful but invisible.

**The core design principle locked (see D-013):**

The baseline rule: 1 minute of a charger activity should produce enough credits to cover 2 minutes of a typical spender. This is the 2:1 burn-down ratio. Charger rates are then modulated by two qualitative dimensions:
- **Impact** (high/low): How much leverage does this activity have on your life? High-impact activities earn more credits — they're worth incentivising even if they're effortful.
- **Enjoyment** (high/low): How naturally do you gravitate toward this? High-enjoyment activities earn *fewer* credits — you do them anyway and need less incentive.

For spenders, a single **Toxicity** dimension replaces the two-toggle model: Low / Medium / High maps directly to how much friction you want to build in.

**The UX design locked (see D-014):**

1. **Tapping + opens a choice sheet**: "Choose from template" / "Create your own." Both paths lead to the same `AddActivityView` — templates just pre-fill it.
2. **`AddActivityView` is enriched** for both paths, for both new and edited activities:
   - Chargers get two binary toggles: High Impact (yes/no) + High Enjoyment (yes/no) → 4 combinations → auto-fills the rate field.
   - Spenders get a three-way Toxicity selector: Low / Medium / High → auto-fills rate.
   - Rate field stays directly editable as an escape hatch for precise control.
   - Brief 1-line helper text per toggle explains the philosophy in context.
3. **Template gallery**: ~12–15 curated presets grouped by category (Focus & Learning, Movement, Rest, Leisure, High-risk). Each template has a pre-set default position of the toggles (i.e., each template "knows" its own impact and enjoyment level).
4. **Editing existing activities** also shows the toggles — users can reconsider whether an activity is "high impact" as their relationship with it evolves.
5. **No onboarding walkthrough needed** — the template gallery + enriched AddActivityView covers the same ground organically. Onboarding is deferred indefinitely.

**Rate table (base spender = 1.0 cr/min):**

| Charger: Impact | Charger: Enjoyment | Rate |
|---|---|---|
| Low | High | 1.0 cr/min |
| Low | Low | 1.5 cr/min |
| High | High | 2.5 cr/min |
| High | Low | 3.0 cr/min |

| Spender: Toxicity | Rate |
|---|---|
| Low | 1.0 cr/min |
| Medium | 2.0 cr/min |
| High | 4.0 cr/min |

**Files that will change:**
- `Views/AddActivityView.swift` — toggles, helper text, rate auto-calculation
- `ActivityListView.swift` — + button action sheet (two choices)
- New: `Models/ActivityTemplate.swift` — static catalog of ~12–15 presets
- New: `Views/TemplateGalleryView.swift` — browsable template picker sheet
- `Localizable.xcstrings` — all new strings × 7 languages

---

## Session 12 — 2026-05-27

**Focus:** App Store submission — signing, device registration, screenshots, listing copy, upload.

**Status: Submission in progress.** Build uploaded. App Store Connect listing ~95% complete. Stopped at filling in Support URL, Copyright, and App Review notes before hitting "Add for Review".

**What was done:**

- **Signing unblocked:** Registered user's iPhone 14 Pro Max as a developer device via Xcode → Signing & Capabilities → Try Again. This resolved the "no devices" provisioning profile error that was blocking Archive.
- **App tested on real device:** Installed via Xcode Debug build. Confirmed smooth after first launch (initial lag was the debug seeder firing once on empty store — not a real bug, not present in Release builds).
- **Archive succeeded:** Product → Archive completed cleanly. Build uploaded to App Store Connect via Distribute App → App Store Connect → Upload.
- **Screenshots retaken** at correct dimensions (1284×2778, iPhone 13 Pro Max simulator — App Store Connect rejected 1320×2868 from iPhone 17 Pro Max simulator):
  - `01-home.png` — home screen, balance 420, activities, quest with Done button
  - `02-stats.png` — Stats tab, NET +640, breakdown, completed quest
  - `03-settings.png` — Settings top (themes, languages, behaviour) — intentional choice to show language/theme options over Legal section
  - `04-add-charger.png` — New Activity sheet, Charger selected, icon picker visible
  - `05-session.png` — Reading session running, 00:39, 4.0 credits earned
  - `06-lockscreen.png` — Lock screen with Gaming Live Activity + "Allow Live Activities" permission prompt (kept intentionally — shows user agency)
  - All saved to `screenshots/appstore/`
- **Listing copy finalised** in `APP_STORE_LISTING.md`:
  - Pixel-art references removed (app ships neumorphic, not pixel-art)
  - "COMING IN FUTURE UPDATES" section added: Siri/Shortcuts, HealthKit, tip jar
  - Disclaimer paragraph added to description
  - "What's New" rewritten to match what actually shipped
- **Pricing:** Free (confirmed — no IAP, no subscriptions)
- **Age rating:** 4+ (all questions No, including Health/Wellness)
- **Build selected** in App Store Connect version page

**Submission confirmed:**
- Support URL: `https://github.com/CyberCervela/DopamineLedger`
- Copyright field filled in
- App Review notes pasted from `APP_STORE_LISTING.md`
- **Submitted: 2026-05-27 at 22:52**

**Status: In Review.** Awaiting Apple review (24–72 hours).

**What to pick up next:**
- Wait for Apple review result (email notification + App Store Connect status change)
- After approval: click "Release this version" in App Store Connect
- Post-launch: plan v1.1 (tip jar, Siri/App Intents, History screen)

---

## Session 11 — 2026-05-27

**Focus:** App Store submission prep — Legal disclaimer section + listing copy cleanup.

**What was done:**

- `SettingsView.swift` — added new `legalSection` (between About and Danger Zone). Contains the disclaimer text block + Privacy Policy link (moved from About). About now holds only: Version · Contact · Source Code.
- `Localizable.xcstrings` — 2 new keys × 7 languages: `settings.section.legal` ("LEGAL" / "LÉGAL" / "RECHTLICHES" / "LEGAL" + CJK), `settings.legal.disclaimer` (full disclaimer sentence in all 7 languages).
- `APP_STORE_LISTING.md` — three fixes:
  - Promotional text: removed "pixel-art" claim (app ships neumorphic, not pixel-art).
  - Description: replaced "Pixel-art everywhere" bullet with "Neumorphic design — soft shadows, dark surfaces, clean typography"; added disclaimer paragraph before the "Built solo with…" line.
  - "What's New": rewrote to accurately describe what shipped (Live Activities, Dashboard, animated balance, language switcher) — removed all pixel-art font/icon references.

**Key decision:** Legal section as its own card rather than folding into About — keeps About clean and gives the disclaimer a clearly-labelled home that's easy for Apple reviewers to find.

**Context:** Apple Developer Program approval received. Submission blocked pending signing setup in Xcode (team selected, no physical device registered — archive should still work via distribution signing). Bundle ID already correct: `com.cibercervela.DopamineLedger`.

**What to pick up next:**
- Product → Archive in Xcode → Distribute → App Store Connect (upload build).
- Create App Store Connect record: `appstoreconnect.apple.com` → New App → paste from `APP_STORE_LISTING.md`.
- Support URL still needed (GitHub repo page or Notion public page).
- Copyright name decision (legal name for the listing).

---

## Session 10 — 2026-05-27

**Focus:** Research — cross-app automation, voice control, and the Shortcuts bridge. No code written.

**Context:** Waiting on App Store submission (Apple Developer Program approval arrived — TestFlight/App Store configuration is the next session's focus).

**What was done:**
- Researched how One Sec, Opal, ScreenZen, and Minimalist Phone approach cross-app session detection on iOS.
- Mapped the full technical landscape across three paths and documented findings in `BACKLOG.md` as a clearly-labelled research note (not agreed implementation).
- Replaced the one-liner "Shortcut / HealthKit auto-session triggers" backlog entry with a full structured note.

**Three paths identified:**

- **Path A — App Intents + Siri (high confidence, build first).** The `AppShortcutsProvider` pattern lets users say "Hey Siri, start Reading in Dopamine Ledger" with zero prior setup. The API is stable and well-supported across iOS 16–26. This directly solves the offline-activity use case (reading a book, cooking) without requiring any screen interaction.

- **Path B — HealthKit workout observer (medium confidence).** Clean, unambiguous signal. Auto-start a charger when the user begins a workout in Fitness or any third-party fitness app. Requires `HealthKit` capability + one Settings toggle.

- **Path C — Screen Time API / shield interception (low confidence, do not build yet).** The technique used by One Sec and Opal: temporarily "block" a distracting app, intercept the launch via a custom shield view, start a session, then lift the block. Technically the only way to auto-detect "user just opened YouTube." However, the API has severe and unresolved regressions on iOS 26 (threshold events firing immediately, random token regeneration, 6 MB extension memory cap causing crashes). Building on it now would mean inheriting One Sec's maintenance burden on a dependency Apple has neglected. Decision: watch and wait.

**Key clarification made (Shortcuts bridge):**
- "The user" in the Shortcuts bridge context = the DopamineLedger app user, not the developers.
- iOS does not allow apps to create Shortcuts automations programmatically — this is a hard security boundary, not an engineering gap.
- Three mechanisms can reduce the friction without crossing that boundary: (1) intent donation + Siri Suggestions — iOS learns usage patterns on-device and proactively surfaces shortcuts on the lock screen with zero user setup; (2) shareable `.shortcut` files for voice shortcuts (not automation triggers); (3) `SiriTipView` for in-context nudges inside the app.
- The full "open YouTube → auto-start session" automation always requires one manual setup by the user in the Shortcuts app. Framed as intentional by design — consistent with anti-engagement principles.

**Decisions locked:**
- No implementation agreed for any of the three paths. All remain research/backlog.
- Research note stamped with date and sources; designed so the next Claude session that picks this up can continue from real references rather than re-deriving the landscape.

**What to pick up next:**
- **Next session: App Store submission.** Apple Developer Program approval received. Configure TestFlight build: set `DEVELOPMENT_TEAM` in Xcode, archive, upload, wire screenshots and listing copy from `kit-for-next-claude/APP_STORE_LISTING.md`. See `BACKLOG.md` item #2 in the priority list.

---

## Session 9 — 2026-05-26

**Focus:** Whole-codebase technical-debt audit (read-only — no code changed). Triggered while waiting on Apple Developer Program approval.

**What was done:**
- Read all 34 Swift files (models, math, services, theme, every view), the test suite, and traced runtime usage of every theme role and service.
- Produced a prioritized debt report and recorded the findings in `BACKLOG.md` under a new **"Technical debt / architecture improvements"** section.

**Headline verdict:**
- **No ship-blockers.** The math/persistence/view layering is clean, the pure-function layer is well-tested (33 cases), and the theme protocol is real architecture. The only thing between us and submission is the screenshot retake already in the backlog.
- The debt that exists is mostly **one pattern repeated** (the neumorphic card chain, 15+ copies) plus **a dormant deferred-feature subsystem** (sound + PixelArt) that should be *kept*, not cleaned.

**Top findings (full list in BACKLOG.md):**
- High value: extract a `.neuCard()` view modifier (kills the biggest duplication); add integration tests for the two ledger-mutating flows (`SessionFinalizer.finalize` + the repay flows) — currently zero coverage on the SwiftData glue, only the pure math is tested.
- Medium: consolidate `formatDuration`/`formatElapsed`, `IconCircle`, and the `FilterPicker`/`ScopePicker` pair; localize the hardcoded notification strings (`NotificationScheduler:95–123`) and the `mailFallback` alert.
- Low: route the remaining hardcoded `Image(systemName:)`/`systemImage:` calls through `IconResolver`, and theme the hardcoded session-timer font (`SessionView:76`) — both tied to PixelArt readiness.

**Deliberately flagged as "do NOT clean now":**
- `SoundPlayer.swift` (zero callers), `theme.sound()`, `SemanticSound`/`SoundAsset`, `surfaceElevated`, `typography.mono`, and unused icon roles — all dead today but intentional scaffolding for the deferred PixelArt theme. ~100+ lines of safe deletion *if and only if* PixelArt is ever formally cancelled.
- Denormalized `activityId` (documented `#Predicate` workaround), `ActivityListView` size (cohesive), `netDelta` overrun (already tracked).

**What to pick up next:**
- App Store submission once the Team ID arrives. Debt items are queued for after launch.

---

## Session 8 — 2026-05-26

**Focus:** BalanceCard animated balance update.

**Shipped:**
- `Views/BalanceCard.swift` — balance number now rolls its digits and flashes colour in sync when the balance changes. Added `@State private var animatedBalance` (mirrors the `balance` prop, updated inside `withAnimation` so `.contentTransition(.numericText())` sees an animated change and rolls). Added `@State private var flashColor` (green on credit, red on debit, fades out after ~0.7 s via a `Task.sleep` + `.easeOut`). Both state changes share one `withAnimation(.easeInOut(duration: 0.4))` call so roll and flash are perfectly synchronised.

**Key decision:**
- `.contentTransition(.numericText())` only rolls when the text value changes inside a `withAnimation` context. The `balance` prop arrives from a `@Query` re-render with no animation wrapper, so the digit just jumped. The fix is a local `animatedBalance` state that is always mutated inside `withAnimation` — the prop drives the trigger, the state drives the display.

**What to pick up next:**
- App Store submission prep (see BACKLOG.md).

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
