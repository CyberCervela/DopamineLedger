# CLAUDE.md — Dopamine Ledger, round 2

Start here. Open `kit-for-next-claude/README.md` and follow the Quick start
section. Then read `CLAUDE.md` end-to-end before writing any code.

This file is the master operating contract for the next Claude session
rebuilding Dopamine Ledger. The user is the product manager. They are
learning to code by watching you work — explanations matter, but so does
not drowning them in walls of text.

---

## What you are building

A native iOS app. Single-screen-friendly time-budget tracker. The user
defines activities; chargers earn credits over time, spenders consume
them, and quests pay a one-tap bounty for a completed task. Overrun on a
spender accrues per-activity debt at 2× rate. The user repays debt
manually. Locked product rules are in `SPECIFICATION.md` — read it before
proposing any product changes.

Round 1 of this app stopped right before shipping to App Store submission. Round 2 is
a green-field rebuild that keeps the parts that worked (math, models,
services, tests, submission docs) and fixes the structural choices that
hurt — primarily the view-layer coupling to a single hard-coded theme.

---

## The three locked decisions for round 2

These were decided before the rebuild started. **Do not re-litigate.**

1. **Transplant working modules.** Models, math, services, tests, and
   submission docs come over from round 1 verbatim (with light cleanup
   comments). Views, theme, icon resolver, and toast are re-derived.
2. **Two themes from day 1.** `Theme` is a protocol. `PixelArtTheme` and
   `SystemTheme` are both implemented and selectable. Every view consumes
   the theme via `@Environment` — no view ever hard-codes a color, font,
   icon, or sound.
3. **Public repo.** Repo lives at <https://github.com/CyberCervela/DopamineLedger>.
   Comments and docs should be readable by an outside contributor.

---

## How to work with the user

- **Plan first.** For anything non-trivial, propose the approach in plain
  English before writing code. The user will sign off, push back, or ask
  questions. Only then write code.
- **Explain *why*, not just *what*.** When you make a structural choice
  ("I extracted this into a Math file so we can unit-test it"), say so.
- **One change at a time.** Big diffs that mix unrelated changes are hard
  to review and harder to learn from.
- **Verify visually.** After UI changes, install on the simulator and
  screenshot — `scripts/install-and-screenshot.sh` is set up for this.
  The user can see the screenshot in chat; don't ask them to run the app
  themselves to verify.
- **Honest about uncertainty.** If you don't know whether a SwiftUI
  modifier will animate off-screen, say so and look it up.
- **Capture lessons.** When you hit a non-obvious gotcha (predicate
  capture, font-weight silent fallback, etc.), update `TOOLING.md` or
  `LESSONS_LEARNED.md` so the next-next Claude doesn't repeat it.

---

## Implementation order

A suggested ramp that lets the user see something on screen quickly and
catches structural issues before they compound. Re-order only with reason.

1. **xcodegen scaffold.** Run `make generate` (alias for `xcodegen generate`)
   using `scaffolds/project.yml`. Confirm `open DopamineLedger.xcodeproj`
   works and the empty app builds.
2. **Theme protocol + both implementations.** Drop in `scaffolds/Theme.swift`.
   Wire `SystemTheme` as the default via `@Environment(\.theme)`. Add a
   debug toggle in `SettingsView` to flip themes. Verify both render an
   empty `Text("hello")` correctly in each theme.
3. **Transplant models + math + tests.** Run the test target — all 22
   should pass before you write a single view.
4. **`Ledger` + `BalanceCard`.** First view that touches data. Single
   number on screen. Uses theme tokens for everything.
5. **Activity CRUD + Session start/stop.** Now the app does something.
   Hook up `SessionFinalizer` and `NotificationScheduler` from the
   transplanted services.
6. **Debt + repay + quests + settings.** Round out the MVP.
7. **Polish, custom fonts (`Info.plist` already has the keys), pixel-art
   icons via `scripts/generate-pixel-icons.py --execute`.**
8. **Live Activities / Widget Extension.** Deferred from round 1; biggest
   remaining tech lift.

---

## Hard rules

- **Never put a hex color, font name, icon name, or sound asset name in a
  view file.** Always go through the theme.
- **Never call `Image(systemName:)` outside `IconResolver`.** That was the
  round-1 rule and it still applies — just more strictly because `Image`
  is now theme-dependent.
- **Never write a SwiftData `#Predicate` that closes over `someModel.id`.**
  Extract the id to a local first. See `TOOLING.md`.
- **Never edit `project.pbxproj` by hand.** Always regenerate via xcodegen
  by editing `project.yml`.
- **Never commit secrets.** The PixelLab API key lives in
  `~/.dopamine-ledger.env` (chmod 600). Scripts source it; nothing else.
  If the user pastes a key in chat, do not echo it back and do not put it
  on a command line where shell history would capture it.
- **Never add a dependency without asking.** Round 1 deliberately has no
  SPM packages and no CocoaPods. Round 2 should keep the surface small
  while the user is still learning the codebase. xcodegen is a tooling
  dependency, not a runtime one — that's fine.

---

## Where to find what

| You need...                          | Read...                              |
|--------------------------------------|--------------------------------------|
| The product rules                    | `SPECIFICATION.md`                   |
| How the code is laid out             | `ARCHITECTURE.md`                    |
| How theming works                    | `DESIGN_SYSTEM.md` + `Theme.swift`   |
| How to collaborate with the user     | `WORKFLOW.md`                        |
| Why `xcrun` won't run                | `TOOLING.md`                         |
| Why round 1 wanted a rewrite         | `LESSONS_LEARNED.md`                 |
| Post-MVP ideas                       | `BACKLOG.md`                         |
| App Store text and process           | `APP_STORE_LISTING.md`, `SUBMISSION.md`, `PRIVACY.md` |

If a question isn't answered in this kit, ask the user — they have the
context. Don't invent product rules.
