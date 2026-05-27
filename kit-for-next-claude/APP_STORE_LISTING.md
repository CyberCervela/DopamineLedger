# App Store Listing Copy — Dopamine Ledger v1.0

Drafted copy for the App Store Connect listing. Paste each section into
the corresponding field. Edit freely — these are first drafts.

---

## App Name (max 30 chars)

```
Dopamine Ledger
```

(15 chars — well under the limit. If taken, try `Dopamine Ledger:
Time` (20 chars) or `Dopamine Ledger Pixel` (21).)

---

## Subtitle (max 30 chars)

```
A credit economy for your time
```

(31 chars — trim by 1. Alternatives:)

```
Time, as currency
```

```
Earn time. Spend it wisely.
```

```
A ledger for your dopamine
```

---

## Promotional Text (max 170 chars, editable anytime without resubmission)

```
A credit economy for the time you spend on what matters.
Charge by reading or exercising. Spend on scrolling. Don't go into debt.
```

(131 chars)

---

## Description (max 4000 chars)

```
Dopamine Ledger turns your time into currency.

Activities that build you up — reading, exercising, cooking, meditating,
working on what matters — are "Chargers." They earn credits over time
at a rate you set.

Activities that take from you — gaming, scrolling, watching TV, the
classic dopamine traps — are "Spenders." They consume credits at a rate
you set.

When you spend more than you've earned, you go into debt. Debt is
activity-specific: that game session you let run too long blocks the
game until you've earned enough credits elsewhere to repay it. Debt
accrues at a 2× penalty rate — there are real consequences to the
budget you set for yourself.

For things you've been putting off — taxes, that email, the dental
appointment — define them as Quests. One tap when complete. Big credit
payoff. No timer, no commitment, just the friction-breaking reward your
brain has been waiting for.

EVERYTHING IN ONE GLANCE
• Pinned balance card at the top of the home screen
• Live elapsed time and projected credit change while a session runs
• Section-grouped lists for Chargers, Spenders, and Quests
• Per-activity icons from a curated SF Symbol catalog

DESIGNED FOR THE BACKGROUND
• Local notifications fire 5 minutes before you hit zero on a spender,
  and again the moment you cross into debt — so you don't have to babysit
  the timer
• Sessions are timestamp-based, not tick-based: background the app
  freely, the math stays accurate
• Single-tap Start, Stop, Done, Repay — no menus, no settings dives

WHAT MAKES IT DIFFERENT
• A real credit/debt economy — not just a time tracker
• "Empty balance" block on spenders — you literally can't start spending
  what you haven't earned
• A satisfying repay loop with confirmation, haptics, and a clean
  ledger-page balance display
• Neumorphic design — soft shadows, dark surfaces, clean typography

PRIVACY
• 100% on-device. No accounts, no analytics, no servers.
• No data ever leaves your iPhone.

Dopamine Ledger is a personal productivity tool, not a medical or
therapeutic application. It is not a substitute for professional advice.

Built solo with SwiftUI, SwiftData, and Claude Code on iOS 17+.

COMING IN FUTURE UPDATES
  • Siri & Shortcuts — start a session with your voice,
    no screen required
  • HealthKit integration — auto-start a charger when
    you begin a workout
  • Tip jar — if Dopamine Ledger earns a place in your
    day, buy the developer a coffee
```

(~2,000 chars — under the limit, with room to expand.)

---

## What's New in This Version (max 4000 chars; required for v1.0)

```
The first release.

— A complete credit-debt economy for time you spend on chargers,
  spenders, and quests.
— Neumorphic design: soft shadows, dark surfaces, smooth digit
  animations, and a curated SF Symbol icon catalog.
— Live Activities: session timer on your Lock Screen and Dynamic Island.
— Dashboard with Today / This Week / All Time stats for every activity.
— Local notifications for the 5-minute warning and zero-balance alarm.
— Manual repay flow with confirmation, haptics, and animated balance.
— Built-in Settings: stop a forgotten session, reset balance, or
  clear accumulated debt. In-app language switcher (EN/FR/DE/ES).

No accounts. No analytics. No servers. Everything stays on your phone.
```

---

## Keywords (max 100 chars, comma-separated, no spaces around commas)

```
time tracking,credit,dopamine,productivity,habit,focus,ledger,pixel art,gamification,screen time
```

(99 chars)

---

## Categories

- **Primary**: Productivity
- **Secondary** (optional): Health & Fitness

Reasoning: Productivity is the closest semantic fit (time/habit
tracking). Health & Fitness gives us a secondary surface for
discovery — meditation, exercise, and wellness chargers are common
use cases.

---

## Age Rating

- **4+** (no objectionable content)

Answer Apple's questionnaire all "No" — no violence, no profanity,
no realistic depictions of substances, no user-generated content, no
unrestricted web access.

---

## Pricing

- **Free** for v1.0
- No in-app purchases
- No ads

(Future v1.x could add a paid pro tier — out of scope for launch.)

---

## App Privacy "Data Not Collected"

Answer the App Privacy questionnaire with:

- **"No, we do not collect data from this app"**

The privacy label will display as **"Data Not Collected"** on the
App Store listing.

---

## Copyright

```
© 2026 [Your Name]
```

(Fill in your legal name or the entity name you want on the listing.)

---

## Support URL

You need a public URL. Easiest options:

1. **GitHub repo readme** — create a repo `dopamine-ledger-support`,
   put a simple readme with the email
2. **Notion public page** — paste the support copy, publish, copy
   the public URL
3. **A single-page site** on your own domain

Suggested support page content (very minimal):

```
# Dopamine Ledger — Support

Found a bug? Have a suggestion? Email cibercervela@pm.me.

This is a solo personal-productivity app. There is no support team
beyond the email above. Response time is best-effort — expect 1-3
days.

Common questions:

**How do I reset all my data?**
Settings → Reset → Reset balance to 0 + Clear all debt. Activities can
be deleted by swiping a row. The whole app can be deleted via long-
press on the home screen.

**Why don't notifications work?**
Check Settings (iOS) → Notifications → Dopamine Ledger. If they were
disabled, re-enable them and the next spender session will schedule
them again.

**Is my data private?**
Yes. The app stores everything on-device. See the privacy policy at
[your privacy URL].
```

---

## Notes for Apple Review (optional, internal-only field)

```
This is a personal-productivity app with no user accounts, no network
calls beyond what iOS itself does for notification scheduling, no
analytics, no third-party SDKs. All data stays on the user's device
via SwiftData.

The "credit economy" mechanic is the core feature: time spent on
"charger" activities earns credits at a user-set rate; time spent on
"spender" activities spends them. Overruns create debt at 2× penalty
rate. The unique novelty is the debt + activity-specific block —
you can't start a Game session if Game has unpaid debt.

Local notifications are used during spender sessions to warn the user
before they go into debt. No push notifications, no server.
```

---

## Final pre-submission checklist

- [ ] App name confirmed available
- [ ] All copy above pasted into App Store Connect
- [ ] At least 3 screenshots uploaded (6.7" / iPhone Pro Max)
- [ ] Privacy policy URL filled in (and the URL works — test it)
- [ ] Support URL filled in (and works)
- [ ] App Privacy questionnaire answered "Data Not Collected"
- [ ] Content rating answered → 4+
- [ ] Build uploaded via Xcode Archive flow
- [ ] Build selected in App Store Connect → 1.0 Prepare for Submission
- [ ] **Add for Review** clicked
- [ ] **Submit for Review** confirmed