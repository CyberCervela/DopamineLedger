# DopamineLedger — Product Philosophy

> This document captures the *why* behind the app — the values that should
> guide every feature decision, design trade-off, and piece of copy. Read it
> before proposing new features. If a feature contradicts something written
> here, the feature needs to change, not the philosophy.
>
> This is a living document. Add to it as the thinking deepens. Do not water
> it down to justify shipping something that doesn't belong.

---

## The three pillars

### 1. Extreme unitasking

The app exists to help users give their full attention to one thing at a time —
whether that thing is work, rest, movement, or play. The enemy is not any
particular activity; it is the half-present state of doing one thing while
mentally elsewhere.

What this means in practice:

- A charger session is not background music for something else. It is the thing.
- A spender session is not a guilty indulgence to be minimised — it is a
  conscious, fully-owned choice. The user chose to spend. They know what it
  costs.
- The app should never compete for attention while a session is running.
  Notifications, nudges, and interruptions during an active session are
  anti-features.
- One active session at a time is not a technical limitation. It is a
  philosophical constraint.

*This pillar is already enforced in the code — you cannot start a second
activity while one is running. Do not relax this rule without understanding
what it costs.*

---

### 2. Create more than you consume

The credit economy is not arbitrary. It encodes a value judgment: activities
that build something — a skill, a piece of work, a healthier body, a
relationship, a rested mind — are worth more than activities that consume
something already made by someone else.

A charger is ideally something that leaves a mark on the world, or on the
person:

- Writing, coding, drawing, cooking, exercising, reading (building knowledge),
  learning an instrument.
- Deep conversation with a close friend or an interesting person — this is
  one of the most meaningful things a human being can do. It creates
  connection, understanding, and shared meaning that didn't exist before the
  conversation. It belongs here without qualification. (Shallow conversation,
  gossip, and small talk do not carry the same weight — but the app never
  makes this judgment for the user. The distinction is noted here as
  philosophy, not as a rule the app enforces. Labelling someone's social
  life as "shallow" would be intrusive and presumptuous. The user decides
  what their time is worth.)
- Rest and recovery also qualify — a rested mind is a more creative one.
  The key is that the rest is *intentional* and *complete*, not a numbing.

A spender is something that primarily consumes:

- Scrolling, streaming, browsing — not inherently bad, but tilted toward
  receiving rather than producing.

The 2:1 earn/burn ratio is not punitive. It is a structural reminder that
consumption should be earned by creation. The rates the user sets are
theirs to choose — the system just keeps score honestly.

*When designing new features, ask: does this make it easier to create, or
easier to consume? Features that make consumption frictionless without a
corresponding increase in creative capacity are suspect.*

---

### 3. The app should make itself unnecessary

The long-term goal is not engagement. It is the opposite.

A user who has fully internalised the credit economy — who has enough
self-regulation, enough awareness of their own dopamine patterns, enough
automatic habit of choosing creation over consumption — no longer needs the
app. That is the success state.

This means:

- No streaks, no badges, no "come back tomorrow" mechanics. These are
  engagement traps disguised as rewards.
- No push to use the app more, log more sessions, or hit daily targets.
- No social features. Comparison is a different kind of dopamine trap.
- Features that help users *understand* themselves are good.
  Features that make users *dependent* on the app are not.

*The privacy policy's "no data collection" commitment is the technical
expression of this pillar. The anti-engagement design rules in
`notification_strategy.md` are its operational expression.*

---

---

## The app as a gate, not a door

Most apps want to be opened as effortlessly as possible. DL inverts this for
consumption: for spender activities linked to a third-party app (YouTube,
Instagram, TikTok, etc.), DL becomes the mandatory first step.

The user opens DL → starts the session → *then* taps "Open YouTube →".
The app they want is one deliberate tap away, not one reflex tap away.

**Why this matters:**

The home screen is a wall of instant gratification. Every icon is an open door
— zero friction between impulse and action. The gatekeeper feature replaces
that reflex with a moment of awareness: *I am choosing to spend credits on
this. I know what it costs. I am starting the clock.*

That moment is the product. Not the tracking, not the balance number — the
pause before the action.

**Why auto-launch was rejected:**

When we built this feature, the technically easy path was to auto-open YouTube
the moment the session starts. We rejected it. If the app opens automatically,
DL becomes a launcher with a timer attached — the intentional moment disappears
entirely. The gate must have a handle the user consciously turns.

**Why the friction is the credit system, not the UI:**

The "Open YouTube →" button has no delay, no confirmation, no second
are-you-sure screen. The friction is the session that is already running — the
clock ticking, the credits moving, the debt risk accumulating. That is
sufficient. Adding UI friction on top of credit friction is patronising and
produces the kind of dark-pattern energy the app is trying to counter.

One conscious tap. Session running first. App opens second. The sequence is the
point.

**Why this is philosophically different from One Sec / Opal:**

One Sec and Opal intercept app launches via the Screen Time API — they
*block* apps until you complete a pause ritual. Their model is adversarial: the
app is bad, the user needs to be stopped.

DL's model is collaborative: the activity is worth tracking, the user is in
control, and the credit system is the honest accounting of what they chose.
DL does not decide YouTube is bad. It just makes the choice visible and
ensures the session clock starts before the content does.

---

## Open questions — to be fleshed out

These ideas have been raised but not fully resolved. Do not treat them as
settled policy yet.

- **What about rest?** Full rest (sleep, intentional doing-nothing) earns
  credits as a charger in the current model — but only if the user explicitly
  logs it. Is that right? Or is logged rest just another form of
  self-surveillance that the philosophy should resist?

- **Recurring obligations** — some things (chores, weekly habits) are
  completion-rewarded rather than time-rewarded, and they repeat. How do
  recurring quests fit into the "create more than you consume" framing?
  Chores are neither creative nor consumptive — they are maintenance.
  See `BACKLOG.md` for the open design item.

- **The transition off the app** — if the goal is eventual non-use, should
  the app ever surface this explicitly? A "you haven't needed me in 30 days"
  message is conceptually aligned, but could also read as a guilt trip.
  Worth thinking through before building anything in this space.
