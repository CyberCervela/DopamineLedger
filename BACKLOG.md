# DopamineLedger — Backlog

Items deferred from active development. Verify or ship when ready.

---

## Data ownership

| Item | Notes |
|---|---|
| **Export / Import (backup & restore)** | The full data wipe in Settings → Danger Zone is a one-way operation with no recovery. Export gives users a safety net and full ownership of their data — consistent with the privacy-first philosophy. **Format:** JSON is recommended over CSV: the data has nested structure (activities with linked apps, sessions with multipliers, debts per activity) that maps cleanly to JSON but awkwardly to flat CSV. A single `.dopamineLedger` file (JSON internally, custom extension) is the right deliverable. **Delivery mechanism:** iOS share sheet — the user saves to Files, emails it to themselves, AirDrops to another device, etc. No server, no cloud — consistent with the privacy policy. **What to export:** All Activities (including archived), all Sessions (including creditsMoved), all Quests (including archived), all ActivityDebts, current Ledger balance. **Import / restore:** Replace all current data with the file contents. Not a merge (merge is complex and creates duplicates). Show a confirmation: "This will replace all current data. Are you sure?" **Premium angle:** First mentioned as a potential paid feature (Session 25). Could ship as part of a one-time purchase alongside the pixel-art theme and tip jar — but also valid as a free feature since it costs nothing to serve and directly supports the "no lock-in" philosophy. Decide at monetisation planning time. **Scope note:** This also makes History soft-delete feel safer — users can export first, then wipe. The export should be clearly surfaced near the Danger Zone in Settings. |

---

## UI polish — post-MVP

| Item | Notes |
|---|---|
| **Dark mode fix — SystemTheme neumorphic shadows** | Dark mode is currently broken: the neumorphic dual-shadow pattern (light shadow top-left + dark shadow bottom-right) is designed for light surfaces and inverts badly on dark backgrounds — producing bright white blobs on dark cards. Root cause: shadow colors in `NeuTheme`/`SystemTheme` are hardcoded to light-mode values and don't adapt to `colorScheme`. Fix requires a thorough audit of every shadow call site and defining a separate shadow token pair for dark mode (in dark mode the "light" shadow should be a subtly lighter tint of the surface, not white). This is a full dedicated session — not a quick patch. Do **not** mix with any feature work. Prerequisite: extract `.neuCard()` modifier first (tech debt item) so there is one place to fix rather than 15+. |
| Sheet header buttons (Cancel / Save / Done) neumorphic styling | Buttons have correct pill shape but the header row sits slightly above the scroll content with a visible seam. Root cause: `.presentationBackground` + plain VStack doesn't fully match the navigation bar treatment. Investigate `UISheetPresentationController` background or a sticky-header approach inside the ScrollView. Low priority — buttons are functional and legible. |
| Consolidate `formatDuration` helper | Duplicated in `ActivityListView.swift` and `SessionView.swift`. Extract to a shared `DurationFormatter.swift` or extension on `TimeInterval`. Zero user-visible impact — purely internal cleanup. |

---

## Next session — priority order

| # | Item | Notes |
|---|---|---|
| ✅ | **Explicit start confirmation** | Done Session 22. All taps route through ActivityMenuView. |
| 2 | **Verify icon fix** | Session 21 fixed ActivityMenuView + DebtView to show the user's chosen icon. Confirm Gaming shows `gamecontroller.fill` (not hourglass) in both sheets on device/simulator. |
| ✅ | **App Store screenshots** | Retaken Session 12 at 1284×2778 on iPhone 13 Pro Max simulator. All 6 saved to `screenshots/appstore/`. |
| ✅ | **App Store submission** | Submitted 2026-05-27 22:52. Awaiting Apple review. |
| 3 | **Release** | After Apple approval: click "Release this version" in App Store Connect. |
| ✅ | **Decimal display for sub-1 credit amounts** | Done Session 19. `.fractionLength(0...1)` across all 7 credit display views. |

---

## Post-MVP features

