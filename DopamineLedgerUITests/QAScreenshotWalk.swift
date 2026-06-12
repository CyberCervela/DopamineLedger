// QAScreenshotWalk.swift
// Resubmission-QA screenshot harness. NOT part of the shipping app — this is a
// ui-testing bundle that drives the Debug build through every reviewer-visible
// screen and saves a PNG per screen, named per the QA matrix convention:
//   <screen>-<device>-<theme>-<scheme>.png
//
// Why a UI test and not a shell script: simctl has no tap injection, and
// AppleScript clicking needs assistive-access permissions and is coordinate-
// fragile. XCUITest taps by accessibility label, waits for elements properly,
// and runs identically on every simulator device.
//
// Configuration comes from the environment (forwarded by xcodebuild via
// TEST_RUNNER_*):
//   DL_QA_DIR    — host directory for PNGs (simulator processes share the host FS)
//   DL_QA_DEVICE — device tag for filenames ("17promax", "se3", ...)
//   DL_QA_THEME  — theme tag ("neu" / "system")
//   DL_QA_SCHEME — scheme tag ("light" / "dark" / "light-fr", ...)
// Theme / language / appearance are set EXTERNALLY (defaults write + simctl ui)
// before the run; the harness just photographs whatever is configured.

import XCTest

final class QAScreenshotWalk: XCTestCase {

    var app: XCUIApplication!
    var dir = "/tmp/dl-qa"
    var tag = "device-neu-light"

    // Localized tap labels for the FR/DE spot passes (QA-26). The harness taps
    // by visible label, so non-EN walks need the catalog's translations for the
    // dozen labels the walk touches. Values mirror Localizable.xcstrings.
    private static let labels: [String: [String: String]] = [
        "fr": ["All": "Tout", "Chargers": "Chargeurs", "Spenders": "Dépenseurs",
               "Quests": "Quêtes", "Home": "Accueil", "Stats": "Stats",
               "History": "Historique", "This Week": "Cette semaine", "All Time": "Tout",
               "Settings": "Paramètres", "Privacy Policy": "Politique de confidentialité",
               "Add Activity": "Ajouter une activité",
               "Choose from Template": "Choisir un modèle",
               "Create Your Own": "Créer votre propre", "Templates": "Modèles",
               "New Activity": "Nouvelle activité", "Cancel": "Annuler",
               "Save": "Enregistrer", "Done": "Terminé",
               "Start session": "Démarrer la session",
               "Start session anyway": "Commencer quand même",
               "Stop": "Stop", "Pause": "Pause", "Resume": "Reprendre",
               "Debt": "Dettes"],
        "de": ["All": "Alle", "Chargers": "Lader", "Spenders": "Ausgeber",
               "Quests": "Quests", "Home": "Start", "Stats": "Statistiken",
               "History": "Chronik", "This Week": "Diese Woche", "All Time": "Gesamt",
               "Settings": "Einstellungen", "Privacy Policy": "Datenschutzrichtlinie",
               "Add Activity": "Aktivität hinzufügen",
               "Choose from Template": "Vorlage auswählen",
               "Create Your Own": "Eigene erstellen", "Templates": "Vorlagen",
               "New Activity": "Neue Aktivität", "Cancel": "Abbrechen",
               "Save": "Speichern", "Done": "Fertig",
               "Start session": "Sitzung starten",
               "Start session anyway": "Trotzdem starten",
               "Stop": "Stopp", "Pause": "Pause", "Resume": "Fortsetzen",
               "Debt": "Schulden"],
    ]
    private var lang = "en"
    // Resolves an English label to the active walk language.
    private func L(_ en: String) -> String {
        Self.labels[lang]?[en] ?? en
    }

