// DebugSeeder.swift
// Populates the store with realistic mock data on first launch when it is empty.
// Only compiled in DEBUG builds — this file is never included in a release or
// App Store archive (DEBUG is not set for the Release configuration).
//
// Trigger: ContentView calls seedIfNeeded(in:) on appear. The guard at the top
// makes it a no-op on every launch after the first insert, so live test data you
// add by hand in the simulator is never clobbered.

#if DEBUG

import Foundation
import SwiftData

enum DebugSeeder {

    // Entry point. Call from a SwiftUI .task on a view that already has the
    // model container in its environment — ModelContext is main-actor-bound.
    static func seedIfNeeded(in context: ModelContext) {
        // Any existing activities mean the store has been used before — bail out.
        let existing = (try? context.fetch(FetchDescriptor<Activity>())) ?? []
        guard existing.isEmpty else { return }
        seedCore(in: context)
    }

    // Force-wipe + reseed — used by Settings → Load Test Data in DEBUG builds.
    // Unlike seedIfNeeded, this always runs regardless of existing data.
    @MainActor
    static func forceSeed(in context: ModelContext) throws {
        try context.delete(model: Session.self)
        try context.delete(model: ActivityDebt.self)
        try context.delete(model: Quest.self)
        try context.delete(model: Activity.self)
        try context.delete(model: Ledger.self)
        try context.save()
        seedCore(in: context)
    }

    private static func seedCore(in context: ModelContext) {

        let now = Date()

        // MARK: Activities

        let exercise   = Activity(name: "Exercise",      kind: .charger, ratePerMinute: 10, iconName: "figure.run")
        let reading    = Activity(name: "Reading",       kind: .charger, ratePerMinute: 6,  iconName: "book.fill")
        let doomscroll = Activity(name: "Doomscrolling", kind: .spender, ratePerMinute: 8,  iconName: "phone.fill")
        let tv         = Activity(name: "TV Series",     kind: .spender, ratePerMinute: 5,  iconName: "tv.fill")
        [exercise, reading, doomscroll, tv].forEach { context.insert($0) }

        // MARK: Sessions
        //
        // Three time layers so all three Dashboard scope filters show different
        // numbers:
        //   • Today (within startOfDay)
        //   • This week (≤7 days ago, outside today)
        //   • All time only (>7 days ago)

        // Today
        makeSession(activity: exercise,   startOffset: -2 * 3600,          duration: 30 * 60, now: now, in: context)  // +300 cr
        makeSession(activity: doomscroll, startOffset: -1 * 3600,          duration: 20 * 60, now: now, in: context)  // −160 cr

        // This week — 3 days ago
        makeSession(activity: reading,    startOffset: -3 * 86400 - 3600,  duration: 40 * 60, now: now, in: context)  // +240 cr
        makeSession(activity: tv,         startOffset: -3 * 86400 - 7200,  duration: 60 * 60, now: now, in: context)  // −300 cr

        // All time — 10 days ago (outside "this week" on any locale)
        makeSession(activity: exercise,   startOffset: -10 * 86400 - 3600, duration: 60 * 60, now: now, in: context)  // +600 cr
        makeSession(activity: doomscroll, startOffset: -10 * 86400 - 7200, duration: 45 * 60, now: now, in: context)  // −360 cr

        // MARK: Quests

        let taxes    = Quest(name: "File tax return",  payoffCredits: 500, iconName: "doc.fill")
        taxes.isCompleted = true
        taxes.completedAt = now.addingTimeInterval(-1 * 3600)     // 1 hour ago — today

        let callMom  = Quest(name: "Call mom",         payoffCredits: 50,  iconName: "phone.fill")
        callMom.isCompleted = true
        callMom.completedAt = now.addingTimeInterval(-4 * 86400)  // 4 days ago — this week

        let desk     = Quest(name: "Reorganize desk",  payoffCredits: 100, iconName: "house.fill")
        desk.isCompleted = true
        desk.completedAt = now.addingTimeInterval(-12 * 86400)    // 12 days ago — all time only

        let learnSwift = Quest(name: "Learn SwiftUI",  payoffCredits: 200, iconName: "laptopcomputer")
        // pending — isCompleted stays false, completedAt stays nil

        [taxes, callMom, desk, learnSwift].forEach { context.insert($0) }

        // MARK: Debts

        // TV Series — 80 cr still outstanding
        let tvDebt = ActivityDebt(activityId: tv.id, amount: 80)
        // originalAmount = 80 already set in ActivityDebt.init; amount stays 80
        context.insert(tvDebt)

        // Doomscrolling — 40 cr, fully repaid 2 days ago
        let doomDebt = ActivityDebt(activityId: doomscroll.id, amount: 40)
        doomDebt.amount   = 0
        doomDebt.repaidAt = now.addingTimeInterval(-2 * 86400)
        context.insert(doomDebt)

        // MARK: Ledger

        // Set balance directly — represents a plausible running total
        // given the session and quest history above.
        context.insert(Ledger(balance: 420))
    } // end seedCore

    // Creates one closed session with an absolute startedAt derived from `now`.
    private static func makeSession(
        activity:    Activity,
        startOffset: TimeInterval,
        duration:    TimeInterval,
        now:         Date,
        in context:  ModelContext
    ) {
        let s = Session(activityId: activity.id)
        s.startedAt = now.addingTimeInterval(startOffset)
        s.endedAt   = s.startedAt.addingTimeInterval(duration)
        context.insert(s)
    }
}

#endif
