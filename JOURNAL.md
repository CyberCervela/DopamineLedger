# DopamineLedger — Session Journal

> **Read this before starting a session** to understand decisions already made,
> bugs already fixed, and things already tried. Don't re-litigate closed items.

---

## Session 32 — 2026-05-31

**Focus:** Polish pass on the activity editor + app-linked templates.

**Shipped:** `Views/AddActivityView.swift`, `Models/ActivityTemplate.swift`, `BACKLOG.md`, `DECISIONS.md`, `PHILOSOPHY.md`.

### Grid shadow bleed — AddActivityView

Category and Linked App grids both used `spacing: theme.spacing.sm` (8pt). Neumorphic shadows on adjacent tiles overlapped and blurred into each other. Fixed to `theme.spacing.md` (12pt) — the same fix applied to `AddQuestView` in Session 17 that was missed in AddActivityView.

### App-linked templates

`ActivityTemplate` gains explicit `init` with `linkedAppScheme: String? = nil` and `linkedAppName: String? = nil` parameters (Swift's synthesized memberwise init excluded stored properties with default values, so an explicit init was required).

Catalog changes:
- Removed: generic "Streaming"
- Added: "Streaming - Netflix" (film.fill, leisure, medium, `nflx://`), "Streaming - YouTube" (tv.fill, leisure, medium, `youtube://`)
- Added: "Social - Instagram" (camera.circle.fill, high-risk, high, `instagram://`), "Social - TikTok" (music.note, high-risk, high, `tiktok://`)
- Kept: "Social Media" (generic, for users not on specific platforms)

`.fromTemplate` init path in `AddActivityView` now reverse-maps `t.linkedAppScheme` back to the correct tile selection — so opening a Netflix template pre-selects the Netflix tile in the Linked App section.

### Docs

- `PHILOSOPHY.md` — new section "The app as a gate, not a door": the intentional entry point concept, why auto-launch was rejected, why the credit system (not the UI) is the friction, and how DL's model differs from One Sec / Opal.
- `DECISIONS.md` — D-018: all three sub-decisions (session-first, no auto-launch, no UI delay) with reasoning.
- `BACKLOG.md` — research entry for expanding the linked app catalog (Prime Video, Disney+, Twitch, Kindle, Duolingo, etc.).

**What to pick up next:**
- Await Apple review; click Release on approval.
- History soft delete.
- Research top App Store apps to expand linked app catalog.

---

## Session 31 — 2026-05-31

**Focus:** Digital gatekeeper — link an activity to a native iOS app or website.

**Shipped:** `Models/Activity.swift`, `Models/LinkedApp.swift` (new), `DopamineLedger/Info.plist`, `Views/AddActivityView.swift`, `Views/SessionView.swift`, `Localization/Localizable.xcstrings` (11 new keys × 7 languages), `LICENSE` (replaced MIT with CC BY-NC 4.0), `project.pbxproj` (regenerated via `make generate`).

### What it does

Any activity (charger or spender) can now be linked to a native iOS app or a custom website URL. While that activity's session is running, an **"Open [App] →"** button appears in SessionView above the Pause/Stop controls. Tapping it opens the app directly via its URL scheme — no browser, no banner — bypassing the home screen entirely.

The friction is the credit system, not the UI. The button is always visible once a session starts; there is no delay. The session running *before* the app opens is what makes this a gate rather than a launcher.

### Implementation

**`Models/Activity.swift`** — two new optional SwiftData fields:
- `linkedAppScheme: String?` — URL scheme (`youtube://`) or https URL. Nil = no linked app.
- `linkedAppName: String?` — display name stored at save time. SessionView reads this directly; no catalog lookup needed at runtime.
Safe lightweight migration — optional with nil defaults.

**`Models/LinkedApp.swift`** (new) — static catalog of 8 supported apps (YouTube, Twitter/X, Instagram, Snapchat, Facebook, TikTok, Netflix, Chrome) plus the "custom website" concept. Stores SF Symbol names for the picker and App Store URLs for the "not installed" fallback alert.

**`DopamineLedger/Info.plist`** — added `LSApplicationQueriesSchemes` array with all 8 scheme names. Without this iOS returns false from `canOpenURL` for any non-system scheme regardless of installation status (iOS 9+ privacy rule).

**`Views/AddActivityView.swift`** — new "Linked App" section in the form (between Category and Rate):
- 3-column grid of app tiles: None + 8 catalog apps + "Website" (custom URL)
- Same selected/unselected styling as the category grid (accent stroke, reduced shadow)
- When "Website" is selected: URL and optional display name text fields animate in
- Reverse-maps stored `linkedAppScheme` back to picker selection in edit mode
- `applyLinkedApp(to:)` helper runs after save for all three modes (create/edit/fromTemplate)

**`Views/SessionView.swift`** — linked app button inside the controls VStack, above Pause:
- Only renders when `activity.linkedAppScheme != nil && !scheme.isEmpty`
- `openLinkedApp()`: `canOpenURL` → open immediately, or show "not installed" alert with App Store link
- Alert uses `common.cancel` (existing key) for dismiss; "App Store" button opens the catalog App Store page directly
- `appStoreURL` looked up from `LinkedApp.catalog` at alert time — SessionView doesn't need the catalog at render time

**Design decision:** button uses `textSecondary` (not accent) — it's an escape hatch, not the primary action. Accent is reserved for Stop.

**`LICENSE`** — replaced MIT with CC BY-NC 4.0 (Copyright 2026 Cyber Cervela). GitHub will detect this automatically and show the badge on the repo page. App Store listing does not need to change — the license covers the source code, not the distributed binary.

### How to test

1. Edit any spender activity (e.g. Doomscrolling) → scroll to "Linked App" → tap YouTube → Save
2. Start that session → "Open YouTube" button appears above Pause
3. Tap it → YouTube opens (if installed) or "not installed" alert appears
4. For custom website: tap "Website" tile → enter `https://reddit.com` → name it "Reddit" → Save → run session → tap button → Safari opens Reddit

**What to pick up next:**
- Await Apple review; click Release on approval.
- History soft delete (Session 25 priority #2).
- Test gatekeeper on a physical device (URL schemes behave the same on device as simulator; the `canOpenURL` result will differ based on what's installed).

---

## Session 30 — 2026-05-31

**Focus:** Empty states — all four screens, copy overhaul, design rules for empty state hierarchy.

**Shipped:** `Views/ActivityListView.swift`, `Views/DashboardView.swift`, `Views/HistoryView.swift`, `Localization/Localizable.xcstrings` (6 keys updated + 2 new).

### What changed

**ActivityListView — new `homeEmptyState` view builder:**
Replaces the old generic `emptyState(icon:message:)` call in `combinedList` (the true first-launch case). Shows the balance icon + "Your ledger is empty." + two `NeuTextButton` CTAs: "Browse Templates" → opens `TemplateGalleryView`; "Start from scratch" → opens `AddActivityView`. No outer neumorphic card — buttons sit directly on the background.

**ActivityListView — `emptyState()` helper updated:**
Icon shrunk from 36pt to 28pt, opacity reduced from 0.5 → 0.4, font changed from `body` (17pt) to `caption` (13pt). Used for chargers/spenders/quests filter empty states.

**DashboardView — `SectionEmptyState` updated:**
Now accepts an `icon: SemanticIcon` parameter (call site passes `.stats`). Same 28pt/0.4/caption treatment.

**HistoryView — `emptyState` updated:**
Added `theme.icon(.history)` at 28pt/0.4 above the caption text. Retains the `Spacer()` sandwich for vertical centering.

**Copy (EN):**
- `home.empty.all`: "Your ledger is empty." (headline for CTA card)
- `home.empty.all.browse` (new): "Browse Templates"
- `home.empty.all.create` (new): "Start from scratch"
- `home.empty.chargers`: "No chargers yet.\nChargers are things worth doing — deep work, exercise, learning."
- `home.empty.spenders`: "No spenders yet.\nSpenders are habits you want to stay intentional about."
- `home.empty.quests`: "No active quests.\nQuests give you credit for getting things done." ← phrased to cover both one-off and recurring quests
- `stats.no_sessions`: "No activity recorded in this period."
- `history.empty`: "Nothing here yet.\nYour first completed session will appear here."

All × 7 languages.

### Design decisions locked

**No nested neumorphic surfaces.** A neumorphic card (raised) containing `NeuTextButton` pills (also raised) stacks two shadow layers on the same background — too much depth. The home empty state originally used a card wrapper; it was removed so the buttons sit directly on the flat background. Rule: never put a raised surface inside another raised surface.

**Empty state text uses `caption` (13pt), not `body` (17pt).** Empty state copy is secondary/explanatory — it should read smaller than the surrounding chrome (filter pills, activity names, etc.). 17pt text in an empty state competes visually with content that isn't there. Caption is the right level for this hierarchy.

**Quick test path:** Settings → Danger Zone → Wipe Data resets to empty state without reinstalling.

**What to pick up next:**
- Await Apple review; click Release on approval.
- History soft delete (Session 25 priority #2).
- Digital gatekeeper feature (design session first — Session 25 priority #3).

---

## Session 29 — 2026-05-31

**Focus:** Peak Hours badge — differentiate charger bonus from spender penalty.

**Shipped:** `Views/SessionView.swift`, `Localization/Localizable.xcstrings` (1 new key).

The "1.5× PEAK BONUS" badge was showing in green for spender sessions too — semantically wrong, since peak hours *cost* more during a spend, not less. Fixed in two parts:

- **Label:** badge now reads "1.5× PEAK PENALTY" for spenders, "1.5× PEAK BONUS" for chargers. New key `session.peak_penalty` added × 7 languages.
- **Color:** badge uses `theme.colors.negative` (red) for spenders, `theme.colors.positive` (green) for chargers.

Confirmed on device.

**What to pick up next:** Empty state for `ActivityListView` (priority #1 from Session 25).

---

## Session 28 — 2026-05-31

**Focus:** Peak Hours multiplier — design locked, docs updated, implementation starting.

**Shipped.** All decisions locked below. See D-017 in `DECISIONS.md`.

---

### Feature: Peak Hours multiplier

Credits and debits during a user-defined time window are amplified by 1.5×. The window is a fixed 6-hour block whose start time the user sets in Settings. The multiplier is stamped on the session at start time and never changes — a session started in-peak keeps the bonus for its full duration (even through pauses); a session started off-peak never gains one.

Applies to: charger sessions (earn 1.5× credits), spender sessions (cost 1.5× credits), and one-tap quest payoffs.

Does NOT apply to: sessions started outside the window, regardless of when they end.

### Design decisions locked (see D-017 for full rationale)

- **Lock at start time** — removes the "need to rush to start before the window closes" dynamic. Once started, the bonus is yours.
- **1.5× fixed multiplier** — meaningful alongside the existing 2× debt rate without being so strong it creates perverse urgency.
- **6-hour fixed window** — roughly a third of a waking day; not user-adjustable in v1.
- **User-defined start time, not named profiles** — a time picker covers every chronotype without forcing users into "early bird / night owl" boxes.
- **Midnight-wrap handled** — a night owl setting start to 22:00 gets a 22:00–04:00 window; `PeakHoursService.isCurrentlyPeak` handles the wrap correctly.
- **Sleep-protection copy nudge** — *"Set this to when you naturally wake up, not when you wish you would."* No minimum start-time cap.
- **Quests get the multiplier** — a quest completed at 8am is a peak-hours win, consistent with the rest of the feature.

### Implementation plan (7 files)

1. **`Services/PeakHoursService.swift`** (new) — pure enum, no state. `isCurrentlyPeak(at:)` reads `@AppStorage` values and handles midnight wrap. `peakEndHour` computed for display.
2. **`Models/Session.swift`** — add `var timeMultiplier: Double = 1.0`. Stored at creation, never mutated. SwiftData lightweight migration is safe with default 1.0.
3. **`Models/SessionMath.swift`** — add `multiplier: Double = 1.0` param to `creditsEarned` and `debtAccrued`. All existing call sites pass nothing → 1.0, no breakage. New unit tests cover the 1.5× case.
4. **`Services/SessionFinalizer.swift`** — pass `session.timeMultiplier` into `SessionMath` calls and into the quest-payoff path.
5. **`Views/ActivityListView.swift`** — at session creation, call `PeakHoursService.isCurrentlyPeak()` and stamp `session.timeMultiplier`.
6. **`Views/SessionView.swift`** — show "1.5× peak bonus" badge (in `theme.colors.positive`) when `session.timeMultiplier > 1.0`.
7. **`Views/SettingsView.swift`** — new Peak Hours section: toggle (enable/disable), start-time picker (when enabled), computed end-time display, copy nudge.
8. **`Localizable.xcstrings`** — ~8 new keys × 7 languages.

### What's out of scope (v1)

- Multiplier as a user-adjustable setting
- Window length as a user-adjustable setting
- Named profile presets (Early Bird / Night Owl) as quick-start shortcuts
- Chronobiology research links (logged in BACKLOG as v1.1)

**Confirmed on simulator/device:** PEAK HOURS section renders between Behaviour and Notifications; time picker shows correctly with green "Your peak: HH:MM → HH:MM" label; Deep Work session shows "1.5× PEAK BONUS" badge in session view. Math feels correct.

**Gotcha caught during implementation:** `SessionView` was computing `creditsMoved = ratePerSecond * elapsed` without the multiplier — the live display would have shown the wrong (lower) credit number while the finalizer applied the correct 1.5× at stop time. Fixed before handoff by using `ratePerSecond * elapsed * session.timeMultiplier` in the display and both `LiveActivityService.update` calls.

**What to pick up next:** Empty state for `ActivityListView` (priority #1 from Session 25, still unbuilt).

---

## Session 27 — 2026-05-30

**Focus:** Launch screen — replace blank green screen with branded text.

**Shipped:** `DopamineLedger/LaunchScreen.storyboard` (new), `DopamineLedger/Info.plist` (switched from `UILaunchScreen` dict to `UILaunchStoryboardName`), `project.yml` + regenerated `project.pbxproj`.

### What changed

The old launch screen was a plain `AccentColor` (neon green) background with nothing on it — looked like a rendering bug on first install when SwiftData takes a moment to initialize.

`LaunchScreen.storyboard` now shows:
- Green background (same AccentColor — user likes the punch)
- **"Dopamine Ledger"** — bold white, 22pt, centered
- **"Setting things up…"** — white/70%, 14pt, 6pt below the name

Key: switched `Info.plist` from `UILaunchScreen` (plist dict) to `UILaunchStoryboardName: LaunchScreen`. The dict approach cannot render text labels; a storyboard is required.

### What didn't ship — logo

`LaunchImage.imageset` and `LaunchImage.png` (copy of the Gemini app icon) are in the repo and correctly bundled. The storyboard references them by name. However, imageView rendering in hand-written launch screen storyboard XML is unreliable without Xcode's visual editor to validate the constraint graph — every XML variant tried rendered the labels but not the image. Adding the logo is a 5-minute task in Xcode's storyboard editor; logged in `BACKLOG.md`.

### Lesson learned

Hand-writing launch screen storyboard XML is fragile. The IB parser is strict about version strings (`toolsVersion`, `targetRuntime`), and imageView constraints that look correct in XML silently fail to render. For anything beyond a background color and labels, use Xcode's storyboard editor directly.

**What to pick up next:**
- Empty state for `ActivityListView` (priority #1 from Session 25)

---

## Session 26 — 2026-05-30

**Focus:** History tab — consecutive session bundling + sub-2-min blip filtering.

**Shipped:** `Views/HistoryView.swift`, `Localization/Localizable.xcstrings` (1 new key).

### Design decisions locked

**Bundling rule — consecutive only, not per-day.** Earlier design considered collapsing all same-activity sessions within a calendar day, but this would destroy the day narrative (and created an unsolvable sort-position ambiguity for interleaved activities). Final rule: consecutive runs only — the same activity must appear back-to-back in the sorted timeline with no quest or different-activity session between them. This preserves the "what did I actually do, in order" readout that makes History useful.

**Blips (sub-2-min sessions) are filtered from History entirely.** Cosmetic only — they still exist in the DB and still count toward the balance. A sub-2-min session is either accidental (fat-finger before the explicit start confirmation existed) or too short to be meaningful. Filtering rather than soft-delete means no user action required and no undo complexity. Blips between same-activity sessions do NOT break a consecutive run.

**Time-range subtitle.** Bundle header shows `19:45 → 20:54 · 5 sessions · 1h 6m` — possible only because the sessions are consecutive and their combined time range is meaningful. This would not be a useful display for scattered same-day sessions.

**Expandable, not flat.** Tap the bundle header to reveal compact detail rows (time · duration · credits each). No nested card styling — plain indented rows under a thin separator. This keeps the card visually clean when collapsed and gives the full picture on demand.

### Implementation

**`HistoryView.swift`** — full rewrite of the file (all logic remains private; no API surface changes).

- `HistoryEntry` enum — added `.sessionBundle([Session], Activity?)` case (sessions newest-first).
- `dayGroups` — new algorithm: filter blips first (`elapsed >= 120`), sort unified list newest-first, walk the list detecting consecutive same-`activityId` runs, flush each run as `.sessionBundle` (≥ 2) or `.session` (1), then group by calendar day.
- `BundledSessionHistoryRow` (new private struct) — neumorphic card with always-visible summary header (icon + name + time-range subtitle + total credits + rotating chevron); `@State private var isExpanded`; conditional `BundleDetailRow` list below a thin separator on expand; animated with `withAnimation(.easeInOut(duration: 0.25))`.
- `BundleDetailRow` (new private struct) — compact row indented to align with the text column in the bundle header (`leading: lg + 44 + md`); caption-sized text; no card styling.
- `formatHistoryDuration` extracted to file-private free function (was duplicated in `SessionHistoryRow` and would have been triplicated).

**`Localizable.xcstrings`** — added `history.bundle.sessions` (`"%d sessions"`) × 7 languages.

**Confirmed on device:** Deep Work bundle (5 sessions, 1h 6m, +397.8) and Gaming bundle (2 sessions, 4h 19m, −259.4) both rendered and expanded correctly.

**Backlog:** Detail-row visual polish added to `BACKLOG.md` as a v1.1 item.

**What to pick up next:**
- Empty state for `ActivityListView` (priority #1 from Session 25)
- Await Apple review result; click Release on approval.

---

## Session 25 — 2026-05-30

**Focus:** Product direction — 7 ideas discussed, priorities agreed.

**No code written. Decisions and direction locked below.**

---

### 1. App as digital gatekeeper (new feature — needs design first)

Link a spender activity to a third-party app (e.g. YouTube). Starting the session in DL also offers to launch that app. DL becomes the intentional entry point for digital consumption.

**Technical path:** `UIApplication.shared.open(URL(string: "youtube://")!)` — URL schemes, no entitlements. Not Screen Time API.

**Design locked:** Auto-launching the linked app on session start was considered and rejected. If the app opens automatically, DL stops being a gate and becomes a launcher — the intentional moment disappears. The right pattern is a "Launch YouTube →" button visible inside the session, requiring a conscious tap. The gate must have friction.

**Open design questions before code:** Where does the user link the URL scheme (activity editor?)? What happens if the linked app isn't installed? Does the button live in ActivityMenuView, SessionView, or both?

---

### 2. Chained Siri → auto-launch linked app

Technically possible (URL scheme can be opened from foreground after a Siri intent brings the app up). **Rejected on philosophy grounds** — same reasoning as above. Siri starts the session; opening the linked app stays a conscious tap inside DL.

---

### 3. Screen Time as credit output

Idea: use credit balance to set the Screen Time daily limit (100 credits at 1 cr/min → 100 min limit). Different from Path C (which used Screen Time as *input* to detect app launches). This is Screen Time as *output* — pushing a limit.

**Still too risky for v1.x:** requires `com.apple.developer.family-controls` entitlement (Apple can reject in review), and the API is still flaky on iOS 26. Backlog note to be updated to distinguish input vs. output use cases. Revisit when API stabilises.

---

### 4. Monetisation

**Premium features that fit the philosophy (one-time purchase, no subscription):**
- Pixel-art theme — already built as a stub; natural first premium unlock
- Tip jar — already in backlog
- CSV/JSON export — privacy-safe, user owns their data

**Avoid:** anything that increases daily opens, streak rewards, social comparison, recurring subscriptions.

**On solo dev → company:** IP ownership, contributor agreements, and incorporation deferred to a lawyer. Out of scope for Claude.

---

### 5. History — soft delete

Swipe-to-delete on History rows. Cosmetic only — no balance recalculation (balance lives in the Ledger row, set at finalize time; removing the Session record doesn't touch it). Stats will shift slightly — acceptable.

**Design question:** Undo? Standard iOS swipe-to-delete with a brief undo toast is the right pattern.

Ready to build — no design session needed.

---

### 6. Philosophy refinement — long-term trend view

**Line agreed:** daily checking = engagement bait (avoid); weekly/monthly glance = self-knowledge (valid).

**Right form factor:** opt-in weekly notification — one sentence, not a reason to open the app daily. In-app: a monthly summary page (discoverable, not promoted — not a new tab). PHILOSOPHY.md update needed before the code.

---

### 7. Loading screen / empty state

Two separate problems:
- **Empty state** (high priority): detect `activities.isEmpty` in `ActivityListView`, show a neumorphic placeholder prompting to add an activity or browse templates. Small change, high first-impression value.
- **Launch screen** (low priority): currently `AccentColor` background from `Info.plist`. A neumorphic skeleton requires a UIKit storyboard — more work for less payoff.

---

### Agreed priority order

1. **#7 — Empty state** — small, visible, helps new users immediately
2. **#5 — History soft delete** — well-scoped, clear UX
3. **#1 — Digital gatekeeper** — design session first, then build
4. **#6 — Philosophy doc update** — low effort, good hygiene before any marketing push
5. **#4 — Tip jar** — already in backlog, straightforward
6. **#3 / #2** — defer until iOS 26 Screen Time API stabilises

**What to pick up next:** Empty state for the home screen when no activities exist.

---

## Session 24 — 2026-05-30

**Focus:** Siri Live Activity recovery + Siri confirmation message tweak.

**Shipped:**

### Live Activity recovery on foreground (`ActivityListView.swift`, `LiveActivityService.swift`)

`ActivityKit.Activity.request()` is a foreground-only API — it silently fails when called from an App Intent while the app is backgrounded. The existing `StartSessionIntent` called `LiveActivityService.start()`, which internally calls `request()`, so the session was saved to SwiftData correctly but no Dynamic Island appeared.

**Fix:** Recovery path in `ActivityListView` that fires when the app comes to the foreground:
- `LiveActivityService` — added `static var hasActiveActivity: Bool` (checks `currentActivity != nil`) so the recovery code can guard against starting a duplicate.
- `ActivityListView` — added `@Environment(\.scenePhase)`, a `recoverLiveActivityIfNeeded()` function, and two call sites: in `.task` (covers the app-was-killed case) and in `.onChange(of: scenePhase)` for `.active` (covers the app-was-backgrounded case). If an active session exists with no Live Activity, the function looks up the activity, computes the correct `adjustedStart` (accounting for pauses), calls `LiveActivityService.start()`, and immediately calls `update()` if the session is currently paused.

UX result: Siri starts the session → user opens the app → Dynamic Island appears instantly. The session is running from the moment Siri confirms; the Live Activity catches up on first foreground.

### Siri start confirmation message (`DopamineLedgerIntents.swift`)

Changed `"Started \(fullActivity.name)."` → `"Started \(fullActivity.name). Open the app to see the timer."` so users aren't confused by the missing Dynamic Island.

**Backlog:** Siri phrases are English-only. Multilingual phrases require `AppShortcuts.stringsdict`; response dialogs need `LocalizedStringResource`. Logged in `BACKLOG.md` for v1.1.

### Process fix — never commit before user confirmation (`kit-for-next-claude/WORKFLOW.md`)

Claude committed the Live Activity fix before the user had confirmed it worked on device. Added an explicit rule to `WORKFLOW.md`: the sequence is always implement → `✅ READY TO TEST` → wait for confirmation → then docs + commit + push. Also updated the persistent memory file so this rule survives a `/clear`.

**What to pick up next:**
- Await Apple review; click Release on approval.
- HealthKit workout observer (Path B) — next automation feature.

---

## Session 23 — 2026-05-29

**Focus:** Siri / App Intents (Path A) — five voice actions pre-registered at install.

**Shipped:**

### `DopamineLedger/AppIntents/DopamineLedgerIntents.swift` (new file)

**`ActivityAppEntity` + `ActivityAppEntityQuery`**
Bridges `Activity` into App Intents. Siri resolves a spoken name ("Reading") to the user's actual row via `ActivityAppEntityQuery`, which implements `EntityStringQuery` — case-insensitive substring match so partial names work. `suggestedEntities()` feeds the Shortcuts picker and Siri disambiguation list.

**Five intents:**
- `StartSessionIntent` — `@Parameter var activity: ActivityAppEntity`; enforces the same debt/balance/chill-mode rules as the in-app flow; starts session, fires Live Activity and notifications.
- `StopSessionIntent` — delegates entirely to `SessionFinalizer.finalize()` (math, ledger, debt row, Live Activity end).
- `PauseSessionIntent` / `ResumeSessionIntent` — call `session.pause()` / `session.resume()`, then push an updated `LiveActivityService.update()` with correct `adjustedStart`, `isPaused`, and `creditsMoved`.
- `CheckBalanceIntent` — reads `Ledger.fetchOrCreate(in:)`, returns spoken formatted balance.

All `perform()` marked `@MainActor` — `LiveActivityService`, `Ledger.fetchOrCreate`, and `SessionFinalizer.finalize` are all `@MainActor`-isolated; marking the caller is cleaner than scattering `MainActor.run{}` blocks.

**`DopamineLedgerShortcuts: AppShortcutsProvider`**
Registers 5 × 1–2 phrases with Siri at install time. No user setup. Works immediately in the Shortcuts app; voice ("Hey Siri, start Reading in Dopamine Ledger") is available after Siri indexes the new phrases (may take a minute on device, or require a device restart on first install).

**`project.yml`** — added `sdk: AppIntents.framework` to the main target dependencies. Without an explicit link the `appintentsmetadataprocessor` build tool skips phrase extraction (warning: "No AppIntents.framework dependency found"), meaning Siri phrases aren't registered. `make generate` run to rebuild the pbxproj.

**Why a fresh `ModelContainer` per intent:**
Intents run outside the SwiftUI lifecycle (Siri from lock screen, app backgrounded). No `@Environment(\.modelContext)` available. `ModelContainer(for:)` opens the same on-disk SQLite store; SwiftData's WAL handles concurrent access.

**What to pick up next:**
- Await Apple review; click Release on approval.
- Test Siri voice phrases on physical device (simulator Siri is limited).
- HealthKit workout observer (Path B) — next automation feature.

---

## Session 22 — 2026-05-29

**Focus:** Explicit start confirmation — prevent accidental session starts on a bare tap.

**Shipped:**

### Explicit start confirmation

All activity taps now require an explicit "Start" tap before a session begins. Previously, tapping a charger or a spender with positive balance + no debt called `startSession(for:)` directly, bypassing any confirmation.

**`ActivityListView.swift` — `openActivity()` simplified:**
Removed the two direct-to-start paths (charger early-return and the clean-spender `balance > 0 && !hasDebt` path). Function now always sets `activityMenuFor = activity`, routing every tap through `ActivityMenuView`. The re-open and "another session running" guards are unchanged.

**`ActivityMenuView.swift` — extended for chargers:**
- Added `.charger` to the `Centre` enum. Evaluated first in `centre`, before the debt/balance checks, so chargers always land here regardless of ledger state.
- `body` switch: `.charger` case shows only `startSessionButton` — no debt card, no balance warning, no "cleared" message.
- Icon fallback for pre-icon-picker ("circle") rows updated: chargers fall back to `theme.icon(.charger)` instead of `.spender`.
- Icon color: `theme.colors.positive` (green) for chargers, `theme.colors.negative` (red) for spenders.
- `startSessionButton` filled treatment (accent color, bold, kerning 4): now applies to both `.cleared` and `.charger`. Chargers always get the prominent button — there's no state to resolve first.

No new localization strings. No `project.yml` changes. No model changes.

**What to pick up next:**
- Await Apple review result; click "Release" on approval.
- Icon system overhaul (see BACKLOG.md) — design session before any code.
- Siri / App Intents (Path A) — implementation notes ready in BACKLOG.md.

---

## Session 21 — 2026-05-29

**Focus:** Backlog additions + three neumorphic bugs in `ActivityMenuView` and `DebtView`.

**Backlog additions (no code):**
- `BACKLOG.md` — added "Explicit start confirmation before beginning a session" (prevent false-positive taps, modelled on debt repayment confirmation).
- `BACKLOG.md` — added "Recurring quests — needs design" (completion-rewarded tasks that reappear on a cadence; multiple open design questions flagged, design-first before any code).
- `PHILOSOPHY.md` (new file at project root) — captures the three product pillars: **Extreme unitasking** (one thing at a time, full attention); **Create more than you consume** (chargers build/create, spenders consume; deep conversation with close friends is unambiguously a charger; the distinction vs. shallow talk is noted but the app never imposes it — user privacy); **The app should make itself unnecessary** (no streaks, no engagement traps, success = user no longer needs the app). Open questions section covers rest, recurring obligations, and the transition-off-app moment. Wired into `kit-for-next-claude/CLAUDE.md` reference table.

**Bugs fixed:**

### `ActivityMenuView` + `DebtView` — Done button not neumorphic
Both sheets used `NavigationStack` + `ToolbarItem(.navigationBarTrailing)` for the Done/Terminé button. UIKit takes over toolbar rendering and produces a system-styled pill regardless of SwiftUI styling. Fix: removed `NavigationStack` from both views; added a custom `sheetHeader` using `NeuTextButton` (the existing bilateral-shadow pill component) with `.overlay()` centering — the same pattern used to fix `ActivityAddChoiceView` and `TemplateGalleryView` in Session 15. Added `.presentationBackground(theme.colors.background)` to both.

### `ActivityMenuView` + `DebtView` — Wrong activity icon
Both views hardcoded the semantic kind icon (`theme.icon(.spender)` / `theme.icon(.charger)`), ignoring the icon the user picked in the icon picker. Fix: applied the `IconResolver.activityIconImage(named:)` fallback pattern (same fix applied to `SessionView` in Session 18). `"circle"` legacy rows fall back to the semantic icon; all others use the chosen icon. Spender-only for `ActivityMenuView` (by design — chargers don't reach that view).

### `ActivityMenuView` + `DebtView` — Disabled repay button flat
When balance is zero, the repay button had no shadows (just a flat surface card), which is visually ambiguous — could look like an untapped raised element. Fix: inset shadow treatment when disabled (light/dark shadow positions reversed) to give a pressed-in appearance that clearly signals "unavailable" without looking tappable.

**What to pick up next:**
- Await Apple review result; click "Release" on approval.
- Icon system overhaul (see BACKLOG.md) — Gaming shows correct icon in ActivityMenuView now, but the broader icon set and quest icons need a dedicated design session.
- Siri / App Intents (Path A).

---

## Session 20 — 2026-05-28

**Focus:** History tab (D-012) + SessionView credits-as-hero layout.

**Shipped:**

### History tab — `HistoryView.swift` (D-012)
Third tab added to the app. Unified reverse-chronological timeline of completed sessions and completed quests, grouped by calendar day. Day headers: "TODAY" / "YESTERDAY" / "MON 26 MAY".

- `SemanticIcon.history` added (`clock` in SystemTheme / `pixel.history` in PixelArt).
- `HistoryView.swift` (new file): `@Query` fetches all sessions, quests, and activities; joined client-side via an `activityMap` dictionary. `SessionHistoryRow` shows icon + name + "14:32 · 20 min" + credits; `QuestHistoryRow` shows icon + name + "14:32 · QUEST" + payoff. Deleted-activity sessions handled gracefully (fallback label). `HistoryIconCircle` is a private 44pt neumorphic circle.
- `ContentView.swift`: `AppTab` extended with `.history`; `HistoryView()` added to ZStack; `NeuTabBar` extended to three buttons.
- 5 new localization keys × 7 languages: `history.title`, `tab.history`, `history.empty`, `history.deleted_activity`, `history.quest.caption`.
- `make generate` required to pick up the new file (XcodeGen project).

**D-012 deviation:** D-012 was written before Session 16's category grouping in Stats. Quests are now embedded in `CategoryGroupSection` — removing them would break the category story. Decision: quests stay in Stats AND also appear in History. Both views serve different purposes (aggregates vs. log). DECISIONS.md updated.

### SessionView — credits as hero
Swapped the center block so the credit number is the 64pt focal point:
1. **64pt credits value** — green for chargers, `textPrimary` for normal spenders, red on overrun, `textSecondary` when paused.
2. **"CREDITS EARNED" / "CREDITS SPENT" caption** — uppercased, matches kind color.
3. **Elapsed timer** — drops to `bodyStrong` + `textSecondary`; now human-readable ("< 1 min" / "20 min" / "1h 20 min").
4. Supporting rows (remaining / debt / burn-down / rate) — unchanged, except "X remaining" → "X credits remaining" for clarity.

Live Activity intentionally excluded — timer auto-ticks for free there; credits are a pushed value and would look stale.

2 new localization keys × 7 languages: `session.credits_earned_caption`, `session.credits_spent_caption`.

**What to pick up next:**
- Await Apple review result; click "Release" on approval.
- Siri / App Intents (Path A) — next automation feature.

---

## Session 19 — 2026-05-28

**Focus:** Backlog triage + three polish items: Screen Time path killed, notification/alert localisation, decimal credit display.

**Shipped:**

### Screen Time API (Path C) — marked BLOCKED
Confirmed via research that `DeviceActivity` exposes no retroactive usage data — only threshold callbacks, with no session start/stop signals. The API is also in active regression on iOS 26 (immediate threshold firing, 6 MB extension memory cap, random token regeneration). Path C removed from implementation queue; research note preserved in `BACKLOG.md` with ⛔ BLOCKED header and explicit unblock trigger (WWDC 2026/2027 or a stabilising point release).

### Localise notification strings (`NotificationScheduler.swift`)
The 5-minute warning and zero alarm were hardcoded English strings. `scheduleSpenderSession` now reads `UserDefaults.standard.string(forKey: "languageCode")`, resolves the bundle via the existing `languageBundle(for:)` helper, and uses `bundle.l()` for all four notification strings. Format strings use `String(format:)` for the `%@` activity name interpolation. 4 new keys × 7 languages in `Localizable.xcstrings`: `notification.alarm.title`, `notification.alarm.body`, `notification.warning.title`, `notification.warning.body`.

### Localise feedback alert (`SettingsView.swift`)
`mailFallback` alert had three hardcoded English literals ("Send feedback", the email address shown as message, "Copy address"). Title and button label replaced with `lBundle.l()` calls. Email address stays as a literal — same in every language. 2 new keys × 7 languages: `alert.feedback.title`, `alert.feedback.copy`.

### Decimal display for sub-1 credit values (7 view files)
All credit display sites used `.fractionLength(1)` (always 1 decimal) or `.fractionLength(0)` (always 0 decimals). Changed to `.fractionLength(0...1)` everywhere:
- **Bug fix:** Quest payoffs in `ActivityListView`, `DashboardView`, and the `AddQuestView` hint text used `.fractionLength(0)` — a 0.8 cr payoff showed as "0". Now shows "0.8".
- **Bug fix:** `AddQuestView` edit mode initialised the payoff text field with `"%.0f"`, silently truncating sub-1 values to "0" on re-edit. Fixed to use `.fractionLength(0...1)`.
- **Polish:** Whole-number values drop the redundant trailing zero — "6.0 cr/min" → "6 cr/min", "42.0" → "42". Also fixed the hardcoded `"0.0"` fallback in `DashboardView.netDeltaText` to `"0"`.

Files changed: `BalanceCard`, `ActivityListView`, `SessionView`, `DebtView`, `ActivityMenuView`, `DashboardView`, `AddQuestView`.

**What to pick up next:**
- Await Apple review result; click "Release" on approval.
- History tab (D-012) — still unbuilt.
- Siri / App Intents (Path A) — next automation feature.

---

## Session 18 — 2026-05-28

**Focus:** Bug fix — SessionView showed generic kind icon instead of activity's chosen icon.

**Bug:** The icon circle in `SessionView` always called `theme.icon(.charger/.spender)`, which renders the semantic kind icon (`bolt.fill` / `hourglass`) regardless of what the user picked in the icon picker.

**Fix:** `SessionView` now mirrors the `ActivityRow` fallback pattern — uses `IconResolver.activityIconImage(named: activity.iconName)` for any activity with a custom icon, and falls back to the semantic kind icon only for legacy `"circle"` default rows. One change: `SessionView.swift` line 61.

**Note:** `AddActivityView` pre-selects `bolt.fill` / `hourglass` as the default icon for new activities (not `"circle"`), so the default case also renders correctly via the `IconResolver` path.

**What to pick up next:**
- Await Apple review result; click "Release" on approval.
- History tab (D-012) — still unbuilt.

---

## Session 17 — 2026-05-28

**Focus:** Home screen category grouping, UI polish, template duplicate bug fix.

**Shipped:**
- `ActivityListView.combinedList` replaced: the flat list of all activities then all quests is now grouped by `ActivityCategory.allCases` order, with quests → chargers → spenders within each non-empty category. Category header uses the same caption/kerning style as `DashboardView`. Empty categories are omitted via `let` filter inside the `ForEach` body.
- **Bug fix — category grid shadow bleed in `AddQuestView`:** Column and row spacing was `theme.spacing.sm` (8 pt); increased to `theme.spacing.md` (12 pt) so neumorphic shadows on adjacent tiles don't overlap. `AddActivityView` already used `md` — the two forms are now consistent.
- **Bug fix — template gallery created duplicate activities:** `AddActivityView.save()` grouped `.create` and `.fromTemplate` together, always calling `context.insert()`. Re-applying a template for an existing activity (e.g. to adjust guidance) silently created a second copy. Fixed by splitting the cases: `.fromTemplate` now fetches all activities, checks for a case-insensitive name match, and updates the existing activity in-place if found. Only inserts if no match exists.

**Key notes:**
- `SectionHeader` in `DashboardView` is `private`, so the home screen inlines the same three-modifier style (`caption`, `textSecondary`, `kerning(2)`) — no abstraction needed for two use sites.
- Pre-migration rows read `category` as `nil` and land in "Other" via `?? .other`. Users can re-categorise via context menu → Edit.
- Template upsert matches by name (case-insensitive). Limitation: if the user renames an activity away from its template name, re-applying creates a new one. Long-term fix (link via `templateId: UUID?`) tracked in `BACKLOG.md`.

**What to pick up next:**
- Await Apple review result; click "Release" on approval.
- History tab (D-012) — still unbuilt.

---

## Session 16 — 2026-05-28

**Focus:** Category system — add `ActivityCategory` to `Activity` and `Quest` models; restructure the Dashboard to group by category with quests → chargers → spenders within each group.

**Design locked (see D-015):** Dashboard replaces the flat charger/spender lists with category-grouped sections. Each non-empty category shows its completed quests first, then chargers, then spenders. Empty sub-groups and empty categories are hidden. Activities and quests default to `.other` for safe lightweight migration of existing rows.

**Files changing:**
- `Models/ActivityTemplate.swift` — rename `TemplateCategory` → `ActivityCategory`, add `.other`
- `Models/Activity.swift` — add `var category: ActivityCategory = .other`
- `Models/Quest.swift` — add `var category: ActivityCategory = .other`
- `Views/AddActivityView.swift` — category picker; auto-filled from template on `.fromTemplate` path
- `Views/AddQuestView.swift` — category picker
- `Models/DashboardStats.swift` — new `CategoryGroup` struct; replace flat lists with `categoryGroups`
- `Views/DashboardView.swift` — render category group sections
- `Localizable.xcstrings` — `category.other` key × 7 languages

**Key gotcha:** SwiftData's `@Model` macro requires fully qualified enum default values (`ActivityCategory.other`, not `.other`). Shorthand triggers *"A default value requires a fully qualified domain named value"*. Documented in `TOOLING.md`.

**Tests:** All 33 tests pass. 4 DashboardStats tests updated to use `categoryGroups` / `flatMap { $0.chargers }` / `flatMap { $0.quests }` instead of the removed `activitySummaries` and `completedQuests` top-level arrays.

**What to pick up next:**
- Await Apple review result; click "Release" on approval.
- History tab (D-012) — still unbuilt.
- Template name review (after gathering parent/kid feedback).

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
