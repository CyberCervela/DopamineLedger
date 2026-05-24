# App Store Submission Plan — Dopamine Ledger

Master checklist for getting v1.0 onto the App Store. Items marked
**[Done]** are already in the project. Items marked **[You]** require
your action (account access, payment, manual decisions).

The submission process has four phases:

1. **Account & registration** — get the keys to the kingdom
2. **App Store Connect setup** — create the listing record
3. **Build & upload** — Archive in Xcode, push to App Store Connect
4. **Submit for review** — fill out questionnaires, wait for Apple

Expected total time: **half a day of focused work**, plus 24-72 hours of
Apple review.

---

## Phase 1 — Account & registration

### 1.1 Apple Developer Program

- [ ] **[You]** Enroll at <https://developer.apple.com/programs/>.
  - Cost: **$99 USD/year**
  - Use your existing Apple ID
  - Individual or Company (Individual is fine for a personal project;
    Company requires a D-U-N-S number)
  - Approval: usually 24-48 hours

You can prepare everything below while waiting for approval; you just
can't *submit* until enrollment completes.

### 1.2 Developer Team ID

Once enrolled, locate your **Team ID** (a 10-character alphanumeric
string) at <https://developer.apple.com/account> → Membership.

You'll need it for code-signing in Xcode (Phase 3).

---

## Phase 2 — App Store Connect setup

### 2.1 Bundle ID

Current bundle ID in the project: **`com.dopamine.ledger`**.

- [ ] **[You]** Decide whether to keep this or change it.
  - **Risk:** `com.dopamine.ledger` is generic — *someone else may
    already own it* on Apple's namespace.
  - **Safer:** use your reverse domain or your name, e.g.
    `com.cibercervela.dopamineledger` or `me.cibercervela.dopamineledger`.

If changing, update the project:

```
DopamineLedger.xcodeproj/project.pbxproj
  PRODUCT_BUNDLE_IDENTIFIER = com.dopamine.ledger;
                              ↓
  PRODUCT_BUNDLE_IDENTIFIER = me.cibercervela.dopamineledger;
```

