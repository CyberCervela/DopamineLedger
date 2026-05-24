# SPECIFICATION.md — Dopamine Ledger

The product model. Locked unless the user explicitly changes it.

---

## Vocabulary

- **Credit** — the universal unit of the economy. Floating point. Never
  rounded for storage; only for display.
- **Balance** — the user's single global credit pool. Lives in `Ledger`.
- **Activity** — a thing the user does that interacts with the economy.
  Three kinds: charger, spender, quest.
- **Session** — one open-ended start-to-stop usage of a charger or
  spender activity.
- **Debt** — credits owed back as a consequence of overrunning a spender
  past zero. Debt is per-activity, not pooled.
- **Repay** — explicit manual user action that moves credits from balance
  back into a specific activity's debt row(s).

---

## Activity kinds

### Charger
- Earns credits over time at `ratePerMinute` while a session is running.
- No notifications. No blocks. No debt. Pure positive.
- Examples: reading, exercising, meditating — anything the user wants to
  do *more* of.

### Spender
- Spends credits over time at `ratePerMinute` while a session is running.
- Two local notifications scheduled at session start: a 5-minute-remaining
  warning (suppressed if the balance would zero in under 5 minutes) and a
  zero-balance alarm.
- Can overrun past zero — see "Debt" below.
- Can be blocked from starting — see "Blocks" below.
- Examples: social media, games — anything the user wants to do *less* of.

### Quest
- Not session-based. One-tap pay-out.
- User defines name + `payoffCredits`. Tapping **Done** credits the
  balance by the payoff and removes the quest from the active list
  (soft-deleted via `isCompleted = true`).
- No debt. No notifications. Reward-only.
- Designed for annoying-but-quick tasks that benefit from a bounty
  (the dishes, the inbox, etc.).

---

## Economy math

All math is in `scaffolds/Models/*Math.swift` as pure functions —
unit-testable, no SwiftData.

### Session math (`SessionMath.apply`)
Given `kind`, `ratePerSecond`, `elapsed`, `currentBalance` →
returns `(newBalance, debtAccrued)`.

- Charger: `newBalance = currentBalance + ratePerSecond × elapsed`, no debt.
- Spender (no overrun): `newBalance = currentBalance − ratePerSecond × elapsed`,
  no debt.
- Spender (overrun): balance drains to zero, then the **overrun portion only**
  accrues debt at `2 × ratePerSecond`.
  - Example: balance 6, rate 0.1/sec, elapsed 90s → balance hits zero at
    60s, 30s overrun → debt = 30 × 0.1 × 2 = 6.
- Spender starting at empty balance is **prevented by the empty-balance
  block** (see below), but the math handles it defensively: full elapsed
  time at 2× rate.

### Repay math (`RepayMath.apply`)
Given `currentBalance`, `totalDebt` → returns
`(amountRepaid, newBalance, newDebtTotal)`.

- Repays `min(balance, debt)` from balance into debt.
- Negative inputs are clamped to zero.

### Notification math (`NotificationMath.compute`)
Given `currentBalance`, `ratePerSecond` → returns
`NotificationTimes?` with `warningInSeconds: TimeInterval?` and
`alarmInSeconds: TimeInterval`.

- `alarmInSeconds = currentBalance / ratePerSecond`.
- `warningInSeconds = alarmInSeconds − 300`, or `nil` if that's ≤ 0.
- Returns `nil` entirely for non-positive balance or non-positive rate.

---

## Sessions

- Open-ended. The user taps Start, lives life, taps Stop.
- Timing is **timestamp-based** (compute `elapsed = endedAt − startedAt`
  on read), not tick-based. Backgrounding the app must not lose accuracy.
- One active session globally at any time. The home screen surfaces it
  (planned — round 1 didn't ship the indicator; see `BACKLOG.md`).
- Stopping a session triggers `SessionFinalizer.finalize(...)`, which is
  the single end-of-session flow:
  1. Cancel pending notifications for this session.
  2. Stamp `endedAt = Date()`.
  3. Look up the activity (handle deleted-mid-session).
  4. Apply `SessionMath`.
  5. Update `Ledger.balance`.
  6. Insert `ActivityDebt` if `debtAccrued > 0`.
  7. Return a `FinalizedSession` for toast feedback.

`SettingsView` also calls `SessionFinalizer.finalize(...)` from its
"Stop active session" reset option. Same flow, both call sites.

---

## Debt

- Accrues at 2× the spender rate **only on the overrun portion** of a session.
- Stored as `ActivityDebt(activityId, amount, createdAt)`. One row per
  overrun. A single activity can accumulate multiple rows over time.
- Total debt for an activity = sum of its non-zero `ActivityDebt.amount`.
- `ActivityDebt.isRepaid` is a computed convenience for `amount == 0`.

### Blocks

- **Per-activity debt block.** A spender activity with any outstanding
  debt cannot start a new session until that debt is fully repaid.
  Charger and quest behavior is unaffected (they only earn).
- **Empty-balance block.** A spender session cannot start when
  `Ledger.balance ≤ 0`. Chargers and quests are unaffected.
- An already-blocked activity does not accumulate further debt — by
  design. Simplifies edge cases.

### Repayment

- **Explicit and manual.** The user taps a Repay button on a debt row.
  Never automatic, never silent.
- Repayment is partial-friendly: if balance < debt, balance goes to zero
  and debt drops by the balance amount.
- Confirmation alert before the repay. Haptic + toast after.

---

## UI shape (high level)

The view layer will be re-derived against the theme protocol in round 2,
but the screens map 1:1 to round 1 and the user has lived with this shape
long enough to know it works.

- **`ActivityListView`** (home)
  - Top: `BalanceCard` — balance number with rolling-digit transition,
    debt summary, "active session" indicator (planned).
  - Body: segmented picker `[All | Chargers | Spenders | Quests]`, list
    of activities matching the filter, swipe-to-delete.
  - Toolbar: gear icon (settings), plus icon (add activity / quest sheet).
- **`SessionView`** — per-activity session runner with live `TimelineView`
  timer and balance footer. Pencil in nav bar to edit (hidden while a
  session is running on this activity).
- **`AddActivityView`** — sheet, mode enum for `.create` vs `.edit`.
- **`AddQuestView`** — sheet, name + payoff.
- **`SettingsView`** — sheet from gear: stop active session, reset balance
  to 0, clear all debt, (round 2) theme switcher.

Toasts: a single reusable component with factory methods per event
(`.chargerStopped`, `.spenderStopped`, `.questCompleted`, `.debtRepaid`).
Don't roll a new toast per view.
