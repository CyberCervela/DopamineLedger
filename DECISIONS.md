# DopamineLedger — Locked decision log

Append-only. Each entry records a decision that should not be
re-litigated, *why* it was made, and when. This gathers in one greppable
place the decisions previously scattered across `CLAUDE.md` (the "three
locked decisions"), `SPECIFICATION.md`, and `JOURNAL.md` session notes.

When a decision is reversed, don't delete the old entry — add a new one
that supersedes it and link back. The history is the point.

Format: `## D-NNN — <title>  (YYYY-MM-DD)` then **Decision / Why / Scope /
Supersedes**.

---

## D-001 — Single global credit balance, not per-activity balances   (round 1; carried into round 2 2026-05-23)
**Decision:** One credit balance shared across all activities. The `Ledger`
is effectively a singleton (one row, accessed via `Ledger.fetchOrCreate`).
**Why:** The product is a single "time budget" the user spends down and
earns back. Per-activity balances would fragment that mental model and make
the headline balance number meaningless.
**Scope:** Balance only. Debt is tracked per-activity (see D-002).
**Supersedes:** none

## D-002 — Debt is per-activity, accrued at 2× base rate, repaid manually   (round 1; carried into round 2 2026-05-23)
**Decision:** When a spender overruns the balance past zero, the overrun
time accrues debt at 2× the activity's base rate, as a per-activity
`ActivityDebt` row. Debt is never cleared automatically — the user taps
Repay. Balance never goes negative; the overflow becomes debt.
**Why:** A global debt pool hid *which* habit caused the deficit — the
per-activity attribution is the product's point. 2× is a deliberate
friction signal, not an interest model. Manual repay keeps the user in
control of the "books."
**Scope:** Spenders only. Chargers never create debt.
**Supersedes:** none

## D-003 — Round 2 is a green-field rebuild that transplants working modules   (2026-05-23)
**Decision:** Models, pure-math layer, services, tests, and submission docs
come over from round 1 verbatim (light cleanup comments only). Views,
theme, icon resolver, and toast are re-derived from scratch.
**Why:** Round 1's working modules were solid and tested; its *view layer*
was structurally bound to one hardcoded theme. Copying the views would just
import that coupling as migration debt.
**Scope:** The round-2 rebuild. See `kit-for-next-claude/README.md`.
**Supersedes:** none

## D-004 — Theming is a protocol with multiple implementations, injected via @Environment   (2026-05-23)
**Decision:** `Theme` is a protocol. `SystemTheme` and a primary
neumorphic/pixel theme ship together; every view consumes theme via
`@Environment(\.theme)` and never hardcodes a value.
**Why:** Round 1's single-struct theme meant switching looks required
editing every view. A second implementation from day one forces every
semantic role to be complete and stable. (See `PRINCIPLES.md` #4.)
**Scope:** All view code. Enforced by HARD_RULES #5–6.
**Supersedes:** none

## D-005 — Build with xcodegen; never hand-edit project.pbxproj   (2026-05-23)
**Decision:** `project.yml` is the source of truth; `make generate`
regenerates the Xcode project.
**Why:** Round 1 hand-rolled the pbxproj with a UUID convention; a single
typo broke the build with an inscrutable error.
**Scope:** All project-structure changes. See `TOOLING.md`.
**Supersedes:** none

## D-006 — Public repo; code and docs readable by an outside contributor   (2026-05-23)
**Decision:** The repo is public at github.com/CyberCervela/DopamineLedger.
Comments and docs are written for an outside reader.
**Why:** The user is learning in the open and wants the project legible.
**Scope:** All commits. Reinforces HARD_RULES #1 (no secrets).
**Supersedes:** none

## D-007 — In-app language switching via a custom `languageBundle` environment key   (2026-05-25)
**Decision:** Language is chosen in-app (overriding the device language)
by injecting a resolved `.lproj` `Bundle` through a custom environment key;
views read it via `lBundle.l("key")`.
**Why:** SwiftUI's `Text(LocalizedStringKey)` ignores
`.environment(\.locale)` for bundle selection — it always reads
`Bundle.main`. The custom key + `NSLocalizedString(_:bundle:)` is the only
reliable way to switch language without an app restart.
**Scope:** All user-facing strings. CJK languages are in the catalog but
hidden from the picker pending native-speaker review.
**Supersedes:** none

## D-008 — No `TabView`; a custom `ZStack` + `NeuTabBar`   (2026-05-25)
**Decision:** Two-tab navigation (Home / Stats) is a plain `ZStack` with
both views always in the hierarchy, switched by opacity, plus a custom
`NeuTabBar` injected via `.safeAreaInset`.
**Why:** `TabView` creates a `UITabBarController` whose system bar can't be
hidden reliably (`.toolbar(.hidden)` is flaky, `UITabBar.appearance()`
fires too late and bleeds globally). Owning the bar is simpler. Keeping
both views live preserves `@Query` state across tab switches.
**Scope:** Root navigation only.
**Supersedes:** none

## D-009 — NeuTheme is the shipping default; PixelArt deferred from the MVP   (2026-05-25)
**Decision:** The light neumorphic theme is the default and primary
experience. PixelArt is implemented as a protocol citizen but filtered out
of the Settings picker and excluded from the MVP submission.
**Why:** PixelArt needs generated assets and font polish that aren't ready;
the neumorphic look is shippable now. The protocol still carries PixelArt so
the abstraction stays honest (D-004).
**Scope:** MVP. The dormant PixelArt/sound scaffolding stays in the tree
(see `PRINCIPLES.md` #4 / BACKLOG watch-list) — delete only if PixelArt is
formally cancelled.
**Supersedes:** none

## D-010 — Completed quests are soft-deleted (isCompleted + completedAt)   (2026-05-26)
**Decision:** Completing a quest sets `isCompleted = true` and stamps
`completedAt`; the active list filters completed quests out. Rows are kept,
not deleted.
**Why:** The dashboard's quest-history section needs completed quests to
still exist, and the store cost is negligible at realistic volumes. This
resolves the "soft vs hard delete" question that `LESSONS_LEARNED.md` left
open in round 1 — the history view became a committed feature in Session 7.
**Scope:** Quests. The flag is the source of truth for "is this active."
**Supersedes:** none (resolves a previously-open question)

## D-011 — ActivityDebt freezes originalAmount + stamps repaidAt for stats history   (2026-05-26)
**Decision:** `ActivityDebt` carries `originalAmount` (frozen at creation,
default 0 for migration safety) and `repaidAt` (stamped when the row
reaches zero), so repayment events survive after `amount` hits 0.
**Why:** `DashboardStats` needs to attribute repaid debt to a time scope;
mutating `amount` in place destroyed that history. Default `= 0` keeps
SwiftData lightweight migration safe for pre-existing rows.
**Scope:** Stats/dashboard. Partial repayments are attributed to the
session that zeroes the row (MVP-acceptable).
**Supersedes:** none

## D-012 — Three-tab navigation: Home / Stats / History   (2026-05-27)
**Decision:** The app has three permanent tabs: Home (`house`), Stats
(`chart.bar`), History (`clock`). Each tab has a single, non-overlapping
purpose. The `QuestHistorySection` that previously lived inside the Stats
tab migrates to History as part of the History screen build.
**Why:** Stats and History answer different questions. Stats = "how am I
doing?" (aggregates, scope picker, future streaks and graphs). History =
"what happened?" (reverse-chronological log of sessions and completed
quests, unified timeline). Mixing them in one tab made Stats cluttered and
made the log hard to find. Three tabs is the right ceiling for this app —
a fourth would need a strong reason.
**Scope:** Root navigation (`ContentView`, `NeuTabBar`). Stats tab loses
`QuestHistorySection`; History tab gains a unified timeline view
(`HistoryView`). No changes to models or math layer.
**Supersedes:** D-008 (extends it — D-008 established the ZStack/NeuTabBar
pattern; D-012 adds the third tab within that same pattern).