    override func setUpWithError() throws {
        continueAfterFailure = true   // a missed element should not abort the whole walk
        let env = ProcessInfo.processInfo.environment
        dir = env["DL_QA_DIR"] ?? dir
        let device = env["DL_QA_DEVICE"] ?? "device"
        let theme  = env["DL_QA_THEME"]  ?? "neu"
        let scheme = env["DL_QA_SCHEME"] ?? "light"
        lang = env["DL_QA_LANG"] ?? "en"
        tag = "\(device)-\(theme)-\(scheme)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        // The notification-permission alert fires on the first spender session
        // start. Answer it deterministically so screenshots stay clean: Allow by
        // default; Don't Allow when the run is the QA-34 denied-state pass.
        let deny = env["DL_QA_DENY_NOTIF"] == "1"
        addUIInterruptionMonitor(withDescription: "notification permission") { alert in
            let button = alert.buttons[deny ? "Don't Allow" : "Allow"]
            if button.exists { button.tap(); return true }
            return false
        }
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Helpers

    private func shoot(_ screen: String) {
        // Small settle delay so transitions/animations finish before capture.
        usleep(600_000)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let url = URL(fileURLWithPath: "\(dir)/\(screen)-\(tag).png")
        try? png.write(to: url)
    }

    @discardableResult
    private func tap(_ element: XCUIElement, _ what: String, timeout: TimeInterval = 5) -> Bool {
        guard element.waitForExistence(timeout: timeout) else {
            XCTFail("missing: \(what)"); return false
        }
        element.tap()
        return true
    }

    // Taps at an absolute point in window coordinates — used for the two
    // icon-only header buttons (gear / +) that have no text label. Anchored to
    // the home title's frame so it adapts to every device's safe-area inset.
    private func tapAtPoint(_ p: CGPoint) {
        let base = app.coordinate(withNormalizedOffset: .zero)
        base.withOffset(CGVector(dx: p.x, dy: p.y)).tap()
    }

    private var homeTitle: XCUIElement { app.staticTexts["Dopamine Ledger"] }

    // "Done" is ambiguous: quest rows on the home screen have a Done button, and
    // stacked sheets each have a Done pill. The sheet's pill is the LAST match in
    // the accessibility hierarchy, so tap the last hittable one.
    private func tapSheetDone() {
        let all = app.buttons.matching(identifier: L("Done")).allElementsBoundByIndex
        if let last = all.last(where: { $0.isHittable }) { last.tap() }
        else { XCTFail("no hittable Done pill") }
        usleep(400_000)
    }

    private func openSettings() {
        _ = homeTitle.waitForExistence(timeout: 5)
        tapAtPoint(CGPoint(x: 30, y: homeTitle.frame.midY))   // gear is leading-aligned
    }

    private func openAddSheet() {
        _ = homeTitle.waitForExistence(timeout: 5)
        let w = app.frame.width
        tapAtPoint(CGPoint(x: w - 30, y: homeTitle.frame.midY)) // + is trailing-aligned
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()
        // Select-all then type replaces reliably regardless of cursor position.
        field.doubleTap()
        app.menuItems["Select All"].exists ? app.menuItems["Select All"].tap() : ()
        field.typeText(text)
    }


    // Taps the last HITTABLE button with this (localized) label. Needed because
    // ContentView keeps all three tabs mounted in a ZStack at opacity 0, so a
    // hidden screen's buttons still exist in the accessibility tree — and some
    // labels collide across screens in other languages (FR: filter "Tout" vs
    // scope "Tout" for All Time). A bare query with 2+ matches crashes the test.
    private func tapButton(_ en: String, _ what: String) {
        let label = L(en)
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            let hittable = app.buttons.matching(identifier: label)
                .allElementsBoundByIndex.filter { $0.isHittable }
            if let target = hittable.last { target.tap(); usleep(300_000); return }
            usleep(300_000)
        }
        XCTFail("missing/unhittable: \(what)")
    }

    // MARK: - The walk

