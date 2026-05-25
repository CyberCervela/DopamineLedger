# DopamineLedger — Backlog

Items deferred from active development. Verify or ship when ready.

---

## UI polish — post-MVP

| Item | Notes |
|---|---|
| Sheet header buttons (Cancel / Save / Done) neumorphic styling | Buttons have correct pill shape but the header row sits slightly above the scroll content with a visible seam. Root cause: `.presentationBackground` + plain VStack doesn't fully match the navigation bar treatment. Investigate `UISheetPresentationController` background or a sticky-header approach inside the ScrollView. Low priority — buttons are functional and legible. |

---

## Post-MVP features

| Item | Notes |
|---|---|
| Dashboard / streaks / stats | Full history view, streak counters, credit earned/spent charts |
| Decimal display for sub-1 credit amounts | e.g. show "0.4 cr" instead of "0 cr" |
| "How long can I keep going?" burn-down on spender rows | Shows estimated time left at current rate before balance hits zero |
| Shortcut / HealthKit auto-session triggers | Start/stop sessions via Shortcuts app or HealthKit workout events |
| Pixel-art theme (Step 7) | Assets not generated; fonts wired but no pixel-art icons yet |
| App Store submission | TestFlight build needed; app icon ✓, privacy policy ✓ |
