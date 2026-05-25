# DopamineLedger — Backlog

Items deferred from active development. Verify or ship when ready.

---

## UI polish — post-MVP

| Item | Notes |
|---|---|
| Sheet header buttons (Cancel / Save / Done) neumorphic styling | Buttons have correct pill shape but the header row sits slightly above the scroll content with a visible seam. Root cause: `.presentationBackground` + plain VStack doesn't fully match the navigation bar treatment. Investigate `UISheetPresentationController` background or a sticky-header approach inside the ScrollView. Low priority — buttons are functional and legible. |
| Consolidate `formatDuration` helper | Duplicated in `ActivityListView.swift` and `SessionView.swift`. Extract to a shared `DurationFormatter.swift` or extension on `TimeInterval`. Zero user-visible impact — purely internal cleanup. |

---

## Next session — priority order

| # | Item | Notes |
|---|---|---|
| 1 | **App Store screenshots — fix & retake** | `Settings.png` captured mid-scroll (top cut off). `Create quest.png` has large empty lower half. `Dashboard.png` is 1320×2868 (6.9") while all others are 1206×2622 (6.3") — needs a consistent set. Retake on the same simulator before submission. |
| 2 | **App Store submission** | Blocked on Apple Developer Program approval (applied, awaiting email). Once Team ID is in hand: set `DEVELOPMENT_TEAM` in Xcode, archive, upload, screenshots, listing copy from `kit-for-next-claude/APP_STORE_LISTING.md`. |
| 3 | **Decimal display for sub-1 credit amounts** | Show "0.4 cr" instead of "0 cr". Formatting-only change in one or two display sites. |

---

## Post-MVP features

| Item | Notes |
|---|---|
| **Dashboard / stats** | Streaks, total credits earned/spent, session count, most-used activities. New tab or sheet off the home screen. All data is already in SwiftData. |
| **History screen** | Chronological log of completed sessions and — most importantly — completed quests. Quests are big rewarding life milestones (e.g. "Publish Dopamine Ledger") and deserve their own timeline view. Think: a scrollable journal of achievements, date-stamped, showing the quest name, payoff earned, and date completed. Could live inside the Dashboard or as its own tab. |
| Decimal display for sub-1 credit amounts | e.g. show "0.4 cr" instead of "0 cr" |
| Shortcut / HealthKit auto-session triggers | Start/stop sessions via Shortcuts app or HealthKit workout events |
| Pixel-art theme (Step 7) | Assets not generated; fonts wired but no pixel-art icons yet |