| Item | Notes |
|---|---|
| ~~**Explicit start confirmation before beginning a session**~~ | ✅ Done Session 22. All activity taps route through `ActivityMenuView`. `openActivity()` simplified to always set `activityMenuFor`. `ActivityMenuView` extended with a `.charger` Centre case (green icon, accent Start button, no debt/balance UI). |
| ~~**History tab — bundle repeated short sessions**~~ | ✅ Done Session 26. Consecutive same-activity runs collapse into one expandable row. Sub-2-min blips hidden. See `JOURNAL.md`. |
| **Launch screen — add DL logo above text** | Storyboard + text are live (`LaunchScreen.storyboard`). `LaunchImage.imageset` and `LaunchImage.png` are already in the bundle. Adding the imageView reliably requires Xcode's visual storyboard editor (drag in an UIImageView, set image to "LaunchImage", add centering constraints). 5-minute task in Xcode — do not attempt in raw XML again. |
| **History bundle detail rows — polish** | The compact inner rows shown when a bundle is expanded (time · duration · credits) are functional but visually plain. v1.1 polish pass: consider a subtle left accent bar, slightly more vertical breathing room, or a dimmed separator between rows. Design-first before any code. |
| **Recurring quests — needs design** | Some tasks (chores, weekly habits) are completion-rewarded rather than time-rewarded, and they repeat on a schedule. The current quest model is a one-tap bounty — it disappears once completed. Recurring quests would reappear automatically after a defined cadence (daily, weekly, etc.). Concrete example: "Make your bed" — daily cadence, low friction, and naturally benefits from the Peak Hours bonus if done in the morning. Open design questions before any code: What cadence options make sense? Does the quest re-appear immediately at midnight / start of week, or after a cooldown? What happens if the user skips a cycle — does it stack, expire silently, or flag? How does this interact with the existing Quest model and `isCompleted` flag? Does it need a new model or can we extend `Quest`? Needs a dedicated design session before implementation. |
| **Template catalog name review** | 16 presets shipped (11 chargers, 5 spenders). Names and toggle defaults curated Session 14. User gathering feedback from parents, kids, and friends on whether names like "Homework" vs "School Work" resonate. No code changes until feedback is in. |
| ~~**Linked app catalog — expand with researched apps**~~ | ✅ Done Sessions 34–35. Catalog grew from 8 → 25 apps; templates 19 → 36. **Still needs device verification (spender-side):** Disney+ (`disneyplus://`), Prime Video (`aiv://`), Max (`max://`), Threads (`threads://`), Reddit (`reddit://`), Roblox (`roblox://`), BeReal (`bereal://`). **Still needs device verification (charger-side):** Kindle (`kindle://`), Calm (`calm://`), Notion (`notion://`). **Paramount+ skipped:** `cbsallaccess://` stale; test `paramountplus://` on device before adding. **Netflix watch:** `nflx://` confirmed in repos but tvOS breakage reported Sept 2025; iOS status unclear. **Not added (messaging):** WhatsApp, Telegram — ambiguous use; left as user choice. |
| **Dashboard / stats** | Done — Sessions 6–7. See JOURNAL.md. |
| **`netDelta` accuracy for overrun sessions** | Currently uses base rate × elapsed for spenders; doesn't reflect the 2× debt penalty on overrun. Fix requires storing `balanceAtSessionStart` on `Session` and replaying `SessionMath.apply()` in `DashboardStats.compute()`. Low urgency (stats are directionally correct). Block on before any "weekly summary" notification or export feature. |
| **Consolidate `formatDuration`** | Duplicated in `ActivityListView.swift`, `SessionView.swift`, and `DashboardView.swift`. Extract to `DurationFormatter.swift` or a `TimeInterval` extension. Zero user-visible impact. |
| **Icon system overhaul** | Activities currently have 31 SF Symbols but users gravitate to the same 3–4. Quests have no icons at all. Needs a dedicated ideation + iteration session before coding: (1) audit which icons are actually used vs ignored, (2) expand and re-curate the activity icon set with better categories (productivity, wellness, leisure, social…), (3) add icon support to quests — likely a smaller curated set (trophy, star, checkmark variants, home, book…). Design question to answer first: should quests share the same picker as activities or have their own purpose-built set? No coding until the icon direction is agreed. |
| ~~**History screen**~~ | ✅ Done Session 20 — `HistoryView.swift`, unified timeline, D-012. |
| ~~**SessionView — credits as hero**~~ | ✅ Done Session 20 — 64pt credits hero, human-readable elapsed, "X credits remaining". |
| ~~Decimal display for sub-1 credit amounts~~ | ✅ Done Session 19 |
| ~~Siri / App Intents (Path A)~~ | ✅ Done Session 23. `AppIntents/DopamineLedgerIntents.swift`. 5 intents + AppShortcutsProvider. |
| **Siri phrases — multilingual (v1.1)** | English-only phrases. Other languages need an `AppShortcuts.stringsdict` with per-language variants (e.g. French: "Lance \(\.$activity) dans \(.applicationName)"). Response dialogs also hardcoded English — move to `LocalizedStringResource`. Low priority: Siri works; this is polish for the 6 non-English locales. |
| **Peak Hours multiplier** | 1.5× multiplier on credits earned/spent during a user-defined 6-hour window. Design locked in D-017 and Session 28 journal. Ready to implement. Files: new `PeakHoursService.swift`, `Session.timeMultiplier`, `SessionMath` multiplier param, `SessionFinalizer`, `ActivityListView` (stamp at start), `SessionView` badge, `SettingsView` section, strings. |
| **Peak Hours — chronobiology research links (v1.1)** | Links to research on biological peak hours and how to identify your chronotype, surfaced from the Peak Hours settings section. Deferred from v1 — feature ships without them. |
| **Peak Hours — named profile presets (v1.1)** | "Early Bird" (preset 06:00 start) and "Night Owl" (preset 20:00 start) as quick-start buttons above the time picker. Deferred — the time picker alone covers all chronotypes. |
| HealthKit workout observer (Path B) | Auto-start a charger when a workout begins. Clean signal; requires HealthKit capability + one Settings toggle. Medium confidence. |
| Screen Time API — app-launch interception (Path C) | ⛔ Blocked — API in active regression on iOS 26. See research note below. Re-evaluate after WWDC 2026/2027. |
| Pixel-art theme (Step 7) | Assets not generated; fonts wired but no pixel-art icons yet |

