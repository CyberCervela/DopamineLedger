# LESSONS_LEARNED.md — Honest retrospective from round 1

Written after submitting round 1 to the App Store and before starting
round 2. The user and Claude collaborated for several days on round
1; this is what we'd do differently with the benefit of hindsight.

---

## What worked, and is being kept

1. **Pure-function math modules.** `SessionMath`, `RepayMath`, and
   `NotificationMath` were extracted early. Every rule change was
   localized and unit-testable. We had 22 tests passing with zero
   `ModelContainer` setup. Keep this pattern.

2. **Shared service helpers.** `SessionFinalizer` and
   `NotificationScheduler` emerged from the second call site (Stop button
   vs. Settings reset; spender session start vs. spender resume). They
   prevented two flows from drifting. Keep extracting on second use.

3. **Locked product rules early.** Debt at 2×, per-activity not global,
   manual repay, hard blocks. The user committed to these and we never
   re-argued them mid-feature. This is the model for round 2.

4. **Generous educational comments.** The user is learning from the
   codebase. Comments explaining *why* paid off — the user could read a
   file weeks later and follow the reasoning. Keep this.

5. **Privacy by default.** Zero data collection, zero trackers, zero
   network calls. Made `PRIVACY.md` honest and the App Store form trivial.

---

## What hurt, and is being changed in round 2

### 1. One-theme assumption baked into views

The biggest one. Round 1's `Theme.swift` was a struct of static values,
and views called `Image(systemName:)` directly. When the user wanted to
switch from system look to pixel art, we had to edit every view file.
Even after introducing `IconResolver`, fonts and colors were still
view-coupled.

**Round 2 fix:** `Theme` is a protocol with at least two implementations
(`SystemTheme`, `PixelArtTheme`) shipping from day one, injected via
`@Environment(\.theme)`. See `DESIGN_SYSTEM.md`. The catalogs (`ThemeColors`,
`ThemeTypography`, `SemanticIcon`, `SemanticSound`) are stable from the
start because the second implementation forces every role to have two
answers.

### 2. Handcrafted `project.pbxproj`

We wrote our own UUID convention (`XX0001000000000000000000`) and edited
four sections of the pbxproj for every new file. It was creative but
fragile — a typo'd UUID broke the build with a useless error.

**Round 2 fix:** **xcodegen**. `project.yml` is the source of truth;
`make generate` regenerates the pbxproj. New file → add to filesystem,
run `make generate`, done.

### 3. Custom-font silent fallback (Monogram + AbaddonBold)

`.weight(.semibold)` on Monogram and `.monospacedDigit()` on AbaddonBold
silently fell back to the system font. We didn't notice for a while
because the *text* still rendered — just in San Francisco instead of
pixel. The fix was building each font value once with all modifiers
applied and never letting view code touch them.

**Round 2 fix:** documented in `DESIGN_SYSTEM.md` as a hard rule.
`ThemeTypography` exposes pre-built `Font` values; views consume them
unmodified.

### 4. `UISegmentedControl` and `UINavigationBar` ignored SwiftUI styling

Round 1 lost an hour realizing the segmented picker can't be styled
through SwiftUI alone. The fix is `UISegmentedControl.appearance()` set
once at launch with a `UIFont`. Same with nav-bar titles —
`ToolbarItem(.principal)` with a custom `Text` is the way.

**Round 2 fix:** documented in `TOOLING.md`. The theme will own the
UIAppearance overrides as part of its activation.

### 5. `UIAppFonts` doesn't flow from build settings

We set `INFOPLIST_KEY_UIAppFonts` as a build setting (which works for
other plist keys) and the fonts never loaded. The fix was a custom
partial `Info.plist` referenced via `INFOPLIST_FILE`.

**Round 2 fix:** `scaffolds/Info.plist` ships pre-populated with the
required keys. `project.yml` wires `INFOPLIST_FILE` directly.

### 6. `xcrun simctl 'unable to find utility'`

`xcode-select` was pointed at Command Line Tools, not Xcode. Every
`xcrun` failed until we figured out the `DEVELOPER_DIR` prefix.

