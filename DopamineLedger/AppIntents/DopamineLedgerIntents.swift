// DopamineLedgerIntents.swift
// Exposes five actions to Siri, Shortcuts, Spotlight, and the Action Button.
//
// Why @MainActor on every perform():
//   LiveActivityService, Ledger.fetchOrCreate, and SessionFinalizer.finalize
//   are all @MainActor-isolated. Rather than sprinkling MainActor.run{} blocks,
//   we mark perform() @MainActor throughout. App Intents honours this — the
//   intent runs on the main actor whether launched by Siri, Shortcuts, or a
//   Focus automation.
//
// Why a fresh ModelContainer per intent:
//   Intents can execute outside the SwiftUI lifecycle (Siri from lock screen,
//   app not foregrounded). There's no @Environment(\.modelContext) here.
//   ModelContainer(for:) opens the same on-disk SQLite store the main app uses;
//   SwiftData's WAL handles concurrent access safely.

import AppIntents
import SwiftData
import Foundation

// MARK: - Shared container factory

private func makeDLContainer() throws -> ModelContainer {
    try ModelContainer(for: Activity.self, Session.self, ActivityDebt.self, Ledger.self, Quest.self)
}

// MARK: - ActivityAppEntity

// Bridges Activity into App Intents so Siri can resolve a spoken name
// ("Reading") to the user's actual Activity row. If the spoken name
// matches multiple activities, Siri shows a disambiguation picker.
struct ActivityAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Activity"
    static var defaultQuery = ActivityAppEntityQuery()

    var id:   UUID
    var name: String
    var kind: ActivityKind

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(from activity: Activity) {
        self.id   = activity.id
        self.name = activity.name
        self.kind = activity.kind
    }
}

// MARK: - ActivityAppEntityQuery

struct ActivityAppEntityQuery: EntityStringQuery {

    // Resolves a specific set of activity IDs (used by Shortcuts automation).
    func entities(for identifiers: [UUID]) async throws -> [ActivityAppEntity] {
        let context = ModelContext(try makeDLContainer())
        return try identifiers.compactMap { id in
            let descriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == id })
            return try context.fetch(descriptor).first.map { ActivityAppEntity(from: $0) }
        }
    }

    // Case-insensitive substring match — "read" finds "Reading".
    func entities(matching string: String) async throws -> [ActivityAppEntity] {
        let context = ModelContext(try makeDLContainer())
        let descriptor = FetchDescriptor<Activity>(sortBy: [SortDescriptor(\.createdAt)])
        let all = try context.fetch(descriptor)
        let query = string.lowercased()
        return all.filter { $0.name.lowercased().contains(query) }.map { ActivityAppEntity(from: $0) }
    }

    // Populates the Shortcuts activity picker and Siri disambiguation list.
    func suggestedEntities() async throws -> [ActivityAppEntity] {
        let context = ModelContext(try makeDLContainer())
        let descriptor = FetchDescriptor<Activity>(sortBy: [SortDescriptor(\.createdAt)])
        return try context.fetch(descriptor).map { ActivityAppEntity(from: $0) }
    }
}

// MARK: - StartSessionIntent

struct StartSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Session"
    static var description = IntentDescription("Start timing an activity in Dopamine Ledger")

    @Parameter(title: "Activity") var activity: ActivityAppEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try makeDLContainer()
        let context   = ModelContext(container)

        // One session at a time — same rule as the in-app flow.
        let activeDescriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.endedAt == nil })
        guard (try context.fetch(activeDescriptor)).isEmpty else {
            return .result(dialog: "A session is already running. Stop it first.")
        }

        // SwiftData #Predicate gotcha: extract id to a local before the closure.
        let activityId = activity.id
        let actDescriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == activityId })
        guard let fullActivity = try context.fetch(actDescriptor).first else {
            return .result(dialog: "Activity not found.")
        }

        // Spender: respect debt and balance rules. Chill mode bypasses both —
        // same behaviour as the ActivityMenuView flow in the app.
        if fullActivity.kind == .spender, !UserDefaults.standard.bool(forKey: "chillMode") {
            let debtActivityId = fullActivity.id
            let debtDescriptor = FetchDescriptor<ActivityDebt>(
                predicate: #Predicate { $0.activityId == debtActivityId && $0.amount > 0 }
            )
            if !(try context.fetch(debtDescriptor)).isEmpty {
                return .result(dialog: "You have debt on \(fullActivity.name). Open Dopamine Ledger to resolve it first.")
            }
            if Ledger.fetchOrCreate(in: context).balance <= 0 {
                return .result(dialog: "Your balance is zero. Earn some credits before spending.")
            }
        }

        let session = Session(activityId: fullActivity.id)
        context.insert(session)
        try context.save()

        LiveActivityService.start(
            activityName:  fullActivity.name,
            activityKind:  fullActivity.kind,
            ratePerSecond: fullActivity.ratePerSecond,
            startedAt:     session.startedAt
        )

        if fullActivity.kind == .spender {
            let balance = Ledger.fetchOrCreate(in: context).balance
            await NotificationScheduler.scheduleSpenderSession(
                sessionId:     session.id,
                activityName:  fullActivity.name,
                balance:       balance,
                ratePerSecond: fullActivity.ratePerSecond
            )
        }

        return .result(dialog: "Started \(fullActivity.name).")
    }
}

