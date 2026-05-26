# DopamineLedger — Feature Tracker

> **Always read this file at the start of a session.**
> Features marked `done` are fully implemented. Assume the code is in place
> and do not re-implement or second-guess them. Pick up from the next
> `in progress` or `planned` item unless the user directs otherwise.

---

## Core loop

| Feature | Status | Files | Notes |
|---|---|---|---|
| Theme protocol + NeuTheme + SystemTheme | `done` | `Theme.swift`, `NeuTheme.swift` | PixelArtTheme exists but filtered from Settings picker |
| SwiftData models (Activity, Session, Ledger, ActivityDebt, Quest) | `done` | `Models/` | 22 unit tests passing |
| BalanceCard | `done` | `Views/BalanceCard.swift` | Queries Ledger; shows debt tap-through |
| Activity CRUD (create / edit / delete) | `done` | `Views/AddActivityView.swift` | Icon picker grid (31 SF Symbols), kind cards |
| Quest CRUD (create / edit / delete) | `done` | `Views/AddQuestView.swift` | |
| Session start / stop / pause / resume | `done` | `Views/SessionView.swift`, `Services/SessionFinalizer.swift` | Swipe-down allowed; session survives dismiss |
| Debt accrual at 2× rate on overrun | `done` | `Models/SessionMath.swift` | Unit-tested |
| Debt repay | `done` | `Views/DebtView.swift`, `Views/ActivityMenuView.swift` | RepayMath splits debt proportionally |
| Quests (one-tap payoff) | `done` | `Views/ActivityListView.swift` (QuestRow) | |
| Live Activities (Lock Screen + Dynamic Island) | `done` | `DopamineLedgerWidgets/` | SessionActivityAttributes; start/update/end wired |

## UX polish

| Feature | Status | Files | Notes |
|---|---|---|---|
| Active-session indicator (pulsing border on row) | `done` | `Views/ActivityListView.swift` (ActivityRow) | |
| Per-activity debt chip on spender rows | `done` | `Views/ActivityListView.swift` (ActivityRow) | |
| Icon picker (31 curated SF Symbols) | `done` | `IconResolver.swift`, `Views/AddActivityView.swift` | Activity.iconName persisted |
| About section in Settings (version, contact, privacy, repo) | `done` | `Views/SettingsView.swift` | Privacy URL → `https://cybercervela.github.io/DopamineLedger/privacy.html` |
| In-app language switcher (EN / FR / DE / ES) | `done` | `Views/SettingsView.swift`, `Localization/LanguageBundle.swift` | CJK strings present in catalog but hidden from picker |
| Foreground notification delivery | `done` | `Services/NotificationScheduler.swift`, `DopamineLedgerApp.swift` | `NotificationCenterDelegate` wired at app init |
| Live balance / debt display in SessionView | `done` | `Views/SessionView.swift` | Shows "X remaining" → turns red → "X in debt · 2× rate" |
| Chill mode (allow spender start with debt) | `done` | `Views/SettingsView.swift`, `Views/ActivityMenuView.swift` | `@AppStorage("chillMode")` |

## Infrastructure

| Feature | Status | Files | Notes |
|---|---|---|---|
| Localisation (EN/FR/DE/ES + ZH/JA/KO) | `done` | `Localization/Localizable.xcstrings` | 7 languages, 80+ keys |
| xcodegen project | `done` | `project.yml` | `make generate` regenerates pbxproj |
| Notification scheduling (5-min warning + zero alarm) | `done` | `Services/NotificationScheduler.swift`, `Models/NotificationMath.swift` | |
| Session recovery on relaunch / swipe-dismiss | `done` | `Views/ActivityListView.swift` (.task block) | |

## Privacy commitments (published — do not violate)

> The privacy policy at `docs/privacy.html` makes the following binding
> promises. **Any feature that would break one of these must update the
> policy and App Store listing before shipping.**

| Commitment | Detail |
|---|---|
| No data collection | Nothing is transmitted to any server — ever |
| All user data is local-only | Activities, sessions, ledger, quests, settings → SwiftData (on-device SQLite) |
| No iCloud sync | Data does not transfer between devices |
| Notifications are local | Scheduled via UserNotifications on-device; no server involved |
| Live Activities are local | ActivityKit data never leaves the device |
| No third-party SDKs | No analytics, crash reporters, or ad frameworks at runtime |
| Children safe | No data collection from any user, including under-13 |

## Backlog (post-MVP)

| Feature | Status | Notes |
|---|---|---|
| Pixel-art theme (Step 7) | `planned` | Assets not generated; excluded from MVP submission |
| Dashboard / stats | `done` | Steps 1–5 complete. `DashboardStats.swift` (pure model), `DashboardView.swift` (ScopePicker, SummaryCard, ActivityStatsSection, QuestHistorySection). See `JOURNAL.md` Sessions 6–7. |
| Decimal display for sub-1 credit amounts | `planned` | See `BACKLOG.md` |
| "How long can I keep going?" burn-down on spender rows | `planned` | See `BACKLOG.md` |
| Shortcut / HealthKit auto-session triggers | `planned` | See `BACKLOG.md` |
| App Store submission | `planned` | App icon ✓; privacy policy ✓; TestFlight build needed |
