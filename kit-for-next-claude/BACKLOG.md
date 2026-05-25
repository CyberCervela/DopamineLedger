# Backlog — Dopamine Ledger

Future improvements not part of the current MVP scope. Keep this list
short and merge into CLAUDE.md (or close as out-of-scope) when each item
is acted on.

---

> **Implemented (2026-05-25):** Active-session indicator, per-activity debt chip,
> unconstrained icon picker, and About section in Settings are now shipped.
> Step 7 (pixel-art polish) is moved to the long-term backlog below.

---

## Active-session indicator on the home screen ✅ Done

When a session is running (charger or spender), the activity list gives
no visual cue that one of the rows is currently "live." A user navigating
back from `SessionView` may forget a session is still ticking.

**Ideas to consider:**
- A small pulsing dot or "● LIVE" badge on the active row.
- A subtle row-background tint (Theme.charger-faint for active chargers,
  Theme.spender-faint for spenders).
- A persistent banner above the BalanceCard: *"Reading — 12:34 elapsed"*
  that tapping deep-links back into the SessionView.
- The BalanceCard itself could grow a "currently earning/spending at X/min"
  subtitle while a session is active.

Decide on one (or layer two) when ready. This is mostly a polish item —
not urgent, but valuable for the "background it" use case where the user
may genuinely forget a session is running.

## Per-activity debt visible on the spender row ✅ Done

Today, debt is surfaced in two places:

- `BalanceCard` at the top of the home screen — but only as an aggregate
  (*"22.6 debt across 1 activity"*) without naming which one.
- Inside the `SessionView`, behind a tap — the amber "Activity is blocked"
  warning appears only after the user drills in.

The spender row itself shows just name + rate. So a user can't tell at
a glance *"which of my spenders is the one I owe credits for, and how
much."* They have to either guess from the aggregate or tap into each
spender to check.

**Idea:** put a per-activity debt indicator on the spender row itself.

**Options to consider:**
- A small amber chip on the right edge of the row: *"⚠ 22.6 in debt"*
- A "🔒 Blocked" badge that doubles as a visual indicator
- A subtle amber row-background tint when the activity has debt
- A second line under the rate: *"−5 credits/min · ⚠ 22.6 in debt"*

Symmetry question to settle when speccing: should chargers also show
"last earned" or similar? Probably no — debt is something the user
needs to *act on*; charger history is just stats (belongs in the
dashboard backlog entry).

**Implementation note (when picked up):** the data already exists.
`ActivityDebt` rows are linked to activities by `activityId`. The work
is just a query (sum `amount` per spender id) + display on the row,
plus the visual treatment.

Out of MVP scope but a small lift — could be folded into the design
pass alongside the active-session indicator.

## Unconstrained icon picker ✅ Done

Currently the icon picker in `AddActivityView` filters icons by activity
kind (chargers see only charger-tagged + any-tagged icons; spenders see
only spender + any). Similar filter on `AddQuestView` (quest + any).

The intent was to make selection less overwhelming, but it's overly
restrictive — a user creating a "Baking" charger might genuinely want
to use a donut icon (currently tagged `spender`) because that's what
they bake. The kind tag was meant as a *suggestion*, not a constraint.

**Idea:** show ALL icons in the picker, still grouped by category.
Keep the `kind` field in the catalog for documentation / future grouping
(e.g., "Suggested for chargers" section at the top, then everything else
below), but never *exclude* an icon from the picker.

**Implementation note (when picked up):** in `AddActivityView` and
`AddQuestView`, change `IconCatalog.shared.icons(for: kind)` and
`.iconsForQuests()` to just iterate `IconCatalog.shared.icons` directly,
then group by tag as before.

Small lift (~5 minutes). Could be done alongside any future picker
polish (search, recent-icons, favorites).

## Editing quests

Activities can be edited via the pencil icon in `SessionView` (with the
"no edits mid-session" exploit guard). Quests have no equivalent — once
created, they can only be marked Done or deleted (swipe). A user who
defines a quest with the wrong payoff or a typo'd name has to delete
and re-add. Not catastrophic, but rough on the "this is a real task
I'm committing to" psychology.

**Idea:** add an edit affordance to the quest row.

**Options to consider:**
- Long-press the row to reveal Edit + Delete in a context menu.
- Tap the row body (not the Done button) → opens an `EditQuestView`.
- Swipe the leading edge to reveal Edit (paired with the existing
  trailing swipe-to-delete). This is the iOS-standard "left edit,
  right delete" pattern.

**Implementation note (when picked up):** mirror what `AddActivityView`
did — refactor `AddQuestView` to take a `Mode` enum (`.create` /
`.edit(Quest)`), pre-fill the form in edit mode, and mutate the
existing quest on Save instead of inserting.

Out of MVP scope. Small lift — same pattern we used for the
edit-activity flow.

## Dashboard / activity tracker

Out of MVP scope, but worth designing for once the core loop is solid.
Inspired by the streak + analytics patterns from meditation apps
(Calm, Insight Timer), fitness apps (Apple Fitness rings, Strava), and
reading apps (Kindle/Goodreads stats).

