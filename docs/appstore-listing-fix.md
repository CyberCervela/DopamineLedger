# App Store listing fix — F-03 / QA-14 (PM action)

**Why:** the live listing's "COMING IN FUTURE UPDATES" block still lists
*Siri & Shortcuts* as a future feature, but Siri shipped in this build
(5 intents: Start / Stop / Pause / Resume / Check Balance). Metadata that
contradicts the binary is its own rejection class (Guideline 2.3) — and this
resubmission cannot afford one.

**Action:** in App Store Connect → App Information / Description, replace the
"COMING IN FUTURE UPDATES" block with the corrected version below. While
there, please also paste the FULL current live description into
`docs/appstore-listing.md` in this repo so the rest of QA-14 (every claimed
feature exists in the build) can be verified line by line.

---

## Replace this block

```
COMING IN FUTURE UPDATES
  • Siri & Shortcuts — start a session with your voice,
    no screen required
  • HealthKit integration — auto-start a charger when
    you begin a workout
  • Tip jar — if Dopamine Ledger earns a place in your
    day, buy the developer a coffee
```

## With this

```
NEW IN THIS VERSION
  • Siri & Shortcuts — start, stop, pause, or resume a
    session and check your balance with your voice

COMING IN FUTURE UPDATES
  • HealthKit integration — auto-start a charger when
    you begin a workout
  • Tip jar — if Dopamine Ledger earns a place in your
    day, buy the developer a coffee
```

(Or simply move the Siri line into the feature list higher up — the essential
thing is that Siri is no longer promised as "future." HealthKit and the tip
jar remain accurate as future items: HealthKit is DL-21 in the backlog, the
tip jar is in the monetisation plan.)