---

## Research note — cross-app automation & voice control

> **Status: research only. No implementation agreed.**
> Written 2026-05-27. Re-read before any coding session that touches this area.
> The goal is to let users start/stop sessions with minimal friction —
> especially for purely offline activities (reading a book, cooking) where
> tapping through the app is a context-breaker, and for digital spender
> activities (YouTube, Instagram) where the phone itself is the "session."

---

### The hard platform constraint

iOS does not expose a "what app is currently open" API. There is no way for
DopamineLedger to passively detect that the user opened YouTube or Instagram.
Apple locked this down entirely for privacy. Any approach that tries to
auto-start a spender session when a distracting app opens must go through
one of the two mechanisms below — there is no third path.

---

### Path A — App Intents + Siri voice (high confidence, build first)

**Frameworks:** `AppIntents` (iOS 16+), `AppShortcutsProvider` (iOS 16.4+)

The modern unified framework for exposing app actions to Siri, Shortcuts,
Spotlight, the Action Button, and the Control Center. Implementing it once
unlocks all of those surfaces simultaneously.

**How it works:**
A struct conforming to `AppIntent` declares a `perform()` method. Registering
intents with `AppShortcutsProvider` pre-registers voice phrases in Siri so they
work the moment the app is installed — no user setup, no shortcut to build.

```swift
// Sketch only — not production code
struct StartSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Session"
    @Parameter(title: "Activity") var activityName: String
    func perform() async throws -> some IntentResult { ... }
}
```

**What this enables for the user:**
- "Hey Siri, start Reading in Dopamine Ledger" → session starts immediately,
  Siri shows a compact confirmation. No screen tap required.
- "Hey Siri, stop Dopamine Ledger" → stops active session.
- "Hey Siri, what's my Dopamine Ledger balance?" → spoken answer, no app launch.
- All of the above also appear automatically in the Shortcuts app, so users
  can build personal automations (Focus mode starts → trigger an intent;
  HomeKit sensor fires → trigger an intent).

