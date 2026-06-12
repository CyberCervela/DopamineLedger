// DataExporter.swift
// Pure export / import logic — no SwiftUI dependencies.
//
// FIELD SYNC RULE: if you add a field to Activity, Session, Quest, ActivityDebt,
// or Ledger, update the corresponding Export struct AND its init from the @Model
// in this file. The round-trip unit test in DopamineLedgerTests will catch the gap.

import Foundation
import SwiftData
import UniformTypeIdentifiers

// MARK: - Portable Codable structs
// String raw values for enums keep old backup files readable if enum cases
// change in future versions. Unknown raw values fall back to safe defaults on import.

struct ExportData: Codable {
    let version: Int        // schema version — 1 for this implementation
    let exportedAt: Date
    let balance: Double
    let activities: [ActivityExport]
    let sessions: [SessionExport]
    let quests: [QuestExport]
    let debts: [DebtExport]
}

struct ActivityExport: Codable {
    let id: UUID
    let name: String
    let kind: String            // ActivityKind raw value: "charger" / "spender"
    let ratePerSecond: Double
    let iconName: String
    let category: String?       // ActivityCategory raw value, or nil for pre-migration rows
    let isArchived: Bool
    let linkedAppScheme: String?
    let linkedAppName: String?
    let createdAt: Date
}

struct SessionExport: Codable {
    let id: UUID
    let activityId: UUID
    let startedAt: Date
    let endedAt: Date?
    let pausedAt: Date?
    let totalPausedSeconds: TimeInterval
    let timeMultiplier: Double
    let creditsMoved: Double
}

struct QuestExport: Codable {
    let id: UUID
    let name: String
    let payoffCredits: Double
    let iconName: String
    let category: String?           // ActivityCategory raw value
    let createdAt: Date
    let isCompleted: Bool
    let completedAt: Date?
    let isArchived: Bool
    let recurringCadence: String?   // RecurringCadence raw value, or nil for one-shot
    let availableAt: Date?
}

struct DebtExport: Codable {
    let id: UUID
    let activityId: UUID
    let amount: Double
    let originalAmount: Double
    let createdAt: Date
    let repaidAt: Date?
}

// MARK: - DataExporter

enum DataExporter {

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // Fetch all data, encode to JSON, write to a temp file, return the URL.
    // Returns nil only on encoding failure (should not happen with valid data).
    @MainActor
    static func exportToFile(context: ModelContext) -> URL? {
        let activities = (try? context.fetch(FetchDescriptor<Activity>())) ?? []
        let sessions   = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        let quests     = (try? context.fetch(FetchDescriptor<Quest>())) ?? []
        let debts      = (try? context.fetch(FetchDescriptor<ActivityDebt>())) ?? []
        let ledger     = Ledger.fetchOrCreate(in: context)

        let exportData = ExportData(
            version: 1,
            exportedAt: Date(),
            balance: ledger.balance,
            activities: activities.map(ActivityExport.init),
            sessions:   sessions.map(SessionExport.init),
            quests:     quests.map(QuestExport.init),
            debts:      debts.map(DebtExport.init)
        )

        guard let data = try? encoder.encode(exportData) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DopamineLedger-backup.json")
        try? data.write(to: url)
        return url
    }

