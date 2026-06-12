# DopamineLedger — App Store Resubmission Checklist (post-5.6 rejection)

> **For Claude Code.** Read this file top to bottom before doing anything.
> Work through phases in order. Do not skip Phase 0.
>
> **Context:** v1.0 (build 1) was rejected under Guideline 5.6 (Developer Code
> of Conduct — Review Suspended, quality standard). The account is flagged:
> the next submission gets extra scrutiny, and a resubmission with similar
> issues risks Developer Program action. We get effectively ONE clean shot.
> Goal: a resubmission where every reviewer-visible surface is finished,
> consistent, and stable — plus detailed improvement notes in App Review
> Information (Apple explicitly requested this).
>
> **Tags:** `[CC]` = Claude Code executes/verifies in terminal or simulator.
> `[PM]` = human task (physical device, judgment call, or App Store Connect).
> Report each item as PASS / FAIL / FIXED with one-line evidence.

---

## Phase 0 — Rules of engagement (read, don't execute)

- **Feature freeze.** No new features in this build. DL-15, DL-10, and all
  Tier 1+ backlog items are deferred to v1.1 post-approval. This build is
  polish + fixes only.
- **No regressions.** Every fix must keep the 22+ unit tests green and must
  not touch locked product rules (debt 2×, activity-specific debt, manual
  repay, open-ended sessions) or the published privacy commitments in
  FEATURES.md.
- **Smallest safe diff.** Prefer one-line fixes. Log every change in
  JOURNAL.md under a "Resubmission QA" session entry as you go — this log
  becomes the source for the App Review notes.

---

## Phase 1 — P0 blockers (must be FIXED, not just noted)

- [ ] **QA-01 [PM→CC] Replace the app icon.** Current `AppIcon-1024.png` is
      Gemini-generated and carries a visible ✦ watermark (bottom-right; see
      JOURNAL.md Session 4 "Known"). App Review sees the icon at full
      1024×1024. A visible AI watermark on the icon directly feeds a 5.6
      "unfinished/low-effort" read. PM supplies or approves a clean
      replacement (regenerate without watermark, or crop/repaint is NOT
      acceptable if it degrades quality — regenerate properly). CC wires it
      into `AppIcon.appiconset` and verifies: 1024×1024, RGB, no alpha, no
      watermark at 100% zoom (open the PNG and inspect all four corners
      programmatically + visually).
- [ ] **QA-02 [CC] Bump version + build.** `Info.plist`:
      `CFBundleShortVersionString` 1.0 → 1.0.1 (or 1.1 if PM prefers — ask),
      `CFBundleVersion` 1 → 2. Also check the widget extension target's
      version stays in sync (App Store Connect rejects mismatched
      CFBundleShortVersionString between app and extension).
- [ ] **QA-03 [PM] App Store Connect — device availability.** In App Store
      Connect → Pricing and Availability / App Information, UNCHECK "Make
      this app available on Apple Silicon Macs" and "Make this app available
      on Apple Vision Pro" (wording varies). Rationale: rejection text says
      the app must "function on all the devices where they are available" —
      we have never tested Mac or Vision Pro, so remove them from
      availability rather than gamble. iPad compatibility mode cannot be
      opted out of for iPhone apps and must instead pass QA-22.
- [ ] **QA-04 [PM] Confirm resubmission eligibility date** in App Store
      Connect (Resolution Center). Do not submit before it. Record the date
      at the top of this file when known.

---

## Phase 2 — Automated static audit `[CC]`

Run from repo root. Fix anything found, or escalate to PM if a fix needs a
product decision.

- [ ] **QA-05 Build clean.** `make generate && make build` → BUILD SUCCEEDED
      with zero warnings introduced by this QA pass. Triage existing
      warnings: fix the cheap ones, list the rest.
- [ ] **QA-06 Tests green.** Run the full `DopamineLedgerTests` suite. All
      pass. If any test is skipped/disabled, justify or re-enable.
- [ ] **QA-07 Placeholder sweep (user-visible only).** Grep all `.swift`,
      `.xcstrings`, and asset catalogs for: `TODO`, `FIXME`, `WIP`,
      `placeholder`, `lorem`, `test`, `debug`, `temp`, `XXX`, `coming soon`,
      `not implemented`. Classify each hit as (a) code-comment-only — OK,
      (b) user-visible string — FIX, (c) DEBUG-gated — verify the `#if DEBUG`
      guard actually excludes it from Release config.
- [ ] **QA-08 Localization completeness.** Script a pass over
      `Localizable.xcstrings`: every key must have a non-empty value for
      en, fr, de, es (the four picker-visible languages). Report any key
      that falls back to English in fr/de/es, any value identical to its key
      name, and any value still in English in a non-en locale. ZH/JA/KO are
      hidden from the picker — confirm the picker filter still excludes them.