**Two intertwined sub-features:**

1. **Streaks** — win/loss streaks tied to the user's habits.
   - "Reading streak: 12 days" — consecutive days with at least one
     Reading charger session of >X minutes.
   - "Debt-free streak: 4 days" — consecutive days where no spender
     overran into debt.
   - Quest streaks — *"Quests this week: 3 completed"*.

2. **General stats / time breakdown**
   - Hours per week/month/year per activity (chargers AND spenders).
   - Total credits earned and spent over time.
   - Best-performing chargers, worst-offending spenders.
   - Average session length per activity.
   - Quest history — what was accomplished when, payoff amounts.

**Likely surface:** a third tab (or "Dashboard" entry in Settings) with
calendar-heatmap-style visualizations + per-activity drill-downs. Will
want a charting solution (Swift Charts is built-in since iOS 16, perfect
fit).

User to refine the proper spec later — capturing the intent here so we
don't lose it during the MVP push.

## Decimal display for sub-1 credit amounts

The number formatter currently uses `.precision(.fractionLength(0...1))`,
which renders sub-1 values like `0.04` as just `"0"`. Result: occasionally
misleading copy like *"0 credits debt across 1 activity"* or *"+0 credits
banked"* on very-short sessions.

The math is correct — only the display loses precision.

**Options when polishing:**
- Show `0...2` fraction digits below `1.0`, `0...1` above (conditional
  formatter).
- Use `.precision(.significantDigits(2))` so small values keep meaning
  (`0.04` stays `"0.04"`, `127.5` stays `"128"` — trade-off).
- Hide rows/lines entirely when the amount is below a threshold (e.g.,
  `< 0.1`), since they're cosmetically uninteresting.
- Round up to a minimum displayable unit (e.g., always show ≥ 0.1).

Likely the conditional formatter is the cleanest answer — keep big
numbers readable, small numbers honest.

## "How long can I keep going?" — estimated burn-down on spenders

Today, a spender row tells you the rate (e.g. *"−5 credits/min"*) and the
home screen tells you the balance (e.g. *"42 credits"*). The user has
to do the division in their head to answer the actual question they
care about: *"how many minutes of this can I afford right now?"*

**Idea:** surface the answer directly on each spender, derived from
`globalBalance / spender.rate`.

**Display options to consider:**
- On the spender row: a subtle subtitle under the rate — *"~8 min left
  at this rate"*.
- Inside `SessionView`: a "time remaining until empty" pill next to the
  live balance footer (counts down in real time alongside the timer).
- A pre-start preview on the start button itself — *"Start (8 min)"*.

**Edge cases to settle when speccing:**
- Activity is blocked (has debt) → suppress the estimate, show the
  block reason instead.
- Balance ≤ 0 → already blocked by the empty-balance rule; suppress.
- Charger is currently running and topping up the balance → ideally
  account for the net rate (`spender.rate − activeCharger.rate`); if
  the result is negative or zero, show *"sustained — earning faster
  than spending"*.
- Rate is `0` → impossible (we validate `> 0` on create), no special case.

**Implementation note:** the math is trivial and side-effect-free —
extract into a pure function (`SessionMath.minutesRemaining(balance:rate:)`)
and unit-test alongside the existing `SessionMath` cases.

Small lift, high "obvious value" payoff. Pairs naturally with the
per-activity debt indicator and the active-session indicator —
all three are "make the spender row tell the truth at a glance."

## Chargers show what they buy — top-3 spender equivalencies

The dual to the burn-down estimate above: a charger row currently
tells you the rate it earns at, but not what that earning *unlocks*.
The user's actual mental model is *"is one hour of learning worth it
for X minutes of gaming?"* — that exchange-rate framing is what makes
the credit economy feel real, and it's exactly the lever that should
nudge behavior at the moment of choosing what to start.

**Idea:** on each charger row (or in its SessionView), show what one
unit of this charger buys across the user's top spenders.

**Display options to consider:**
- On the charger row: a third line of small caption text —
  *"1h earns: 15 min gaming · 30 min TV · 12 min social"*.
- In `SessionView` for chargers: a "what you've earned so far" block
  that updates live alongside the timer — *"You've banked 12 credits
  ≈ 4 min gaming, 8 min TV"*.
- A toast variant on Charger Stop: *"+18 credits banked — that's ~6
  min of gaming"*. The reward feedback gets concrete.

**Which spenders to show:**
- "Top 3" by some signal: most credits spent over the last 7/30 days,
  or most-recently-used, or user-pinned. **Default to most credits
  spent in last 30 days** — that's the actual "what I keep doing"
  truth. Pinning is a v2 nicety.
- Hide entirely if the user has fewer than 3 spenders (or fewer than
  any) — graceful degradation.

**Edge cases to settle when speccing:**
- A spender is currently blocked with debt → still show the equivalency,
  but flag it: *"15 min gaming (currently blocked)"*. Reinforces that
  earning here also unblocks future use.
- Spender rates change over time → recomputed on the fly each render,
  no caching needed (cheap math).