    // Read and decode a backup file chosen via the document picker.
    // Handles the security-scoped resource lifecycle.
    static func decodeBackup(from url: URL) -> ExportData? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(ExportData.self, from: data)
    }

    // Read and decode the bundled seed file (DEBUG builds only).
    // Returns nil if the file is missing or malformed.
    static func decodeBundleSeed() -> ExportData? {
        guard let url = Bundle.main.url(forResource: "seed-data", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(ExportData.self, from: data)
    }

    // Wipe all current data and restore from the decoded backup.
    // Throws if the SwiftData delete or save fails.
    //
    // ATOMICITY: the wipe (5 bulk deletes) and the restore (inserts) are all
    // staged on the ModelContext and only persisted by the final save() below.
    // But a context is left *dirty* if anything throws partway through — and the
    // mainContext autosaves by default, so those pending deletes could later be
    // flushed on their own, persisting a wipe with no restore (the exact data-loss
    // a malformed import must never cause). We wrap the whole operation in a
    // do/catch and call context.rollback() on any throw: rollback discards every
    // unsaved change and resets the context to the last saved state, guaranteeing
    // the user's existing data is left untouched on failure. On success the single
    // save() commits the wipe+restore together, so a partial import is impossible.
    @MainActor
    static func applyImport(_ exportData: ExportData, context: ModelContext) throws {
        do {
            try applyImportBody(exportData, context: context)
        } catch {
            context.rollback()
            throw error
        }
    }

    // The actual wipe+restore. Kept private so the public applyImport above can
    // wrap every exit path with rollback-on-throw without duplicating logic.
    @MainActor
    private static func applyImportBody(_ exportData: ExportData, context: ModelContext) throws {
        // Wipe — same order as SettingsView.wipeAllData()
        try context.delete(model: Session.self)
        try context.delete(model: ActivityDebt.self)
        try context.delete(model: Quest.self)
        try context.delete(model: Activity.self)
        try context.delete(model: Ledger.self)

        // Restore activities
        for a in exportData.activities {
            let activity = Activity(
                name: a.name,
                kind: ActivityKind(rawValue: a.kind) ?? .spender,
                ratePerMinute: 1.0,     // placeholder; overridden below
                iconName: a.iconName,
                category: a.category.flatMap(ActivityCategory.init(rawValue:)) ?? .other
            )
            activity.id              = a.id
            activity.ratePerSecond   = a.ratePerSecond  // exact value, no round-trip loss
            activity.isArchived      = a.isArchived
            activity.linkedAppScheme = a.linkedAppScheme
            activity.linkedAppName   = a.linkedAppName
            activity.createdAt       = a.createdAt
            context.insert(activity)
        }

        // Restore sessions
        for s in exportData.sessions {
            let session = Session(activityId: s.activityId)
            session.id                  = s.id
            session.startedAt           = s.startedAt
            session.endedAt             = s.endedAt
            session.pausedAt            = s.pausedAt
            session.totalPausedSeconds  = s.totalPausedSeconds
            session.timeMultiplier      = s.timeMultiplier
            session.creditsMoved        = s.creditsMoved
            context.insert(session)
        }

        // Restore quests
        for q in exportData.quests {
            let cadence = q.recurringCadence.flatMap(RecurringCadence.init(rawValue:))
            let quest = Quest(
                name: q.name,
                payoffCredits: q.payoffCredits,
                iconName: q.iconName,
                category: q.category.flatMap(ActivityCategory.init(rawValue:)) ?? .other,
                recurringCadence: cadence
            )
            quest.id              = q.id
            quest.createdAt       = q.createdAt
            quest.isCompleted     = q.isCompleted
            quest.completedAt     = q.completedAt
            quest.isArchived      = q.isArchived
            quest.availableAt     = q.availableAt  // override Quest.init's computed value
            context.insert(quest)
        }

        // Restore debts
        for d in exportData.debts {
            let debt = ActivityDebt(activityId: d.activityId, amount: d.amount)
            debt.id             = d.id
            debt.originalAmount = d.originalAmount
            debt.createdAt      = d.createdAt
            debt.repaidAt       = d.repaidAt
            context.insert(debt)
        }

        // Restore ledger balance
        let ledger = Ledger(balance: exportData.balance)
        context.insert(ledger)

        try context.save()
    }
}

// MARK: - Export struct initialisers (one per @Model class)
// These live here — not in the model files — so the exporter is self-contained.
// When you add a field to an @Model, update BOTH the struct above AND the init below.

private extension ActivityExport {
    init(_ a: Activity) {
        id              = a.id
        name            = a.name
        kind            = a.kind.rawValue
        ratePerSecond   = a.ratePerSecond
        iconName        = a.iconName
        category        = a.category?.rawValue
        isArchived      = a.isArchived
        linkedAppScheme = a.linkedAppScheme
        linkedAppName   = a.linkedAppName
        createdAt       = a.createdAt
    }
}

private extension SessionExport {
    init(_ s: Session) {
        id                  = s.id
        activityId          = s.activityId
        startedAt           = s.startedAt
        endedAt             = s.endedAt
        pausedAt            = s.pausedAt
        totalPausedSeconds  = s.totalPausedSeconds
        timeMultiplier      = s.timeMultiplier
        creditsMoved        = s.creditsMoved
    }
}

private extension QuestExport {
    init(_ q: Quest) {
        id               = q.id
        name             = q.name
        payoffCredits    = q.payoffCredits
        iconName         = q.iconName
        category         = q.category?.rawValue
        createdAt        = q.createdAt
        isCompleted      = q.isCompleted
        completedAt      = q.completedAt
        isArchived       = q.isArchived
        recurringCadence = q.recurringCadence?.rawValue
        availableAt      = q.availableAt
    }
}

private extension DebtExport {
    init(_ d: ActivityDebt) {
        id             = d.id
        activityId     = d.activityId
        amount         = d.amount
        originalAmount = d.originalAmount
        createdAt      = d.createdAt
        repaidAt       = d.repaidAt
    }
}
