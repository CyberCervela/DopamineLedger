# HARD_RULES.md — The "never do X" list for Dopamine Ledger

Rules that don't bend. These were previously embedded in `CLAUDE.md`;
this file gathers them in one place and maps each to a check in
`scripts/lint-rules.sh` where it can be expressed as a grep. The point is
that rules are **enforced**, not just remembered — the Session 9 audit
found ~8 leaks against a clearly-stated rule.

Run before every `READY TO TEST`:

```bash
bash kit-for-next-claude/scripts/lint-rules.sh DopamineLedger
```

> **Note on known leaks.** The lint currently reports a handful of
> pre-existing violations (hardcoded `Image(systemName:)` in `SettingsView`,
> `BalanceCard`, `PrivacyPolicyView`; `systemImage:` in `ActivityListView`
> context menus; the hero timer font in `SessionView`). These are tracked
> in `BACKLOG.md` → tech debt (Low, tied to PixelArt) and are *not*
> ship-blockers. The rule applies going forward: **do not add new
> violations.** Clean the existing ones when PixelArt work resumes.

---

## Universal

### 1. Never commit secrets
- The PixelLab API key lives in `~/.dopamine-ledger.env` (chmod 600) as
  `PIXELLAB_API_KEY=...`. Scripts `source` it; nothing else references it.
- If the user pastes a key in chat: don't echo it back, don't put it on a
  command line (shell history captures it).
- **`.gitignore` does NOT protect a key hardcoded in committed source** —
  it filters by filename, not content. See the Session 5 incident in
  `TOOLING.md` (a Google key in a `.py` literal was committed and caught by
  GitHub secret scanning; the only fix was rotate + scrub history).
- *Checkable:* lint greps for key-shaped literals.

### 2. Never hand-edit `project.pbxproj`
Always regenerate via xcodegen by editing `project.yml` and running
`make generate`. A hand-edited pbxproj is fragile and its errors are
inscrutable. See `TOOLING.md`.

### 3. Never add a dependency without asking
Round 1 and 2 deliberately have no SPM/CocoaPods packages. Keep the
surface small while the user is learning the codebase. xcodegen is tooling,
not runtime — that's fine.

### 4. Never skip verification to save time
No `--no-verify`, no disabling a failing test/check to make it pass, no
claiming a UI change works without running it on the simulator. Fix the
cause.

---

## Project-specific (theme law & SwiftData)

### 5. Never put a color / font / icon / sound *value* in a view
Always go through `@Environment(\.theme)`. A view asks for a *role*
(`theme.colors.accent`, `theme.typography.display`, `theme.icon(.charger)`)
— never a literal hex, font name, SF Symbol string, or asset path. If a
view would need a `switch` on theme, the role catalog is missing a role:
extend the protocol, don't branch in the view. See `DESIGN_SYSTEM.md`.
- *Checkable:* lint greps `Views/` for `Color(red:` / `Color(hex:` and for
  raw `.system(size:` text fonts.

### 6. Never call `Image(systemName:)` outside `IconResolver`
`Image` is theme-dependent now. The resolver (and the two theme
implementations that delegate to it) are the only places a system symbol
name may appear. The same applies to `Label(..., systemImage:)`.
- *Checkable:* lint greps for both, excluding `IconResolver.swift`,
  `Theme.swift`, `NeuTheme.swift`.

### 7. Never write a `#Predicate` that closes over `someModel.id`
SwiftData fails to compile a predicate that references nested model
property access. Extract the id to a local first:
```swift
let activityId = activity.id           // ✅
#Predicate<ActivityDebt> { $0.activityId == activityId }
```
Behavioral (not greppable) — but it WILL bite. See `TOOLING.md`.

### 8. Never apply `.weight()` / `.monospacedDigit()` to a theme font
On custom fonts (Monogram, AbaddonBold) these modifiers silently fall back
to the system font — text still renders, just in the wrong typeface, with
no error. Build each `Font` once in `ThemeTypography` with all modifiers
applied; views consume them unmodified. See `DESIGN_SYSTEM.md` /
`LESSONS_LEARNED.md`.

---

### 9. Export field sync — update DataExporter.swift in the same commit as any @Model field addition

If you add a field to `Activity`, `Session`, `Quest`, `ActivityDebt`, or `Ledger`,
update the corresponding Export struct (`ActivityExport`, `SessionExport`, etc.) AND
the `init(_ model:)` extension at the bottom of `DataExporter.swift` in the **same
commit**. The `testExportImportRoundTrip` unit test enforces this at build time — a
missing field will import as its zero/nil/false default and an assertion will fail.

Not greppable (field additions by definition don't exist until you add them). The
test is the enforcement.

---

## How to add a rule

1. Write it here with a one-line rationale (ideally citing the incident
   that motivated it).
2. If it can be a grep, add it to `scripts/lint-rules.sh`.
3. If it's behavioral (a footgun, not a literal), document it here AND in
   `TOOLING.md` so the next session doesn't rediscover it the hard way.
