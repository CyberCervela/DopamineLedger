# App Review Information — Notes (paste into App Store Connect)

> **FINALIZED for 1.0.1 resubmission** (2026-06-19). Paste the block below into
> App Store Connect → App Review Information → Notes. The previously-bracketed
> items are now resolved: the icon line is kept (final icon shipped), and the
> physical-hardware line reflects extended real-world device use.
>
> **Two lines must match reality before you submit:**
> 1. *"We have disabled availability on Mac and Apple Vision Pro"* — only true
>    once you actually uncheck those in App Store Connect → Pricing and
>    Availability (QA-03). Do that first, or the note contradicts your settings.
> 2. The physical-hardware line says *"extended daily use."* Only strengthen it
>    to *"including a 24-hour soak test of session recovery"* if you actually
>    run that deliberate test during your device pass. Do not claim it otherwise.

```
Thank you for the detailed feedback on our previous submission. We took the
Developer Code of Conduct and quality concerns seriously and performed a full
audit of the app before resubmitting. Improvements in this build (1.0.1):

DESIGN & CONSISTENCY
- Replaced the app icon with a final, production-quality asset.
- Unified all duration displays on a single format across every screen
  (previously three different formats were in use).
- Unified all credit-rate displays on one localized, abbreviated format.
- Audited every screen across iPhone SE (3rd gen), iPhone 17, and iPhone 17
  Pro Max in both app themes and in light and dark mode — roughly 280
  reviewed screenshots. No layout defects remain.

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
- Full unit test suite passing (63 tests, up from 46 — added coverage for
  input parsing, backup-import hardening, and validation boundaries).
- The backup-import flow was hardened and tested against empty, truncated,
  malformed, wrong-schema, and oversized files: it always fails safely with
  a friendly error and never modifies existing data.
- Fixed: the export share sheet could present empty on first use; and
  deleting all data during a running session could leave a stale Live
  Activity on the Lock Screen. Both are resolved.
- Verified session recovery across app relaunch and Lock Screen, and
  verified all core flows work correctly with notification permission denied.
- Verified the app functions correctly in iPad compatibility mode
  (full core-flow walk on iPad Pro 11").
- Verified on physical iPhone hardware through extended daily use, including
  session recovery across lock, backgrounding, and app restart.

DEVICE SUPPORT
- The app targets iPhone. We have disabled availability on Mac and Apple
  Vision Pro, as those platforms are not yet tested to our quality bar.

The app is fully offline and collects no data (see the privacy policy at
https://cybercervela.github.io/DopamineLedger/privacy.html). No account is
required, and all features are immediately accessible to the reviewer.
```