**Implementation note:** pairs with the same pure helper as above —
`SessionMath.equivalentMinutes(creditsEarned:atRate:)`. Add a query
helper that returns the user's top-N spenders by 30-day credit spend.

This and the burn-down estimate are two halves of the same UX
insight: **credits are abstract, time is concrete**. Surface the
time-equivalent everywhere we currently surface credits.

## Auto-trigger sessions from external apps / IoT

The seamless ideal: open YouTube → a YouTube spender starts automatically.
Close it → it stops. Start an Apple Watch workout → Fitness charger
auto-runs. No manual tapping for things the OS already knows about.

This could legitimately be the product's moat: *"the dopamine ledger
that knows what you actually do."* But iOS's privacy architecture
imposes hard limits, so it's worth understanding what's realistic
before scoping.

### Apple's official surface: Screen Time API (iOS 15+)

Three frameworks work together:

- **`FamilyControls`** — gets the user's permission to monitor app usage.
  Two authorization modes:
  - `.individual` — for self-management (us). Available to any developer,
    no special entitlement required.
  - `.child` — for parental controls. Needs Apple-granted "Family Controls"
    entitlement.
- **`DeviceActivity`** — schedules monitoring events. Background extension
  fires when criteria are met.
- **`ManagedSettings`** — restrict/block apps. Parental-control territory;
  we wouldn't use.

**Flow we'd build:**

1. First-launch: user grants Screen Time authorization via system prompt.
2. Show Apple's `FamilyActivityPicker` — a system UI that lets the user
   pick apps/categories to monitor (Social, Entertainment, or specific
   apps). *We can't bypass this picker — it's Apple's UI.*
3. Register usage thresholds with `DeviceActivityCenter`: *"notify me when
   these apps have been used for 1 minute today."*
4. iOS calls a background extension we ship when a threshold fires.

**Hard limitations to be honest about:**

| Limitation | Implication for our app |
|---|---|
| No raw "app opened" events | We can only react to *thresholds* (X minutes used), not launches. So we can't auto-start a session the instant YouTube opens — only after some accumulated usage. |
| Latency | System fires events on its own schedule (seconds to minutes after threshold). Not real-time. |
| App identities are opaque | The picker returns anonymized `ApplicationToken`s. We literally cannot tell which token is YouTube vs Twitter — Apple deliberately strips this for privacy. |
| User picks the apps, not us | No way to programmatically say *"monitor YouTube."* User sees Apple's picker. |

So Screen Time gives us **generic categorical awareness** — *"the user
has spent against the apps they marked as distractions"* — but **not
specific-app awareness** like *"auto-start a Twitter session."*

### User-driven alternative: Shortcuts Automation

iOS Shortcuts has Personal Automations. The user can set up:
*"When app X opens → run shortcut → call DopamineLedger via an App Intent."*

| Trade-off | Detail |
|---|---|
| ✅ Specific app awareness | User tells us *"this automation is for Twitter,"* so we know exactly what's being tracked |
| ✅ No special entitlement | Ships today, no Apple review hurdle |
| ❌ One-time manual setup per app | User creates the automation themselves — discoverability friction |
| ❌ Triggers on launch only | Doesn't notify when the app closes — we'd need a heuristic timer |

This is the path **Opal**, **One Sec**, **Forest** and similar apps
already use today. Realistic indie-app stack for 2026.

### Other useful angles

- **HealthKit** — workout sessions, step counts, heart rate. Could
  auto-start a Fitness charger when an Apple Watch workout begins.
  Well-supported, no special entitlement needed.
- **HomeKit** — smart plug under the TV turns on → auto-start a TV
  spender. Niche but real.
- **Focus Modes** — user creates a "Doomscrolling" Focus that activates
  with certain apps; we listen for the Focus turning on. Indirect.
- **Location** — geofence the gym for auto Fitness charger. Crude but
  works.

### What Apple flat-out won't let us do

- ❌ Enumerate installed apps on the device
- ❌ Observe what app is currently in foreground
- ❌ Subscribe to app launch events for arbitrary apps in real-time
- ❌ Read another app's data, traffic, or state
- ❌ Anything that would let us silently track without explicit opt-in

These are iOS sandboxing fundamentals. No workaround on stock iOS —
jailbreak only, which is a commercial non-starter.

### Recommended phasing

1. **Phase 1 — Shortcuts integration.** User-driven, app-specific,
   ships first. *"When YouTube opens → start YouTube session"* per app.
2. **Phase 2 — HealthKit chargers.** Auto-detect workouts and meditation
   sessions. Apple Watch users get charger sessions for free.
3. **Phase 3 — Screen Time API.** Coarse-grained anonymous bucket:
   *"You've spent 12 min today on apps you flagged as distractions."*
   No per-app setup needed, but no per-app specificity either.

The fully passive + fully automatic + fully app-specific dream **cannot
exist on iOS** by design. But realistically ~80% of the value can be
delivered with the stack above.

Out of MVP scope. Captured here in detail so we don't lose the
research when we're ready to spec it.