- [ ] **QA-09 Hardcoded-string sweep.** Grep view files for `Text("` with
      raw literals (not `lBundle.l(`). Every user-visible string must route
      through localization. Fix stragglers in all 4 visible languages.
- [ ] **QA-10 Dead-asset audit.** PixelArt fonts (`Monogram.ttf`,
      `AbaddonBold.ttf`) ship in the bundle but the theme is excluded from
      Settings. Confirm nothing user-visible references them and that no
      pixel-art UI can be reached. (Keeping them bundled is fine — they're
      invisible.) Confirm `ThemeRegistry.all` filter still excludes
      `pixelArt`.
- [ ] **QA-11 Release-config audit.** Build a Release configuration. Verify:
      "Load Test Data" button absent from Settings, no debug logging visible,
      no `print` spam in console on normal flows (sample the main flows).
- [ ] **QA-12 Crash-surface audit.** Grep for force-unwraps (`!`) and
      `try!`/`fatalError` in Views/ and Services/. For each, verify the
      invariant genuinely cannot fail at runtime, or replace with safe
      handling. Pay special attention to SwiftData fetches, URL inits in the
      linked-app gatekeeper catalog, and notification scheduling.
- [ ] **QA-13 Privacy consistency.** Re-verify the app matches every row of
      the "Privacy commitments" table in FEATURES.md (no network calls:
      grep for `URLSession`, `URLRequest` — the only acceptable hits are the
      linked-app `canOpenURL`/`open` flows which don't transmit data). Confirm
      the privacy URL in Settings → About resolves (curl the github.io page,
      expect 200).
- [ ] **QA-30 Malformed-import hardening.** The Import flow is
      reviewer-reachable. Write unit tests feeding it: an empty file, truncated
      JSON, valid JSON with wrong schema, a huge file, and a non-JSON file.
      Every case must surface a friendly localized error and leave existing
      data untouched — never crash, never partially import. Fix what fails.
- [ ] **QA-31 Launch screen check.** Verify a real launch screen is
      configured (not blank/default) and that it doesn't flash placeholder
      content before the home screen renders.
- [ ] **QA-32 iOS floor pass.** Build and run the core flows once on an
      iOS 17.x simulator (oldest supported), not just the latest runtime.
      Catch any API used without an availability guard.
- [ ] **QA-14 App Store metadata vs reality.** Fetch the current listing
      description (PM to paste it into the repo as
      `docs/appstore-listing.md` if not already there). Verify every claimed
      feature exists in the build, and the "COMING IN FUTURE UPDATES" list
      (Siri ✅ shipped / HealthKit / tip jar) is still accurate. Flag any
      mismatch — misleading metadata is its own rejection class (2.3).

---

## Phase 3 — Simulator visual QA matrix `[CC]`

Run the app in the iOS Simulator and screenshot every screen in every cell
of this matrix. Review each screenshot BOTH directions (new elements present
AND nothing broken/leftover — per WORKFLOW.md lesson from Session 7).
Store screenshots under `qa/resubmission/` with the naming scheme
`<screen>-<device>-<theme>-<scheme>.png` and write a findings table.

**Devices:** iPhone SE (3rd gen — smallest, most layout breakage),
iPhone 17 (standard), iPhone 17 Pro Max (largest).
**Themes:** Dopamine (Neu) and System.
**Color scheme:** System theme in BOTH light and dark; Dopamine in its
locked scheme.
**Locales:** full pass in EN; spot-pass (home, session, settings, add
activity) in FR and DE (German strings are longest — most truncation risk).

Screens to capture (from FEATURES.md):

- [ ] **QA-15** Home — All / Chargers / Spenders / Quests tabs, each with
      data AND in empty state (use the debug seeder in a Debug build for the
      data states; delete all for empty states).
- [ ] **QA-16** BalanceCard — zero balance, normal balance, ≥100K
      (abbreviation), in-debt state with debt tap-through.
- [ ] **QA-17** Session flows — charger running, spender running with
      burn-down, spender past zero (red overrun + "in debt · 2× rate"),
      paused state, pinned-active row + ACTIVE badge on home.
- [ ] **QA-18** Add/Edit Activity (incl. icon grid, kind cards, linked-app
      picker), Add/Edit Quest, recurring quest badge states, template
      gallery, add-choice sheet, long-press action sheet.
- [ ] **QA-19** Stats/Dashboard — Today/Week/All scopes, with data and
      empty. History — bundled runs, day grouping, empty.
- [ ] **QA-20** Settings — every section; language switch live-applies;
      Export/Import round trip (export, wipe via import of the exported
      file); Debt view + repay flow.
- [ ] **QA-21** Live Activity / Dynamic Island + lock screen widget during
      an active session (simulator supports this; verify both compact and
      expanded presentations, charger and spender).
- [ ] **QA-22 iPad compatibility mode.** Run the iPhone build on an iPad
      simulator (compatibility window). Walk the five core flows: create
      activity → start charger → stop → start spender → repay debt. Nothing
      needs to be beautiful; nothing may be broken, clipped, or crash.
      Screenshot evidence.

- [ ] **QA-33 Dynamic Type pass.** On iPhone SE + iPhone 17, set text size
      to XL and to the largest accessibility size; screenshot the four core
      screens (home, session, add activity, settings). No clipped, truncated,
      or overlapping text on core actions. Fix blockers; log `accept` items
      with PM sign-off.
- [ ] **QA-34 Notification-denied state.** In the simulator, deny
      notification permission on fresh install. Run a charger and a spender
      session end to end: timers must work, no repeated permission nagging,
      and the user must still be able to see time-up state in-app.

**Findings rule:** every visual defect gets logged with screenshot path,
severity (blocker / fix / accept), and — after PM triage — fixed or
explicitly accepted in writing.

---

## Phase 4 — On-device + judgment QA `[PM]` (Claude Code prepares, PM executes)

- [ ] **QA-23** Full manual pass on a physical iPhone, fresh install (delete
      app first): onboarding-less first launch must make sense to a
      stranger. Notifications: grant flow, 5-min warning, zero alarm,
      foreground delivery, time-up behavior after force-quit.
- [ ] **QA-24** 24-hour soak: leave a session running across a lock/unlock,
      app backgrounding, and a device restart. Session recovery must be
      correct (timestamp-based model should survive all three).
- [ ] **QA-25** Siri intents on device: all 5 phrases (Start / Stop / Pause /
      Resume / Check Balance) in EN; confirm they fail gracefully in
      unsupported locales rather than erroring.
- [ ] **QA-26** Language judgment pass: PM (native FR) reads every FR
      string in situ. DE/ES: if no native review available, at minimum
      verify nothing is machine-garbled on the four core screens — or hide
      DE/ES from the picker for this submission (PM decision; hiding is the
      conservative play and they can return in 1.1 after review).
- [ ] **QA-27** App Store screenshots: retake ALL listing screenshots from
      the final build (current set predates Sessions 41–51 UI changes —
      long-press sheet, ACTIVE badge, abbreviated numbers may be visibly
      inconsistent with the live app, which is a 2.3 metadata risk).

---

## Phase 5 — Submission package `[PM]`, drafted by `[CC]`

- [ ] **QA-28** Claude Code drafts `docs/app-review-notes.md` from the
      JOURNAL.md "Resubmission QA" entry, using the template below. PM
      pastes it into App Store Connect → App Review Information → Notes.
- [ ] **QA-35 [PM] App Store Connect consistency sweep.** Verify: (a) the
      App Privacy questionnaire answers say "Data Not Collected" and match
      FEATURES.md; (b) the Support URL resolves and offers a real contact
      path; (c) age rating and category are sensible; (d) check the
      Resolution Center thread for any attachments or device/OS details from
      the reviewer we haven't used (they sometimes include screenshots of
      what failed).