    func test01CoreScreens() {
        // ---- Home: all four filter tabs (seeded data) ----
        _ = homeTitle.waitForExistence(timeout: 10)
        shoot("home-all")
        tapButton("Chargers", "Chargers tab");  shoot("home-chargers")
        tapButton("Spenders", "Spenders tab");  shoot("home-spenders")
        tapButton("Quests", "Quests tab");    shoot("home-quests")
        tapButton("All", "All tab")

        // ---- Stats: three scopes ----
        tapButton("Stats", "Stats tab"); shoot("stats-today")
        tapButton("This Week", "This Week scope"); shoot("stats-week")
        tapButton("All Time", "All Time scope");  shoot("stats-alltime")

        // ---- History ----
        tapButton("History", "History tab"); shoot("history")
        tapButton("Home", "Home tab")

        // ---- Settings + Privacy ----
        openSettings()
        if app.staticTexts[L("Settings")].waitForExistence(timeout: 4) {
            shoot("settings-top")
            app.swipeUp(); app.swipeUp()
            shoot("settings-bottom")
            if app.staticTexts[L("Privacy Policy")].firstMatch.exists {
                app.staticTexts[L("Privacy Policy")].firstMatch.tap()
                shoot("privacy")
                tapSheetDone()   // privacy sheet
            }
            tapSheetDone()       // settings sheet
        }

        // ---- Add flow: choice sheet, template gallery, create-own + cap hint ----
        openAddSheet()
        if app.staticTexts[L("Add Activity")].waitForExistence(timeout: 4) {
            shoot("addchoice")
            tap(app.staticTexts[L("Choose from Template")].firstMatch, "template path")
            if app.staticTexts[L("Templates")].waitForExistence(timeout: 4) {
                shoot("templates")
                tap(app.staticTexts["Deep Work"].firstMatch, "Deep Work template")
                shoot("addactivity-template")
                // Cancel pops the pushed form back to the gallery (it does NOT
                // close the sheet), so cancel the gallery as well.
                tap(app.buttons[L("Cancel")].firstMatch, "cancel template form")
                if app.staticTexts[L("Templates")].waitForExistence(timeout: 3) {
                    tap(app.buttons[L("Cancel")].firstMatch, "cancel gallery")
                }
            }
        }
        usleep(800_000)   // let the sheet dismissal settle before re-opening
        // Re-open: create your own (cancel above may have closed the whole sheet)
        if !app.staticTexts[L("Add Activity")].exists { openAddSheet() }
        if app.staticTexts[L("Add Activity")].waitForExistence(timeout: 4) {
            tap(app.staticTexts[L("Create Your Own")].firstMatch, "create-own path")
            if app.staticTexts[L("New Activity")].waitForExistence(timeout: 4) {
                let name = app.textFields.element(boundBy: 0)
                tap(name, "name field"); name.typeText("QA Charger")
                // Over-cap rate → red max hint + disabled Save (F-09)
                let rate = app.textFields.element(boundBy: 1)
                replaceText(in: rate, with: "100")
                app.swipeUp()   // bring the rate field + hint into view
                shoot("addactivity-overcap")
                replaceText(in: rate, with: "12")
                shoot("addactivity-create")
                tap(app.buttons[L("Save")].firstMatch, "save activity")
            }
        }

        // ---- Charger session: confirm sheet → running → ACTIVE pin → stop ----
        if app.staticTexts["QA Charger"].waitForExistence(timeout: 5) {
            app.staticTexts["QA Charger"].firstMatch.tap()
            if app.buttons[L("Start session")].waitForExistence(timeout: 4) {
                shoot("activitymenu-charger")
                app.buttons[L("Start session")].firstMatch.tap()
                _ = app.buttons[L("Stop")].waitForExistence(timeout: 4)
                shoot("session-charger")
                if app.buttons[L("Pause")].exists {
                    app.buttons[L("Pause")].tap(); shoot("session-paused")
                    if app.buttons[L("Resume")].exists { app.buttons[L("Resume")].tap() }
                }
                // Swipe the sheet down — session survives; home should show the
                // pinned row with the localized ACTIVE badge (DL-12 + F-04).
                app.swipeDown(velocity: .fast)
                shoot("home-active-pinned")
                // Reopen and stop.
                if app.staticTexts["QA Charger"].firstMatch.waitForExistence(timeout: 4) {
                    app.staticTexts["QA Charger"].firstMatch.tap()
                    if app.buttons[L("Stop")].waitForExistence(timeout: 4) { app.buttons[L("Stop")].tap() }
                }
            }
        }

        // ---- Spender session (seeded "Doomscrolling") ----
        if app.staticTexts["Doomscrolling"].firstMatch.waitForExistence(timeout: 5) {
            app.staticTexts["Doomscrolling"].firstMatch.tap()
            // Cleared state shows "Start session"; debt state shows "Start session anyway"
            let start = app.buttons[L("Start session")].exists
                ? app.buttons[L("Start session")]
                : app.buttons[L("Start session anyway")]
            if start.waitForExistence(timeout: 4) {
                shoot("activitymenu-spender")
                start.firstMatch.tap()
                _ = app.buttons[L("Stop")].waitForExistence(timeout: 4)
                shoot("session-spender")
                if app.buttons[L("Stop")].exists { app.buttons[L("Stop")].tap() }
            } else {
                // Menu without a start button (unexpected state): swipe it away.
                app.swipeDown(velocity: .fast)
            }
        }

        // ---- Debt sheet via balance card tap-through ----
        let debtRow = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'debt'")).firstMatch
        if debtRow.exists {
            debtRow.tap()
            if app.staticTexts[L("Debt")].waitForExistence(timeout: 4) {
                shoot("debt")
                tapSheetDone()   // debt sheet
            }
        }
    }