// MARK: - StopSessionIntent

struct StopSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Session"
    static var description = IntentDescription("Stop the active session in Dopamine Ledger")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try makeDLContainer()
        let context   = ModelContext(container)

        let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.endedAt == nil })
        guard let session = try context.fetch(descriptor).first else {
            return .result(dialog: "No active session to stop.")
        }

        // SessionFinalizer handles all the math: stamp endedAt, apply credits,
        // update ledger, insert debt row if overrun, end the Live Activity.
        SessionFinalizer.finalize(session: session, in: context)
        try context.save()

        return .result(dialog: "Session stopped.")
    }
}

// MARK: - PauseSessionIntent

struct PauseSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Session"
    static var description = IntentDescription("Pause the active session in Dopamine Ledger")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try makeDLContainer()
        let context   = ModelContext(container)

        let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.endedAt == nil })
        guard let session = try context.fetch(descriptor).first else {
            return .result(dialog: "No active session to pause.")
        }
        guard !session.isPaused else {
            return .result(dialog: "Session is already paused.")
        }

        session.pause()

        // Fetch activity rate to push a creditsMoved value to the Live Activity.
        let sessionActivityId = session.activityId
        let actDescriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == sessionActivityId })
        let rate = (try? context.fetch(actDescriptor).first?.ratePerSecond) ?? 0

        LiveActivityService.update(
            adjustedStart: session.startedAt.addingTimeInterval(session.totalPausedSeconds),
            isPaused:      true,
            pausedElapsed: session.elapsed,
            creditsMoved:  rate * session.elapsed
        )
        try context.save()

        return .result(dialog: "Session paused.")
    }
}

// MARK: - ResumeSessionIntent

struct ResumeSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Session"
    static var description = IntentDescription("Resume the paused session in Dopamine Ledger")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try makeDLContainer()
        let context   = ModelContext(container)

        let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.endedAt == nil })
        guard let session = try context.fetch(descriptor).first else {
            return .result(dialog: "No active session to resume.")
        }
        guard session.isPaused else {
            return .result(dialog: "Session is not paused.")
        }

        session.resume()

        let sessionActivityId = session.activityId
        let actDescriptor = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == sessionActivityId })
        let rate = (try? context.fetch(actDescriptor).first?.ratePerSecond) ?? 0

        // After resume(), totalPausedSeconds has grown; adjustedStart shifts
        // forward so the Live Activity timer shows correct elapsed time.
        LiveActivityService.update(
            adjustedStart: session.startedAt.addingTimeInterval(session.totalPausedSeconds),
            isPaused:      false,
            pausedElapsed: 0,
            creditsMoved:  rate * session.elapsed
        )
        try context.save()

        return .result(dialog: "Session resumed.")
    }
}

// MARK: - CheckBalanceIntent

struct CheckBalanceIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Balance"
    static var description = IntentDescription("Check your current credit balance in Dopamine Ledger")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try makeDLContainer()
        let context   = ModelContext(container)

        let balance   = Ledger.fetchOrCreate(in: context).balance
        let formatted = balance.formatted(.number.precision(.fractionLength(0...1)))
        return .result(dialog: "Your Dopamine Ledger balance is \(formatted) credits.")
    }
}

// MARK: - App Shortcuts provider

// Registers all phrases with Siri at install time — no user setup needed.
// The \(\.$activity) interpolation tells Siri this slot is filled by speaking
// an activity name; it resolves via ActivityAppEntityQuery.
struct DopamineLedgerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartSessionIntent(),
            phrases: [
                "Start \(\.$activity) in \(.applicationName)",
                "Begin \(\.$activity) in \(.applicationName)"
            ],
            shortTitle: "Start Session",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: StopSessionIntent(),
            phrases: [
                "Stop \(.applicationName)",
                "End \(.applicationName) session"
            ],
            shortTitle: "Stop Session",
            systemImageName: "stop.fill"
        )
        AppShortcut(
            intent: PauseSessionIntent(),
            phrases: [
                "Pause \(.applicationName)"
            ],
            shortTitle: "Pause Session",
            systemImageName: "pause.fill"
        )
        AppShortcut(
            intent: ResumeSessionIntent(),
            phrases: [
                "Resume \(.applicationName)"
            ],
            shortTitle: "Resume Session",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: CheckBalanceIntent(),
            phrases: [
                "What's my \(.applicationName) balance",
                "Check my \(.applicationName) balance"
            ],
            shortTitle: "Check Balance",
            systemImageName: "scalemass.fill"
        )
    }
}
