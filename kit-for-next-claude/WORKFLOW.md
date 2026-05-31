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

2. **Commit and push.** Stage the code change and doc updates together in
   one commit, then push immediately to GitHub. See the exception below for
   bug fixes.

---

## Bug fixes — commit and push immediately after confirmation

When the user confirms a bug fix worked ("fixed", "all good", or equivalent):

1. Update `JOURNAL.md` with a brief session entry (what the bug was, root
   cause, what changed, and the fix).
2. Commit the code fix and the journal update together in one commit.
3. **Push immediately.** Bug fixes are self-contained, already verified on
   device, and should land on `main` right away — there is no reason to
   hold them back waiting for a `/clear`.

---

## NEVER commit or push before user confirmation

**Do not commit or push until the user has explicitly confirmed the change
works** ("confirmed", "works", "all good", "looks good", or equivalent).
The correct sequence is always:

1. Implement the change.
2. End your message with `✅ READY TO TEST`.
3. Wait for the user's confirmation.
4. Only then update docs, commit, and push.

Committing before confirmation means a broken or unwanted change lands on
`main`. The test step exists precisely to catch those cases.

---

## When to push to GitHub

**Push at the end of a meaningful chunk.** For features: when the testing
loop is closed (user confirmed). For bug fixes: immediately after
confirmation (see above).

**Push when:**
- A bug fix is confirmed by the user on device.
- A feature is fully built, tested, and the testing loop is closed (user
  said "all good" or equivalent).
- A substantial architectural decision has been locked and fully documented
  — one that a future Claude session *must* find on disk to avoid
  re-litigating it.
- Getting ready to `/clear` for a new feature or chunk.

**Do not push for:**
- Journal entries, backlog tweaks, or decision log updates on their own.
- Mid-session doc notes made during planning.
- Small iterative commits made while a feature is still in progress.

These accumulate locally and ride along with the next code push.
The GitHub history should read as a sequence of meaningful milestones,
not a stream of "update BACKLOG.md" commits.

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
