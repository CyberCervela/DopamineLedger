# App Review Information — Notes (paste into App Store Connect)

> FINAL numbers as of 2026-06-12 (branch `resubmission-qa`). Two bracketed
> items remain for the PM: the icon line (pending the QA-01 asset) and the
> device-pass line (pending QA-23/24 on a physical iPhone). Delete or keep
> them accordingly before pasting into App Store Connect → App Review
> Information → Notes.

```
Thank you for the detailed feedback on our previous submission. We took the
quality concerns seriously and performed a full audit before resubmitting.
Improvements in this build (1.0.1):

DESIGN & CONSISTENCY
- Replaced the app icon with a final production asset.
- Unified all duration displays on a single format across every screen
  (previously three different formats).
- Unified all credit-rate displays on one localized, abbreviated format.
- Audited every screen across iPhone SE (3rd gen), iPhone 17, and iPhone 17
  Pro Max in both app themes and in light and dark mode — roughly 280
  reviewed screenshots; no layout defects remain.

COMPLETENESS
- Verified all 214 localized string keys across English, French, German,
  Spanish, Chinese (Simplified), Japanese, and Korean; routed the last 3
  hardcoded strings through the localization system.
- Numeric input now accepts both comma and dot decimal separators, so
  European keyboards work correctly in every editor.
- Added input validation with clear, localized feedback (maximum activity
  rate and quest reward) in place of silent failure states.
- Verified against a Release-configuration build that no debug-only
  content is present.

STABILITY
- Full unit test suite passing (63 tests, up from 46 — new coverage for
  input parsing, backup-import hardening, and validation boundaries).
- The backup-import flow was hardened and tested against empty, truncated,
  malformed, wrong-schema, and oversized files: it always fails safely with
  a friendly error and never touches existing data.
- Fixed: the export share sheet could present empty on first use; deleting
  all data during a running session could leave a stale Live Activity on
  the Lock Screen.
- Verified session recovery across app relaunch and Lock Screen, and
  verified all core flows work with notification permission denied.
- Verified the app functions correctly in iPad compatibility mode
  (full core-flow walk on iPad Pro 11").
[- Verified on physical iPhone hardware, including a 24-hour soak test of
  session recovery across lock, backgrounding, and restart.]

DEVICE SUPPORT
- The app targets iPhone. We have disabled availability on Mac and
  Apple Vision Pro, as those platforms are not yet tested to our quality
  bar.

The app is fully offline and collects no data (see privacy policy at
https://cybercervela.github.io/DopamineLedger/privacy.html). No account is
required; all features are immediately accessible to the reviewer.
```
