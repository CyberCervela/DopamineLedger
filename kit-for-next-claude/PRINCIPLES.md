# PRINCIPLES.md — Architecture principles for Dopamine Ledger

The structural habits that have paid off across both rounds of this app,
plus the ones the Session 9 technical-debt audit wished had been explicit
from the start. These are defaults backed by real evidence in this
codebase — not abstract rules. `ARCHITECTURE.md` describes the layout;
this file explains the *why* behind it.

---

## 0. The layer cake: every layer calls down, none calls up

```
Views (SwiftUI)      → consume Theme via @Environment; no business math
Services             → touch SwiftData + system APIs; apply math results
Math (pure functions)→ no SwiftData, no system APIs; unit-testable
Models (@Model)      → persistence + a few computed helpers
```

Models don't know about services; services don't know about views; views
don't know about persistence beyond `@Query` / `ModelContext`. When this
holds, each layer is testable and replaceable in isolation. (Full diagram
in `ARCHITECTURE.md`.)

---

## 1. Pure logic core, separated from framework and UI

The credit/debt/scheduling rules live in `SessionMath`, `RepayMath`,
`NotificationMath`, and `DashboardStats` — `enum`s of `static` functions
that take primitives in and return small structs out. No SwiftData, no
SwiftUI.

**Payoff, concretely:** `DopamineLedgerTests` covers all four with 33
cases and **zero** `ModelContainer` setup. When a rule changes ("make the
debt penalty 1.5× instead of 2×"), there is exactly one file to edit and
the test tells you instantly if you broke an edge case.

**Rule:** if you reach for business math in a view or service, stop and
extract a `*Math.swift` first.

---

## 2. Test the glue, not just the pure core  ⚠ known gap

This is the one the Session 9 audit flagged. The pure math has 33 tests —
but the **stateful glue that writes to SwiftData has zero**:
`SessionFinalizer.finalize` (balance write + debt-row insert) and the
repay flows in `DebtView.repay` / `ActivityMenuView.repay`
(`RepayMath.split` + `repaidAt` stamping). Those are the
highest-consequence mutations in the app, and a green suite over the easy
layer hid that they were untested.

**Rule:** for every flow that mutates persistent state, write at least one
integration test against an in-memory `ModelContainer`. Pure-function
coverage is necessary, not sufficient. (Tracked in `BACKLOG.md` → tech
debt, High value.)

---

## 3. Extract a shared helper on the *second* use — for logic AND views

Done well for services: `SessionFinalizer` emerged from two call sites
(SessionView Stop + SettingsView global stop), `NotificationScheduler`
from two (session start + resume). They prevent the two flows from
drifting — fix a bug once, both get it.

**Where we slipped:** the same trigger was never applied to *view styling*.
The neumorphic card chain (`.background(surface)` → `.clipShape` → two
`.shadow`s) is copy-pasted 15+ times because no `.neuCard()` modifier
existed when the second card was written. By the 15th it's a refactor
touching every screen.

**Rule:** "extract on second use" applies to repeated UI treatments (a
styled card, an icon circle, a segmented picker) exactly as much as to
logic. (Tracked in `BACKLOG.md` → tech debt, High/Medium.)

---

## 4. Scaffold abstractions early; defer subsystems until the first call site

These pull opposite ways and the distinction is load-bearing here:

- **Abstraction, built early = right.** Shipping `SystemTheme` *and*
  `NeuTheme`/`PixelArtTheme` from day one forced every `SemanticIcon`,
  color, and typography role to have a complete answer in more than one
  place. That's *why* the theme layer is clean — the second implementation
  kept the catalog honest.
- **Subsystem, built early = wrong.** `SoundPlayer` + `SemanticSound` +
  `theme.sound()` + the PixelArt sound map were all built day one for a
  feature that's still deferred — 100+ lines of dead code carried for
  nothing (audit Session 9 watch-list).

**Litmus test:** "Does building this *now* force an existing abstraction to
be better-shaped?" → build it. "Am I building this because I think I'll
need it later?" → defer to the first real caller.

---

## 5. Don't hand-craft what a tool generates

Round 1 hand-rolled `project.pbxproj` with a custom UUID scheme; a typo'd
UUID broke the build with a useless error. Round 2 uses **xcodegen**:
`project.yml` is the source of truth, `make generate` regenerates the
pbxproj. New file → update `project.yml` → `make generate`. See
`TOOLING.md`.

---

## 6. Privacy / data-minimalism by default

Zero data collection, zero trackers, zero network calls. This made
`PRIVACY.md` honest and the App Store privacy form trivial, and it's a
published, binding commitment (see `FEATURES.md`). Any feature that would
collect or transmit data must update the policy and listing *first*.

---

## 7. Make hard rules mechanical

The Session 9 audit found ~8 small leaks against the clearly-stated
"never call `Image(systemName:)` outside `IconResolver`" rule. Good
intentions don't enforce rules — `grep` does. Every greppable hard rule
has a line in `scripts/lint-rules.sh`, run before each handoff. See
`HARD_RULES.md`.

---

## 8. Keep the dependency surface small

No SPM packages, no CocoaPods — the only runtime dependencies are Apple's
own frameworks. xcodegen is a *tooling* dependency, not a runtime one,
which is fine. Add a runtime dependency only when building it yourself
clearly costs more than the black box — and ask the user first.
