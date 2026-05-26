# WORKFLOW.md — How to work with the user

The user is the product manager for Dopamine Ledger. They don't write
Swift themselves yet, but they've spent days living with round 1 of
this app and have strong opinions about its feel. They are learning by
watching you work — your comments and explanations are part of the
deliverable, not overhead.

---

## Plan before you code

For anything bigger than a typo fix:

1. State what you understand the goal to be in one paragraph.
2. List the concrete files you intend to create or change.
3. Note any product-rule ambiguity and either ask, or state the
   assumption you're making.
4. Wait for the user to acknowledge or push back.
5. Only then start writing code.

For trivial changes (rename a variable, fix a typo, add a missing
import), just do it. Use judgment on what "trivial" means — when in
doubt, plan.

---

## Explain *why* in comments

Round 1 set a precedent of generous educational comments. Continue it.
Examples of comments that earned their place:

- "Denormalized `activityId` instead of a `@Relationship` because
  predicates from `@MainActor` views were painful."
- "Capture `name` and `payoff` before toggling `isCompleted` — the
  `@Query` filter will drop the entity once the flag flips."
- "Why a thin wrapper around `UNUserNotificationCenter`: keeps SessionView
  free of UN boilerplate, namespaces identifiers, and the testable math
  lives separately in `NotificationMath`."

Examples of comments that are noise:

- `// initialize the variable`
- `// loop over the array`
- `// SwiftUI view`

Aim for the first kind. Delete the second kind.

---

## UI completion checklist — two gates before marking a step done

Every new UI element must clear both gates before the step is called complete:

**Gate 1 — Theme applied.**
No hardcoded colors, fonts, icons, or spacing values in view code. Every
value must flow from `@Environment(\.theme)`. Test by switching from
NeuTheme to SystemTheme in Settings — if anything looks wrong or
inconsistent, the gate isn't cleared. Tab bars, pickers, sheet backgrounds,
and toolbar items are common places this gets missed.

**Gate 2 — Strings localised.**
Every user-visible string must have a key in `Localizable.xcstrings` and
be accessed via `lBundle.l("key")`. Hardcoded English is acceptable only
as a temporary placeholder during the same step, and must be resolved
before the step is marked done. Test by switching the in-app language to
French or German — if any string stays in English, the gate isn't cleared.

Catching both issues at the end of a step is far cheaper than discovering
them after several steps have stacked on top.

---

## Verify visually after UI changes

Use `scripts/install-and-screenshot.sh`:

```bash
make screenshot   # builds, installs to the simulator, takes a PNG
```

Then attach the screenshot in chat. The user can see it. Don't ask the
user to launch the app themselves to verify your change.

After a backend-only change, the test suite is the verification:

```bash
make test
```

22 tests already exist for the math layer. If you add business math,
add tests in the same `DopamineLedgerTests.swift` file.

### How to read the screenshot — removal check

When reviewing a screenshot, read the **full screen top-to-bottom**, not
just the area you were working on. Apply two checks in order:

1. **New elements present?** Confirm every element you added is visible
   and looks correct.
2. **Old elements gone?** For every element the change was supposed to
   remove or hide, explicitly name it and confirm it is absent. If you
   replaced a system tab bar, verify the system tab bar is not still
   showing beneath the new one. If you removed a button, verify it is
   not still there.

The failure mode is pattern-matching forward (new thing looks good →
ship it) without checking backward. A strip at the bottom of the screen
is not always a background colour mismatch — it might be the old UI
element still present underneath the new one.

---

## One change at a time

A diff that mixes "fix the balance formatting bug + add the theme toggle
+ rename three files" is harder to review and rolls back as a unit.
Land work in narrow, reviewable chunks. Commit messages should match.

---

## Honest about uncertainty

If you don't know whether a SwiftUI `.contentTransition(.numericText())`
will animate while the view is off-screen, say so. Then look it up,
run a quick test, or note the open question. Never pretend confidence
you don't have — the user can't independently verify Swift trivia, so
your "I'm not sure" is the only signal they get.

---

## Capture lessons in real time