**Why this is the right first move:**
This is the cleanest answer to the reading-a-book problem. The user picks up
the book, says the phrase, done. The API is well-supported, stable, and
Apple has actively invested in it across iOS 16–18 / iOS 26. Zero known
regressions. Low implementation risk.

**Phrases to pre-register (App Shortcuts):**
| Intent | Suggested phrase |
|---|---|
| Start session | "Start \<activity name\> in \(.applicationName)" |
| Stop session | "Stop \(.applicationName)" |
| Pause session | "Pause \(.applicationName)" |
| Check balance | "What's my \(.applicationName) balance?" |

**Implementation size estimate:** 1 new Swift file (`DopamineLedger/AppIntents/DopamineLedgerIntents.swift`),
no UI changes, no new capabilities required. `project.yml` glob already covers new subdirectories — no manual pbxproj edit needed.

**Implementation notes (ready to build — 2026-05-29):**

*Structs needed in the one new file:*
- `ActivityAppEntity` — makes `Activity` discoverable as an App Intents entity; Siri uses it to resolve "Reading" → the user's actual activity via fuzzy name matching
- `ActivityAppEntityQuery` — `entities(matching:)` does case-insensitive substring search on activity names; `suggestedEntities()` returns all activities for disambiguation UI
- `StartSessionIntent` — `@Parameter var activity: ActivityAppEntity`; starts session; returns spoken confirmation
- `StopSessionIntent` — stops active session (if any)
- `PauseSessionIntent` + `ResumeSessionIntent` — pause / resume active session
- `CheckBalanceIntent` — returns spoken balance (no parameter)
- `DopamineLedgerShortcuts: AppShortcutsProvider` — registers the 5 phrases; Siri phrases work on install, zero user setup

*SwiftData from AppIntent:* App Intents can run outside the SwiftUI lifecycle (Siri from lock screen, app not open). Cannot use `@Environment(\.modelContext)`. Create a `ModelContainer` directly inside `perform()` — same 5 models as `DopamineLedgerApp`, points at the same on-disk store.

*Debt check in `StartSessionIntent`:* When the user says "Start Gaming" and Gaming has debt (or zero balance, chill mode off) — **block with spoken explanation**: *"You have debt on Gaming. Open Dopamine Ledger to resolve it first."* Read `UserDefaults.standard.bool(forKey: "chillMode")` — if chill mode is on, start anyway. This matches the in-app philosophy; voice commands should respect the same rules as taps.

---

### Path B — HealthKit workout observer (medium confidence, clean signal)

**Framework:** `HealthKit` (iOS 8+, well-established)

When the user starts a workout in the Fitness app or any third-party fitness
app (Strava, Nike Run Club, etc.), HealthKit fires an observer query.
DopamineLedger can listen for this and auto-start a designated charger.

**How it works:**
- User configures in DL Settings: "When a workout starts → auto-start [Exercise]."
- A background `HKObserverQuery` on `HKWorkoutType` fires when a workout begins.
- DL starts the session; optionally auto-stops when the workout ends.

**Signal quality:** Clean and unambiguous — a workout start is a meaningful
life event. No false positives from the user just unlocking their phone.

**What it requires:**
- `HealthKit` capability added to `project.yml` and entitlements.
- A privacy usage description in `Info.plist`
  (`NSHealthShareUsageDescription`, read-only — no write needed).
- A new Settings toggle (opt-in, off by default).
- Background delivery enabled (`enableBackgroundDelivery(for:frequency:)`).

**Risk:** HealthKit requires a device (no simulator support for workout
observation). Must be tested on physical hardware.

---

### Path C — Screen Time API / app-launch interception ⛔ BLOCKED

> **Blocked as of 2026-05-28. Do not implement until unblocked.**
> Unblock trigger: Apple stabilises the API in a future iOS 26 point release,
> or WWDC 2026/2027 announces meaningful improvements. Re-evaluate then.
> The research below is preserved so we don't repeat the investigation.