(Two occurrences — Debug and Release. Tell me your choice and I'll edit
for you, or do it in Xcode's Signing & Capabilities pane.)

### 2.2 Register the App ID with Apple

- [ ] **[You]** At <https://developer.apple.com/account/resources/identifiers>:
  - Click **+** → **App IDs** → **App**
  - Description: `Dopamine Ledger`
  - Bundle ID: the one you settled on
  - Capabilities: tick **Push Notifications**? **No** — we only use
    local notifications, no entitlement needed. Leave defaults.

### 2.3 Create the App Store Connect record

- [ ] **[You]** At <https://appstoreconnect.apple.com/apps>:
  - Click **+** → **New App**
  - Platform: **iOS**
  - Name: `Dopamine Ledger` (if taken, try `Dopamine Ledger by
    [yourname]` or similar)
  - Primary language: English (U.S.)
  - Bundle ID: select the one you registered in 2.2
  - SKU: any unique string, e.g. `dopamine-ledger-001`
  - User access: Full Access

### 2.4 App Privacy questionnaire

Apple asks a detailed questionnaire about data collection. **Our answers
are all "No" or "Not collected"** because the app stores everything
locally and never transmits user data.

- [ ] **[You]** In App Store Connect → App Privacy:
  - Click **Get Started** under "Data Collection"
  - Select **No, we do not collect data from this app**
  - Click Save → Publish

That's it. The app's privacy nutrition label will read **"Data Not
Collected"** — a strong signal to privacy-aware users.

---

## Phase 3 — Build & upload

### 3.1 Open in Xcode (one-time setup)

- [ ] **[You]** Open `DopamineLedger.xcodeproj` in Xcode.
- [ ] **[You]** Top of project navigator → **DopamineLedger target** →
  **Signing & Capabilities** tab:
  - Tick **Automatically manage signing**
  - Team: select your developer team
  - Bundle Identifier: should match what you registered (Phase 2.1)

### 3.2 Pre-flight technical checklist (already done)

- [Done] App icon at 1024×1024 in `Assets.xcassets/AppIcon.appiconset/`
- [Done] `INFOPLIST_KEY_UIAppFonts` declared (custom fonts ship correctly)
- [Done] `ITSAppUsesNonExemptEncryption = false` (no encryption questionnaire on submission)
- [Done] `INFOPLIST_KEY_UIUserInterfaceStyle = Dark` (locks app to dark mode — matches design)
- [Done] `UISupportedInterfaceOrientations_iPhone = portrait only` (app is portrait-only by design)
- [Done] iOS deployment target = 17.0
- [Done] Marketing version = 1.0, Build = 1
- [Done] All 22 unit tests passing

### 3.3 Capture screenshots

Apple requires screenshots for the **6.7"** size class (iPhone 14/15/16/17 Pro Max),
**minimum 3, maximum 10**. The iPhone 17 Pro Max simulator we've been using
is the right device.

**Recommended set of 5** (suggested order on the App Store listing):

| # | Screen | Why it sells |
|---|---|---|
| 1 | **Home screen with credit balance + activities** | The headline: pixel-art credit economy. Show the balance ≥ 100, a few activities of each kind. |
| 2 | **SessionView with timer running** | Live tracking moment. Showcase the projection text + big pixel-art button. |
| 3 | **Repay flow** with debt warning | The unique mechanic — debt as a real consequence. |
| 4 | **Quests tab** with a few quests + a high payoff one (e.g. "Publish Dopamine Ledger") | Differentiator vs. plain time trackers. |
| 5 | **Empty state OR Settings + Credits screen** | Shows polish, attribution honesty, design pride. |

**Capture process** (run from the project root with the simulator booted):

```bash
# Boot + install latest build
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
UDID=$(xcrun simctl list devices booted | grep "iPhone 17 Pro Max" | awk '{print $NF}' | tr -d '()')
xcrun simctl io "$UDID" screenshot screenshots/01-home.png
# (manually arrange the app state via taps, then run again per screen)
```

Or just use **Cmd+S** in the simulator window to save a screenshot to
your Desktop, then upload to App Store Connect.

**Image specs**: PNG, 1290×2796 px (iPhone 17 Pro Max native), no
status bar overlays. App Store Connect will accept simulator screenshots
as-is.

- [ ] **[You]** Capture 3-5 screenshots and upload to App Store
  Connect → App Information → Localized Information → Screenshots.

### 3.4 App Store listing copy

Drafted copy in `APP_STORE_LISTING.md` (separate doc). Includes
description, subtitle, keywords, support URL placeholder, and
"What's New" for v1.0.

- [ ] **[You]** Paste from `APP_STORE_LISTING.md` into App Store Connect →
  App Information.

### 3.5 Privacy policy

Drafted text in `PRIVACY.md`. **Apple requires the privacy policy to be
hosted at a public URL** — you can't just paste the text into App Store
Connect.

Hosting options (easiest first):

| Option | Cost | Setup time |
|---|---|---|
| **GitHub Pages** | Free | 10 min — create a repo, drop the file, enable Pages |
| **Notion public page** | Free | 5 min — paste the text, publish as web page |
| **Your own domain** | Domain cost | 30 min if you already have hosting |
| **Termly / iubenda free tier** | Free | 15 min via wizard |

- [ ] **[You]** Host `PRIVACY.md` (rendered as HTML) at a public URL.
- [ ] **[You]** Paste that URL into App Store Connect → App Privacy →
  Privacy Policy URL.

### 3.6 Archive and upload

- [ ] **[You]** In Xcode:
  - Top menu: select **Any iOS Device (arm64)** as the destination (not a simulator)
  - **Product → Archive**
  - Wait for the archive to build (~1-2 min)
  - The Organizer window opens automatically
  - Click **Distribute App** → **App Store Connect** → **Upload**
  - Follow prompts. Xcode handles signing automatically.
  - Wait for the upload to complete (~3-5 min)
  - Apple processes the build for ~10-30 min

- [ ] **[You]** Once processed, go to App Store Connect →
  Your app → 1.0 Prepare for Submission → Build → select the uploaded build.

---

## Phase 4 — Submit for review

### 4.1 Final listing review

- [ ] **[You]** App Store Connect → 1.0 Prepare for Submission:
  - **Promotional text** (170 chars, optional, can edit anytime):
    *"A pixel-art credit economy for the time you spend on what
    matters."*
  - **Description**: paste from `APP_STORE_LISTING.md`
  - **Keywords**: paste from `APP_STORE_LISTING.md`
  - **Support URL**: a URL where users can reach you. Could be:
    - The Credits screen email (`mailto:cibercervela@pm.me`) — but
      Apple wants a web URL, not mailto
    - A GitHub repo page if you make one
    - A simple landing page
  - **Marketing URL** (optional): same or a different marketing page
  - **Copyright**: e.g. `© 2026 [Your Name]`
  - **Primary category**: **Productivity** (recommended)
  - **Secondary category**: **Health & Fitness** (optional)
  - **Content rating**: Click "Edit" → answer the questionnaire → expect **4+**
  - **App Review Information**:
    - Sign-in required: **No**
    - Contact info: your name, email, phone (Apple's eyes only)
    - Notes: leave blank or a brief "Solo personal-productivity app, no accounts, no network."
  - **Version Release**: choose "Manually release this version" (recommended for first release — you control the go-live moment)

### 4.2 Submit

- [ ] **[You]** Click **Add for Review** → **Submit for Review**.
- [ ] **[Apple]** Review takes **24-72 hours** typically.
- [ ] **[You]** Watch for the email — likely an "Approved" or sometimes
  a "Metadata Rejected" with a quick fix request.

### 4.3 After approval

- [ ] **[You]** Click **Release this version** in App Store Connect.
- [ ] **[You]** Within 1-2 hours the app appears on the App Store.

---

## Anticipated rejection risks (and how to mitigate)

Apple's most common rejection reasons for an app like ours:

| Risk | Likelihood | Mitigation |
|---|---|---|
| **Privacy policy URL missing/broken** | High if forgotten | Triple-check the URL loads before submission |
| **"App is too simple / lacks unique functionality"** | Low — our credit-debt mechanic is novel | Use the App Review notes to highlight the unique mechanic if asked |
| **Notification permission rationale weak** | Low — we ask just-in-time | If they push back, point them at the just-in-time prompt during a spender session |
| **Asset attribution missing** | Mitigated | Credits screen exists; license URLs work |
| **Bundle ID collision** | Possible | Use a unique reverse-domain in Phase 2.1 |
| **Default English region copy issues** | Low | Listing copy is plain English |

If rejected, Apple gives detailed feedback and you can resubmit
immediately after fixing — no extra wait queue.

---

## Decisions I need from you before this can move forward

1. **Apple Developer Program enrollment** — already done, in progress, or not started?
2. **Bundle ID** — keep `com.dopamine.ledger` or change to your reverse
   domain?
3. **Listing author / copyright name** — what name goes on the App Store?
4. **Support URL plan** — your own page, a GitHub repo, or a free
   landing-page service?
5. **Privacy policy hosting** — GitHub Pages, Notion, your own domain?

Tell me your answers and I'll fold them into the listing copy + tweak
the project files.