When you hit a non-obvious gotcha — a SwiftData predicate that won't
compile, a font modifier that silently falls back, an `xcrun` that fails
because of `xcode-select` — update the relevant file in this kit:

- Tooling/environment quirks → `TOOLING.md`
- Architectural realizations → `ARCHITECTURE.md` or `DESIGN_SYSTEM.md`
- Anything reflective ("we should have done X earlier") → `LESSONS_LEARNED.md`

The kit only stays useful if it stays current.

---

## What the user does well to help

- Will paste screenshots of bugs.
- Will say "I don't like how this feels" — treat that as legitimate
  feedback and explore until you find the underlying cause (often a
  font size, spacing, or transition).
- Will sometimes paste another LLM's review of a plan. Read it; weigh
  the arguments; agree or disagree on the merits. Don't capitulate
  just because a second opinion exists.
- Will lock product decisions before you start a big change — and means
  it. Don't re-litigate locked decisions.

## What the user appreciates

- Brief, honest "this won't work because X" over implementing the wrong
  thing.
- A sketch of two approaches with trade-offs, when there's real choice.
- Saying "I don't know — let me check" instead of guessing.
- Calling out when a request would create technical debt and proposing
  a cleaner alternative.

---

## Handing off to the user for testing

When a step is fully implemented, built, and self-verified (build green,
tests pass, screenshot reviewed), end your message with a clearly visible
handoff block so the user knows it is their turn:

```
---
✅ READY TO TEST
What to check: [one-line summary of the feature]
How: [what to tap / where to look]
Known: [anything intentionally deferred or imperfect]
---
```

Do not write this block mid-task or while still making changes.
Only write it once — the final message of the step.

---

## Closing a testing loop

Once the user confirms the feature looks good (explicit "all good", "looks
great", "approved", or equivalent — not silence), always do the following
before moving to the next task:

1. **Update the kit docs** in one pass:
   - `JOURNAL.md` — add a session entry with what shipped, decisions made,
     gotchas, and what to pick up next.
   - `FEATURES.md` — mark the feature `done` (or update its status/notes).
   - `BACKLOG.md` — add any newly discovered deferred items; remove or
     update anything that was resolved.
   - `DECISIONS.md` — if a non-obvious decision was *locked* this session,
     log it (dated, with the why) so it isn't re-litigated later.
   - `WORKFLOW.md` / `PRINCIPLES.md` — add any new process or architecture
     lesson learned this session (non-obvious things that should change how
     we work together or how the code is shaped).

2. **Ask the user** in a single message:
   > "Docs updated. Want me to commit and push to GitHub?"

   Wait for their answer before running any git commands. Do not bundle
   the commit into the doc-update message — the user may want to review
   the diff or add unstaged files first.

---

## Standing rituals (not one-offs)

These are easy to treat as "things we did once." Make them recurring:

- **Hard-rule lint before every `READY TO TEST`.** Run
  `bash kit-for-next-claude/scripts/lint-rules.sh DopamineLedger`. Cheap,
  and it catches rule erosion that prose can't (Session 9 found ~8 leaks
  against a clearly-stated rule). The job is "no NEW violations."
- **Pre-milestone audit.** At each "feature-complete" milestone — not just
  before the very first release — do a read-only debt audit: layering,
  duplication, test coverage of the *glue* (see `PRINCIPLES.md` #2), dead
  code, rule leaks. File findings in `BACKLOG.md` → tech debt. Don't fix
  during the audit; report, then decide together what's worth doing.
  (Session 9 was the first such audit.)

---

## Parallel sessions

If the user runs a second Claude session in parallel (e.g. a separate
terminal via `/btw`), treat it as a coordination hazard: work done there is
invisible to this session and can be lost or clobbered (it happened once —
mock-data work went missing). When you learn a parallel session touched the
repo, re-read the relevant files before assuming state.

---

## Context compaction

Long sessions get compacted and the summary can drop a nuance. The durable
defense is keeping the core docs (`CLAUDE.md`, `SPECIFICATION.md`,
`PRINCIPLES.md`, `TOOLING.md`) short-but-complete, so a reload from disk
restores what a compacted summary might miss.
