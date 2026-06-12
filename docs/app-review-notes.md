# App Review Information — Notes (paste into App Store Connect)

> DRAFT — numbers in [brackets] are placeholders until the final Phase D
> counts are locked. PM pastes the fenced block below into App Store
> Connect → App Review Information → Notes for the 1.0.1 submission.

```
Thank you for the detailed feedback on our previous submission. We took the
quality concerns seriously and performed a full audit before resubmitting.
Improvements in this build (1.0.1):

DESIGN & CONSISTENCY
- Replaced the app icon with a final production asset.
- Unified all duration displays on a single format across every screen.
- Unified all credit-rate displays on one localized, abbreviated format
  (including the template gallery, which previously used its own).
- Audited all screens across iPhone SE, iPhone 17, and iPhone 17 Pro Max in
  light and dark mode; fixed [N] layout issues.

COMPLETENESS
- Verified all [N] localized strings across English, French, German,
  Spanish, Chinese (Simplified), Japanese, and Korean; routed the last
  [3] hardcoded strings through the localization system.
- Numeric input now accepts both comma and dot decimal separators, so
  European keyboards work correctly in every editor.
- Added input validation with clear, localized feedback (maximum activity
  rate and quest reward), replacing silent failure states.
- Removed all placeholder or debug-only content from the release build
  (verified against a Release-configuration build).

STABILITY
- Full unit test suite passing ([63] tests, up from 46 — new coverage for
  input parsing, import hardening, and validation boundaries).
- The backup-import flow was hardened and fuzz-tested against empty,
  truncated, malformed, wrong-schema, and oversized files: it now always
  fails safely with a friendly error and never touches existing data.
- Fixed an edge case where deleting all data during a running session could
  leave a stale Live Activity on the Lock Screen.
- Verified session recovery across app termination, device lock, and
  restart.
- Verified the app functions correctly in iPad compatibility mode.

DEVICE SUPPORT
- The app targets iPhone. We have disabled availability on Mac and
  Apple Vision Pro, as those platforms are not yet tested to our quality
  bar.

The app is fully offline and collects no data (see privacy policy at
https://cybercervela.github.io/DopamineLedger/privacy.html). No account is
required; all features are immediately accessible to the reviewer.
```
