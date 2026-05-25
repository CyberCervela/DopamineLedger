# TOOLING.md — Environment quirks, iOS gotchas, and shell recipes

Things that will burn time if you don't know them. Inherited mostly from
round 1; updated as round 2 finds more.

---

## macOS / Xcode environment

### `xcode-select` points to CLT, not Xcode

On this machine, `xcode-select -p` returns
`/Library/Developer/CommandLineTools`. Running `xcodebuild` or
`xcrun simctl` directly fails with:

> tool 'xcodebuild' requires Xcode, but active developer directory
> '/Library/Developer/CommandLineTools' is a command line tools instance.

**Fix for interactive use** (needs the user's sudo password):
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

**Fix for non-interactive use** (Claude from the CLI — preferred):
prefix every command with `DEVELOPER_DIR`:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild ...
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl ...
```

The `Makefile` and `install-and-screenshot.sh` already do this. Use them
instead of reinventing the wheel.

### Simulator name

Round 1 standardized on `iPhone 17 Pro Max` as the simulator destination.
Use the same so screenshots are visually comparable across the project's
history. Listed in `project.yml` and the Makefile.

### Build incantations

Prefer:
```bash
make build       # builds for the standard simulator destination
make test        # runs the unit test target
make install     # boots simulator, builds, installs the .app
make screenshot  # install + take a PNG of the home screen
```

If you must call `xcodebuild` directly:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild \
    -project DopamineLedger.xcodeproj \
    -scheme DopamineLedger \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
    build
```

---

## xcodegen

Round 1 hand-rolled `project.pbxproj` with a UUID convention. It worked
but every new Swift file needed four manual edits across the pbxproj.
Round 2 uses **xcodegen**:

```bash
brew install xcodegen          # one-time
make generate                  # regenerate project.pbxproj from project.yml
```

Always re-run `make generate` after adding, removing, or moving a Swift
file. Commit both `project.yml` and the regenerated `project.pbxproj`.

Editing `project.pbxproj` by hand in round 2 is a smell; if you find
yourself doing it, the `project.yml` is probably missing something.

---

## Info.plist keys round 1 wished it had set sooner

`scaffolds/Info.plist` is pre-populated, but for the record, the keys
that mattered:

| Key                              | Value          | Why                                  |
|----------------------------------|----------------|--------------------------------------|
| `UIAppFonts`                     | `[Monogram.ttf, AbaddonBold.ttf]` | Custom fonts must be registered or `Font(name:size:)` silently falls back to system. |
| `ITSAppUsesNonExemptEncryption`  | `false`        | App Store demands a value; `false` skips the export-compliance form. |
| `UIUserInterfaceStyle`           | `Dark`         | Locks the app to dark mode (the design assumes a dark navy palette). |
| `UISupportedInterfaceOrientations` | `[Portrait]` only | The app is single-handed portrait; locking avoids landscape regressions. |

`INFOPLIST_KEY_UIAppFonts` as a build setting does **not** flow into the
generated Info.plist correctly. Use a custom `Info.plist` referenced via
`INFOPLIST_FILE` (already wired in `project.yml`).

---

## SwiftData

### `#Predicate` cannot capture nested property access

This fails with a cryptic `PredicateExpressions.Equal` error:
```swift
let descriptor = FetchDescriptor<ActivityDebt>(
    predicate: #Predicate { $0.activityId == activity.id }  // ❌
)
```

Fix — extract to a local first:
```swift
let activityId = activity.id
let descriptor = FetchDescriptor<ActivityDebt>(
    predicate: #Predicate { $0.activityId == activityId }   // ✅
)
```

Apply this pattern **everywhere** a predicate references a model property.

### Capture model values before mutation

A SwiftData `@Model` property may become stale or nil-out after the
entity is filtered or deleted (e.g. a `@Query` predicate filters it out).
Capture anything you'll need *after* the mutation:

```swift
let name   = quest.name
let payoff = quest.payoffCredits
withAnimation { quest.isCompleted = true }   // entity now filtered out
presentToast(.questCompleted(name: name, payoff: payoff))
```

### Singleton `Ledger`

`Ledger.fetchOrCreate(in:)` is `@MainActor` and handles the
zero-then-one initialization. Always use it; never `try? context.fetch(...)`
on `Ledger` directly.

### `@Query` doesn't animate off-screen

`.contentTransition(.numericText())` and `.animation(value:)` only animate
on visible views. If the balance changes while the user is on
`SessionView`, the `BalanceCard` on `ActivityListView` will display the
new value *statically* when they navigate back — the animation ran
off-screen and was already gone. Round 1's workaround: give `SessionView`
its own balance footer with its own rolling-digit animation so the
change happens where the user is actually looking.

---

## SwiftUI specific gotchas

### Custom font silent fallback

Modifiers like `.weight(.semibold)`, `.monospacedDigit()`, or
`.italic()` on a registered custom font like Monogram or AbaddonBold
**silently** fall back to the system font. Fix: build the `Font` in
`ThemeTypography` once, with all the modifiers already applied to the
correct base, and never re-modify in view code.

### `Picker(... .segmented)` ignores SwiftUI `.font(...)`

To style the segmented control text:
```swift
UISegmentedControl.appearance().setTitleTextAttributes(
    [.font: yourUIFont], for: .normal
)
```
Do this once at app launch, gated on the active theme.

### `.navigationTitle(...)` ignores custom fonts

Use a `ToolbarItem(.principal)` with a `Text` styled by `theme.typography`
instead of `.navigationTitle(...)` when you need pixel-art type in the
nav bar.

### `UINavigationBar.appearance()` is global

When you flip themes at runtime, you must re-apply
`UINavigationBar.appearance()` settings. Don't be surprised if the bar
keeps the old theme's colors until the next app launch — that's a known
limitation of `UIAppearance`. Either accept "theme changes apply at next
launch" or rebuild the relevant appearance proxies on theme change.

---

## Notifications

- Permission is asked **just-in-time** — at session-start, not app launch.
- Identifiers are namespaced: `session.warning.<sessionUUID>` and
  `session.alarm.<sessionUUID>`. Cancel-by-session is `cancelSession(sessionId:)`
  on `NotificationScheduler`.
- The math (when to fire, whether to fire) is in `NotificationMath`, not
  the scheduler. Edit there to change rules.

---

## PixelLab.ai pixel-art pipeline

The user has a paid PixelLab.ai account; the API key lives in
`~/.dopamine-ledger.env` (chmod 600) as `PIXELLAB_API_KEY=...`. Never
echo it; never pass it on a command line argument.

`scripts/generate-pixel-icons.py` is the only intended entry point.
Always run with `--dry-run` first to confirm the queue (filenames,
prompts, output dir, estimated cost). Only after the user approves, run
with `--execute`.

Two endpoints exist:

- **Pixflux** — text-to-image. Use for **anchor** assets (the first
  rendering of a new role with no reference). The app icon was generated
  this way.
- **Bitforge** — style-conditioned. Use for **batch consistency** once an
  anchor exists. `style_image` must be exactly the same dimensions as
  the requested output; if the anchor is 64×64 and you want 128×128 out,
  upscale the anchor with PIL nearest-neighbor first.

Enum-valued parameters take specific strings, not common adjectives:
- `outline`: `"single color black outline"`, etc. — not `"thick"`.
- `shading`: `"basic shading"`, `"detailed shading"`, etc. — not `"flat"`.

If the API returns a 400 with an enum error, look up the exact accepted
values in PixelLab's docs.

---

## Asset Catalog 9-slicing

For pixel-art buttons/panels, use a single continuous PNG (not a 3×3
atlas — PixelLab can generate single-PNG buttons directly). Slice in
Xcode's Asset Catalog inspector:

1. Select the image set, open the right-hand attributes inspector.
2. Slicing → Horizontal and Vertical.
3. Set the cap insets (left, right, top, bottom) to the unstretchable
   pixel widths.

The center stretches, the corners don't. If a button looks "blurry in
the middle," cap insets are wrong.

---

## Security & secrets

- PixelLab API key: `~/.dopamine-ledger.env`, chmod 600.
- Never commit `.env` files. `.gitignore` should include `*.env`.
- The user's support email (in `PRIVACY.md` and `APP_STORE_LISTING.md`)
  is public-facing and intentionally shareable.
- No banking, no payment processing, no third-party SDKs — this app
  needs none of them. If a future feature seems to demand one, surface
  the question to the user before pulling it in.

### Incident — Session 5: Google API key committed to public repo

**What happened:** `scripts/generate_ai_icons.py` was written with the
Google AI Studio key hardcoded as a string literal. The script was
committed and pushed. GitHub secret scanning flagged it immediately.

**Why `.gitignore` didn't help:** `.gitignore` blocks files by name
(e.g. `*.env`). It cannot inspect the *contents* of committed files for
secret strings. A `.py` file with a hardcoded key bypasses it entirely.

**Fix applied:**
1. Key rotated in Google AI Studio (do this first — always).
2. Script updated to read from environment: `os.environ.get("GOOGLE_AI_KEY")`.
3. `git filter-repo --replace-text` used to scrub the string from every
   commit in history.
4. Force-pushed to GitHub. Secret scanning alert closed as revoked.

**Rule for every future script that needs an API key:**

```python
import os, sys
API_KEY = os.environ.get("MY_SERVICE_KEY", "")
if not API_KEY:
    sys.exit("Error: MY_SERVICE_KEY not set. Run: export MY_SERVICE_KEY=<key>")
```

The key itself lives in `~/.dopamine-ledger.env` (outside the repo,
chmod 600). Before running: `source ~/.dopamine-ledger.env`.

**Never hardcode a secret, even temporarily.** The assumption "I'll
remove it before committing" has a 100% failure rate across the industry.