- [ ] **QA-29** Final pre-flight: archive build, validate in Xcode Organizer
      (no asset/entitlement warnings), upload, confirm build processes in
      App Store Connect without warnings, attach to the 1.0.1 version,
      submit — on or after the eligibility date from QA-04.

### App Review notes template

```
Thank you for the detailed feedback on our previous submission. We took the
quality concerns seriously and performed a full audit before resubmitting.
Improvements in this build (1.0.1):

DESIGN & CONSISTENCY
- Replaced the app icon with a final production asset.
- [List every visual fix from Phase 3 findings, one line each.]
- Audited all screens across iPhone SE, iPhone 17, and iPhone 17 Pro Max in
  light and dark mode; fixed [N] layout issues.

COMPLETENESS
- Verified all [N] localized strings across English, French, German, and
  Spanish; removed/fixed [N] incomplete translations.
- Removed all placeholder or debug-only content from the release build.

STABILITY
- Full unit test suite passing ([N] tests).
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

---

## Reporting format (for Claude Code)

At the end of each phase, output a table: `ID | Status (PASS/FIXED/FAIL/PM) |
Evidence (file:line, screenshot path, or command output)`. Append the table
to JOURNAL.md under the Resubmission QA session. Stop and ask the PM before
any fix that touches a locked rule, the data model, or the privacy policy.