**Round 2 fix:** `Makefile` and helper scripts all export `DEVELOPER_DIR`
internally. Documented in `TOOLING.md`.

### 7. PixelLab API enum trial-and-error

`outline=thick` and `shading=flat` returned 400s; the API wants exact
enum strings like `"single color black outline"` and `"basic shading"`.
We discovered this by repeated failure.

**Round 2 fix:** `scripts/generate-pixel-icons.py` has a constants block
with the known accepted enum values. New roles slot in by name.

### 8. `Bitforge` style-strength=50 destroyed the subject

When generating the app icon, using Bitforge with a style reference at
strength 50 produced something that no longer looked like a ledger.
Pixflux (text-to-image, no style ref) produced a clean result.

**Round 2 fix:** documented in `TOOLING.md` — use Pixflux for anchors,
Bitforge for batch consistency once an anchor exists.

### 9. Tiny Swords "Big buttons" were reference grids, not 1× buttons

We thought a 3×3 atlas was a 9-slice slice ready to go; it was actually
nine reference *renderings* of the same button at different sizes.
Wasted some hours.

**Round 2 fix:** generate single continuous PNG buttons via PixelLab
directly, then 9-slice in the Asset Catalog. Documented in `TOOLING.md`.

### 10. Deferred Live Activities indefinitely

We pushed Widget Extension / Live Activities to the end and then ran
out of MVP energy. A "session running" lock-screen indicator is
arguably the highest-value missing feature.

**Round 2 fix:** `BACKLOG.md` calls it out as the biggest remaining tech
lift. Round 2's plan-paragraph in `CLAUDE.md` puts it as step 8 — not
day one, but explicit, not "later."

---

## Process lessons (about how the user and Claude work together)

1. **Plan-first sometimes slipped.** For UI tweaks we drifted into
   "just try it" mode and occasionally landed something the user didn't
   want. Re-committing to the plan-first habit in `WORKFLOW.md`.

2. **Visual verification was the right loop.** Once we set up
   "install + screenshot, paste it in chat," feedback got 5× faster.
   Round 2 makes this a Makefile target on day one.

3. **The user pasted other LLMs' reviews of plans.** Sometimes valuable,
   sometimes not. The right response is to read the review on its
   merits and engage point-by-point — not to defer reflexively, not to
   dismiss it. Round 2's `WORKFLOW.md` calls this out.

4. **Long sessions lost context to compaction.** A few times the
   conversation hit a limit and the post-compaction summary missed a
   nuance. Keeping `CLAUDE.md`, `SPECIFICATION.md`, and `TOOLING.md`
   short-but-complete is the durable answer.

5. **Educational comments are not overhead.** The user explicitly said
   they read them and learn from them. Round 2 should keep the bar.

---

### 11. ActivityKit `Activity` conflicts with the app's `Activity` SwiftData model

When adding the Live Activity service, calling `Activity<SessionActivityAttributes>.request(...)` fails to compile because Swift resolves `Activity` to the local SwiftData model class, not `ActivityKit.Activity`.

**Fix:** fully qualify as `ActivityKit.Activity<SessionActivityAttributes>` wherever both types are in scope. Also, `.after(...)` on the dismissal policy needs a fully qualified `ActivityUIDismissalPolicy.after(...)` for the same reason (a `Date` extension method named `after` might otherwise be inferred). Document this in `LiveActivityService.swift` with a comment if it trips you again.

---

## Things that are genuinely open

- **Soft-delete vs hard-delete for completed quests.** We picked soft
  (`isCompleted = true`) to enable a future history view. If round 2
  ships a history view, this pays off. If not, it's clutter in the
  store. Revisit when that view is on the table.

- **Whether `BalanceCard` should live-update via timer while a session is
  open.** Round 1 didn't, and gave `SessionView` its own footer.
  `BalanceCard`'s static-on-return behavior is a workaround for the
  `@Query`-off-screen-no-animate issue. There might be a cleaner answer
  with `TimelineView` + computed elapsed.

- **Whether to support landscape on iPad.** Round 1 locked portrait
  iPhone-only. Round 2 inherits that until asked otherwise.
