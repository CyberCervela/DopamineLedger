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