    // Focused add-activity capture for the FR/DE spot passes (QA-26): the full
    // walk's add-flow can be skipped if an earlier sheet misbehaves, so this
    // runs the editor path in isolation from a fresh launch. Captures the
    // choice sheet, the editor, and the over-cap hint (new ×7 string from F-09).
    func test03AddActivitySpot() throws {
        guard ProcessInfo.processInfo.environment["DL_QA_ADDSPOT"] == "1" else {
            throw XCTSkip("add-activity spot pass not requested")
        }
        _ = homeTitle.waitForExistence(timeout: 10)
        openAddSheet()
        if app.staticTexts[L("Add Activity")].waitForExistence(timeout: 4) {
            shoot("addchoice")
            tap(app.staticTexts[L("Create Your Own")].firstMatch, "create-own path")
            if app.staticTexts[L("New Activity")].waitForExistence(timeout: 4) {
                shoot("addactivity-create")
                let rate = app.textFields.element(boundBy: 1)
                replaceText(in: rate, with: "100")
                app.swipeUp()
                shoot("addactivity-overcap")
            }
        }
    }

    // Wipes all data via the Danger Zone to capture the first-launch empty state.
    // Run LAST and only when DL_QA_EMPTY=1 (destructive; the DEBUG seeder
    // repopulates on next launch because the store is empty again).
    func test02EmptyStates() throws {
        guard ProcessInfo.processInfo.environment["DL_QA_EMPTY"] == "1" else {
            throw XCTSkip("empty-state pass not requested")
        }
        _ = homeTitle.waitForExistence(timeout: 10)
        openSettings()
        guard app.staticTexts[L("Settings")].waitForExistence(timeout: 4) else { return }
        app.swipeUp(); app.swipeUp()
        tap(app.staticTexts["Wipe all data"].firstMatch, "wipe row")
        // System alert confirmation.
        let confirm = app.alerts.buttons["Wipe everything"]
        if confirm.waitForExistence(timeout: 4) { confirm.tap() }
        _ = homeTitle.waitForExistence(timeout: 5)
        shoot("home-empty")
        tap(app.buttons[L("Stats")].firstMatch, "Stats tab");   shoot("stats-empty")
        tap(app.buttons[L("History")].firstMatch, "History tab"); shoot("history-empty")
    }
}
