# Kit for next Claude — Dopamine Ledger, round 2

This folder is a self-contained handoff package. It is everything a fresh
Claude Code session needs to rebuild **Dopamine Ledger** from scratch in a
new repo, while keeping the parts of round 1 that already worked.

> **Public-repo note.** Dopamine Ledger is a personal time-budget iOS app:
> a single credit balance where "charger" activities earn credits over time
> and "spender" activities spend them. Overrunning a spender past zero
> accrues activity-specific debt at 2× rate, which the user repays manually.
> This kit exists because the first attempt shipped, but accumulated a few
> structural choices that are cheaper to fix on a green-field rebuild than
> in place.

**Start here.** Read this file top to bottom, then open `CLAUDE.md` and read
it end-to-end before writing any code.

---

## Quick start

1. Read this `README.md` (you're here).
2. Read `CLAUDE.md` — the master operating instructions for this rebuild.
3. Skim `SPECIFICATION.md` to load the product model.
4. Read `ARCHITECTURE.md` and `DESIGN_SYSTEM.md` before writing any view code.
5. Read `WORKFLOW.md` and `TOOLING.md` before running any shell command.
6. When ready to scaffold the project:
   - Create the new Xcode project via **xcodegen** using `scaffolds/project.yml`
     (do not handcraft `project.pbxproj` — round 1 did that and regretted it).
   - Drop the files in `scaffolds/Models/`, `scaffolds/Services/`, and
     `scaffolds/Tests/` into the new project unchanged. They are transplanted
     from round 1 and already have unit-test coverage.
   - Implement `scaffolds/Theme.swift`, `scaffolds/IconResolver.swift`, and
     `scaffolds/SoundPlayer.swift` as the real theming layer. Round 1's
     versions are intentionally **not** transplanted — see `LESSONS_LEARNED.md`
     for why.
   - Use `scaffolds/Info.plist` as-is; it already has the keys round 1 had to
     discover the hard way (`UIAppFonts`, `ITSAppUsesNonExemptEncryption`,
     `UIUserInterfaceStyle=Dark`, portrait-only).
7. Use `scripts/Makefile` for every build / test / install / screenshot
   verb. Do not invent ad-hoc `xcodebuild` invocations.

---

## What's in here

### Top-level docs (fresh, written for round 2)

| File                | Purpose |
|---------------------|---------|
| `README.md`         | This file. Kit index + start-here. |
| `CLAUDE.md`         | Master operating instructions for the next Claude. |
| `SPECIFICATION.md`  | Product spec — economy, debt, sessions, quests. |
| `ARCHITECTURE.md`   | Code structure + theme protocol design. |
| `DESIGN_SYSTEM.md`  | Theming strategy: semantic roles vs concrete values. |
| `WORKFLOW.md`       | How to collaborate with the user (plan first, screenshot-verify). |
| `TOOLING.md`        | macOS / Xcode / simulator gotchas the next Claude will hit. |
| `LESSONS_LEARNED.md`| Honest retrospective from round 1. |

### Top-level docs (transplanted from round 1)

| File                  | Purpose |
|-----------------------|---------|
| `BACKLOG.md`          | Post-MVP ideas, ranked. |
| `PRIVACY.md`          | Privacy policy (used for App Store). |
| `APP_STORE_LISTING.md`| Drafted listing copy. |
| `SUBMISSION.md`       | App Store submission process notes. |

### Code scaffolds

```
scaffolds/
├── project.yml                       xcodegen manifest (fresh)
├── Info.plist                        pre-populated plist (fresh)
├── Theme.swift                       protocol + 2 implementations (fresh)
├── IconResolver.swift                theme-bound semantic icon lookup (fresh)
├── SoundPlayer.swift                 stub with TODOs (fresh)
├── Models/
│   ├── Activity.swift                @Model — transplanted
│   ├── Session.swift                 @Model — transplanted
│   ├── ActivityDebt.swift            @Model — transplanted
│   ├── Ledger.swift                  @Model — transplanted
│   ├── Quest.swift                   @Model — transplanted
│   ├── SessionMath.swift             pure math — transplanted (6 tests)
│   ├── RepayMath.swift               pure math — transplanted (6 tests)
│   └── NotificationMath.swift        pure math — transplanted (5 tests)
├── Services/
│   ├── SessionFinalizer.swift        end-of-session flow — transplanted
│   └── NotificationScheduler.swift   UN wrapper — transplanted
└── Tests/
    └── DopamineLedgerTests.swift     22 unit tests — transplanted
```

### Scripts

```
scripts/
├── Makefile                          build / test / install / screenshot
├── generate-pixel-icons.py           PixelLab.ai wrapper (--dry-run / --execute)
└── install-and-screenshot.sh         one-shot visual-verify helper
```

### Manifest

`kit-manifest.json` — machine-readable listing of every file in this kit,
which ones are transplanted vs. fresh, and a list of acceptance checks the
next Claude can run to confirm the kit landed cleanly.

---

## What this kit deliberately does NOT include

- **No views.** Round 1's SwiftUI views are not transplanted. The new
  rendering passes through `Theme` + `IconResolver` from day one, which
  changes every view's shape — copying old views would just create migration
  debt. Re-derive views from `SPECIFICATION.md`.
- **No `Theme.swift` from round 1.** Round 1's theme was a single struct of
  static values. Round 2 needs a protocol so PixelArt and System themes can
  coexist — see `DESIGN_SYSTEM.md`.
- **No `IconResolver.swift` from round 1.** Round 1's resolver mapped a
  string key to an SF Symbol. Round 2's resolver belongs to the active
  theme, so PixelArt can return a pixel asset and System can return an SF
  Symbol for the same semantic key.
- **No `Toast.swift` from round 1.** Same reason — it's view-layer and needs
  to be re-derived against the new theming model.
- **No handcrafted `project.pbxproj`.** Use xcodegen.

---

## Provenance

Round 1 lives in a local working tree on the maintainer's machine; this
kit was transplanted from there. Round 2 lives at the public GitHub repo
https://github.com/CyberCervela/DopamineLedger. If you have access to
the round 1 tree you can read it for reference, but treat anything not
in this kit as **inspiration, not source of truth**.

The user is the product manager. They don't write Swift themselves but
have lived with the app long enough to have strong opinions about its
behavior. Treat their feedback like a designer's: specific, grounded, and
final on product questions; up for collaboration on implementation.