**Frameworks:** `FamilyControls`, `ManagedSettings`, `DeviceActivity` (iOS 16+)

This is the mechanism used by One Sec, Opal, ScreenZen, and similar apps.
It is the only way to detect that the user is about to open a specific app
(YouTube, Instagram, etc.) and act on it — but it comes with significant
fragility.

**How it works:**
The user authorises DL to "manage" a set of apps they choose (via the system
`FamilyActivityPicker` UI — DL never sees the app names, only opaque tokens).
DL marks those apps as "shielded" via `ManagedSettings`. When the user taps
YouTube, iOS intercepts the launch and displays DL's custom shield view
(`ShieldConfigurationDataSource` extension). DL can show a brief confirmation
("Starting Doomscrolling — 2h balance remaining"), start the session, then
dismiss the shield and let the app open.

**What this would enable:**
- Automatic spender session start the moment the user opens a designated app.
- A brief "you're spending" moment of intentional friction (like One Sec) —
  this actually aligns well with the anti-engagement philosophy.

**Important clarification — no retroactive data:**
`DeviceActivity` fires threshold callbacks (e.g. "user exceeded 30 min of
YouTube today") but does not expose raw usage data. You cannot query "how long
did the user spend on YouTube between 2pm and 3pm." That data is locked in
Apple's system and inaccessible to third-party apps. Any auto-session trigger
via this path is prospective (intercept the launch) — never retroactive.

**Why it is blocked (as of 2026):**
The Screen Time API has well-documented, long-standing issues that are
actively getting worse on iOS 26. Specifically:

| Issue | Impact on DL |
|---|---|
| Random token regeneration (iOS re-issues opaque app tokens unpredictably) | The shield extension receives a token it has never seen; can't determine which activity to start |
| 6 MB memory cap on the `DeviceActivityMonitor` extension | Extension crashes under normal load; One Sec's developer has filed this as a radar since iOS 15 — unfixed |
| iOS 26 `eventDidReachThreshold` regression | Threshold fires immediately (seconds) instead of at the configured time; only workaround is re-requesting permissions, which resets every ~2 weeks |
| No "app closed" signal | `DeviceActivityMonitor` fires on usage thresholds, not on individual app close events; stopping a session when the user exits YouTube has no clean trigger |
| User can disable at any time | Settings → Screen Time → [App] toggle removes all restrictions instantly, with no callback to DL |
| Requires special Apple entitlement | `com.apple.developer.family-controls` requires App Store review justification; not guaranteed to be approved |

One Sec — the most sophisticated app built on this stack — has an entire
support page dedicated to "Screen Time API issues" and asks users to grant
permissions repeatedly because the system silently breaks them.

---

### The Shortcuts bridge — detail

#### Who "the user" is in this context

"The user" throughout this section means the **DopamineLedger app user** —
the person with DL on their iPhone. Not us, the developers.

#### The hard boundary (what iOS will never allow)

An app cannot create Shortcuts automations on the user's behalf. DL will
never be able to silently write a rule into someone's Shortcuts app that
says "when Instagram opens, start Doomscrolling." iOS treats that as a
security boundary: automations have system-wide side effects and allowing
any installed app to create them invisibly would be an attack surface.
This is not a gap we can engineer around.

#### What the app user would do manually (once)

After we ship Path A:
1. User opens the iOS **Shortcuts** app (pre-installed on every iPhone)
2. Taps **Automation → New Automation**
3. Picks a trigger: "App → Instagram → Is Opened"
4. Adds action: searches "Dopamine Ledger" → picks "Start Session" → selects activity
5. Saves. Done forever.

From that point, every time they open Instagram, the automation fires
silently and DL starts the session. No further interaction needed.

Trigger examples the user can build for themselves once intents exist:

| Trigger | Action |
|---|---|
| "When I open [app]" (iOS Automation) | Run `StartSessionIntent` |
| "When Work Focus turns on" | Run `StartSessionIntent` for Work charger |
| "When I arrive home" (location) | Run `StopSessionIntent` |
| HomeKit sensor fires | Run any intent |
| NFC tag tap (sticker on desk, book, etc.) | Run `StartSessionIntent` for Reading |

#### What we can do to get close to automatic — three mechanisms

The "open YouTube → start session" automation always needs a human to
configure it once. But we can reduce that friction significantly, and for
simpler patterns (time-based habits) we can get close to zero setup:

**1. Intent donation + Siri Suggestions (closest to automatic)**
When a user performs an action in DL — e.g. starts Reading every evening
at 9pm — iOS watches that pattern. If we donate the intent each time it's
performed (standard App Intents behaviour), iOS's on-device ML engine learns
the habit and proactively surfaces a suggestion on the lock screen, in
Spotlight, and in Siri Suggestions. No user setup required. We can
additionally use `RelevantIntentManager` to explicitly hint "this intent is
likely relevant right now" (e.g. at the user's habitual cooking time).
The user sees: *"Start Reading" appears on their lock screen at 9pm.*
One tap. No prior setup from them.

**2. Shareable `.shortcut` files (one-tap import)**
We can host pre-built Shortcuts as `.shortcut` files — on a web page or
linked from inside the app. User taps the link, iOS opens Shortcuts with
the workflow pre-loaded, user taps "Add." One tap.
*Limitation:* this works for manual Shortcuts (voice, tap) but not for
personal automations with automatic triggers (app-open, location, Focus).
Those triggers always require the user to set them manually — Apple
explicitly blocks sharing automation triggers via file.

**3. `SiriTipView` — in-app contextual nudge**
App Intents ships a ready-made `SiriTipView` component. Show it inside DL
at the right moment (e.g. right after the user manually starts Reading for
the first time) and it renders: *"Say 'Hey Siri, start Reading in Dopamine
Ledger.'"* Not automation, but teaching the shortcut in context where it
lands best.

Summary:

| Mechanism | Human action required? | What it achieves |
|---|---|---|
| Intent donation + Siri Suggestions | None after first natural use | iOS learns patterns; surfaces on lock screen |
| `RelevantIntentManager` hints | None | We nudge iOS to surface the right intent |
| Shareable `.shortcut` file | One tap to import | Pre-built voice shortcut; not for auto triggers |
| `SiriTipView` in-app | One tap on the tip | Teaches Siri phrase in context |
| Full automation (open YouTube → session) | One-time manual setup | Trigger must be set by a human |

#### Philosophical note

This framing — teach the user to set things up intentionally, rather than
wiring their phone for them — is actually a good fit for DopamineLedger's
anti-engagement design principles. Nudging someone to consciously configure
a habit automation is itself a small act of intentionality. We should not
over-engineer this into a "do it all for you" feature.

---

### Recommended implementation order

| Priority | Path | Reason |
|---|---|---|
| 1 | **App Intents + Siri (Path A)** | Solves the reading-book problem immediately; stable API; unlocks Shortcuts bridge for free |
| 2 | **HealthKit observer (Path B)** | Clean signal; meaningful for fitness chargers; self-contained |
| 3 | **Shortcuts tip in Settings** | Documents the YouTube/Home automation pattern; zero code |
| ⛔ | **Screen Time API (Path C)** | Blocked — API in active regression on iOS 26. Re-evaluate after WWDC 2026/2027 or a stabilising point release. |

---

### Sources consulted (2026-05-27)

- [One Sec — Screen Time API Issues (support page)](https://tutorials.one-sec.app/en/articles/3036354)
- [State of the Screen Time API (riedel.wtf, 2024)](https://riedel.wtf/state-of-the-screen-time-api-2024/)
- [Developer's Guide to Apple's Screen Time APIs (Medium / Julius Brussee)](https://medium.com/@juliusbrussee/a-developers-guide-to-apple-s-screen-time-apis-familycontrols-managedsettings-deviceactivity-e660147367d7)
- [Apple's Screen Time API: How It Broke Me (Habit Doom)](https://habitdoom.com/blog/apple-screen-time-api-guide)
- [ShieldConfigurationDataSource tutorial (Medium / John Baker)](https://medium.com/@B4k3R/creating-a-screentime-shieldconfigurationdatasource-for-ios-familycontrols-api-5ca1079d3188)
- [App Intents + AppShortcutsProvider (createwithswift.com)](https://www.createwithswift.com/performing-your-app-actions-with-siri-through-app-shortcuts-provider/)
- [WWDC22: Implement App Shortcuts with App Intents (Apple)](https://developer.apple.com/videos/play/wwdc2022/10170/)

---

## History — timezone-aware day bundling

> **Status: edge-case note — no action needed now. Flag when History pagination or a "this day" grouping redesign comes up.**

The session bundling algorithm in `HistoryView.dayGroups` groups sessions by calendar day using `Calendar.current` — which reflects the device's timezone at query time. A user who travels across timezones (e.g. Southeast Asia → Switzerland, UTC+7 → UTC+1) may see bundles split or merged incorrectly: `startedAt` timestamps are stored in UTC, and when the device timezone shifts, those timestamps land on different local dates than when they were recorded. A session started at 23:30 local time in Bangkok becomes 17:30 in Zurich — it moves to a different day group and may break or create a consecutive bundle across the timezone boundary. No fix needed until the History redesign or pagination work, when a locale-stable grouping key (e.g. storing the local date string at session-creation time) should be considered.

---

## Performance — History tab at scale

> **Status: proactive note — no action needed now. Revisit before v1.1 or when a power user reports slowness.**

`HistoryView` currently fetches **all sessions and all quests** in a single `@Query`, then runs the bundling/blip-filtering algorithm client-side on the full dataset before any UI renders. For a v1.0 user with a handful of sessions this is fine. At scale it becomes a problem.

**When it hurts:** A power user logging 5+ sessions/day accumulates ~1 800 session rows in a year. Fetching and walking all of them on every tab switch will produce a measurable first-render pause, and SwiftData loads rows into memory before any display happens.

**Root cause:** The bundling algorithm (`dayGroups` computed property) has to see the full sorted list to detect consecutive same-activity runs correctly — a bundle boundary only becomes visible when the *next* item in the sequence differs. This makes a naïve "fetch the first N rows and stop" approach break at window edges (the first visible session of a new page might be the tail of a bundle that started on the previous page).

**Likely fix path when the time comes:**

1. **Day-based windowed fetch.** Instead of fetching all sessions, fetch sessions in calendar-day chunks using `FetchDescriptor` with a date predicate (`startedAt >= windowStart`). Load the most recent 30 days on first render; append the next 30 days when the user scrolls to the bottom.
2. **Bundle-safe window edges.** When appending a new window, fetch one extra day of context before the window start so the bundling algorithm can detect whether the first session in the new page continues a run from the previous page.
3. **`LazyVStack` + on-appear trigger.** Replace the current `ForEach` inside the `ScrollView` with a `LazyVStack`. A sentinel row at the bottom fires an `.onAppear` that appends the next window. Standard iOS infinite-scroll pattern.
4. **No DB schema changes needed.** `FetchDescriptor` date predicates work against the existing `startedAt` field on `Session`. The bundling logic can stay pure-Swift — it just operates on a smaller input slice.

**What not to do early:** Don't pre-aggregate or denormalize history into a separate table just to speed up reads. The query cost at < 500 rows is negligible and premature denormalization adds a consistency burden every time a session is mutated.

**Trigger to act:** User-reported lag on the History tab, or internal benchmark showing > 100 ms render time at 500+ sessions. Until then, leave the current approach in place.

---

## Technical debt / architecture improvements

From the Session 9 codebase audit (2026-05-26). The audit found **no ship-blockers** —
all items below are post-launch cleanup. Ordered roughly by value. None should delay
App Store submission.

### High value

| Item | Detail |
|---|---|
| **Link `ActivityTemplate` to `Activity` via UUID** | Template re-apply currently matches by name (case-insensitive). Works fine while template names are unique, but breaks silently if the user renames an activity away from its template name. Fix: add an optional `templateId: UUID?` field to `Activity`, written at creation time from `.fromTemplate` mode. The upsert in `AddActivityView.save()` then matches on `templateId` first, falling back to name for activities created before this field existed. Low urgency — name matching is good enough for the current template library size. |
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
