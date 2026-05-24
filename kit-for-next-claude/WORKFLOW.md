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
