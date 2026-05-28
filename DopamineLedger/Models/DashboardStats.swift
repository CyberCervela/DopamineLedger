// DashboardStats.swift
// Pure-function aggregate over Sessions, Quests, Activities, and ActivityDebts
// for a given time scope. No @Model, no SwiftUI — feed in arrays, get structs
// back. Same shape as SessionMath / RepayMath: numbers in, numbers out.

import Foundation

// The time window the user selects on the Dashboard.
// Raw values are localisation keys — resolved to display strings by the view layer.
enum DashboardScope: String, CaseIterable, Identifiable {
    case today    = "scope.today"
    case thisWeek = "scope.this_week"
    case allTime  = "scope.all_time"

    var id: String { rawValue }

    // The earliest Date that falls within this scope relative to `now`.
    // Returns nil for .allTime — no lower bound, all records qualify.
    func startDate(now: Date = .init(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .thisWeek:
            // Anchors to the locale's first weekday (Monday in most of Europe,
            // Sunday in the US) so the app respects the device region.
            return calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            )
        case .allTime:
            return nil
        }
    }
}

// Rolled-up numbers for one activity within the selected scope.
struct ActivitySummary: Identifiable {
    let id:           UUID          // matches Activity.id
    let name:         String
    let kind:         ActivityKind
    let category:     ActivityCategory
    let iconName:     String
    let sessionCount: Int
    let totalElapsed: TimeInterval  // working seconds across closed sessions in scope
    let totalCredits: Double        // earned (charger) or spent at base rate (spender)
}

// One completed quest that falls within the selected scope.
struct CompletedQuestEntry: Identifiable {
    let id:            UUID
    let name:          String
    let category:      ActivityCategory
    let payoffCredits: Double
    let completedAt:   Date
}

// All activity and quest data for one life-area category, pre-split by kind.
// The dashboard renders quests first, then chargers, then spenders within each group.
// Empty groups are excluded from the categoryGroups array.
struct CategoryGroup: Identifiable {
    let category: ActivityCategory
    let quests:   [CompletedQuestEntry]
    let chargers: [ActivitySummary]
    let spenders: [ActivitySummary]
    var id: ActivityCategory { category }
}

// The full set of stats for one scope window.
struct DashboardStats {

    // Credits added to the balance by charger sessions in scope.
    let creditsEarned: Double

    // Credits consumed by spender sessions (base rate × elapsed) in scope.
    // For sessions that overran the balance this overstates the actual draw-down
    // from the balance — the overrun became debt, not a direct deduction.
    // Accurate for within-balance sessions. See BACKLOG.md for the planned fix
    // (store balanceAtSessionStart on Session to replay exact SessionMath).
    let creditsSpent: Double

    // Sum of payoffs from quests completed within scope.
    let questPayoff: Double

    // Credits drained from the balance by debt rows fully cleared in scope.
    // Sourced from ActivityDebt.originalAmount filtered by ActivityDebt.repaidAt.
    // Partial repayments are attributed to the session in which the row reached 0.
    let debtRepaid: Double

    // earned + questPayoff − spent − debtRepaid.
    // Directionally correct; see creditsSpent caveat above for the known overrun edge case.
    let netDelta: Double

    // Sum of all currently unrepaid debt — not scoped, always current state.
    // Shown in the UI regardless of selected scope so the user always sees
    // how much they still owe.
    let totalOutstandingDebt: Double

    // Activities and completed quests grouped by life-area category.
    // Order follows ActivityCategory.allCases; empty categories are omitted.
    // Within each group: quests (newest first), chargers (alpha), spenders (alpha).
    let categoryGroups: [CategoryGroup]

    static let empty = DashboardStats(
        creditsEarned: 0, creditsSpent: 0, questPayoff: 0,
        debtRepaid: 0, netDelta: 0, totalOutstandingDebt: 0,
        categoryGroups: []
    )

    // Main entry point. Accepts plain arrays so it is callable from
    // @Query results in a view or directly from unit tests without a ModelContainer.
    static func compute(
        sessions:   [Session],
        quests:     [Quest],
        activities: [Activity],
        debts:      [ActivityDebt],
        scope:      DashboardScope,
        now:        Date     = .init(),
        calendar:   Calendar = .current
    ) -> DashboardStats {

        let startDate = scope.startDate(now: now, calendar: calendar)

        // Build a UUID→Activity map for O(1) joins in the session loop.
        let activityMap = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })

        // Only closed sessions within scope.
        // Active sessions are in-flight — their credits appear in the ledger only
        // after the user taps Stop, so including them would cause the stats to
        // fluctuate every second and disagree with the balance card.
        let scopedSessions = sessions.filter { s in
            guard s.endedAt != nil else { return false }
            guard let start = startDate else { return true }
            return s.startedAt >= start
        }

        // Quests completed within scope — must have both the flag and a timestamp.
        let scopedQuests = quests.filter { q in
            guard q.isCompleted, let completedAt = q.completedAt else { return false }
            guard let start = startDate else { return true }
            return completedAt >= start
        }

        // Debts fully cleared within scope. repaidAt is nil while any balance remains.
        let scopedRepaidDebts = debts.filter { d in
            guard let repaidAt = d.repaidAt else { return false }
            guard let start = startDate else { return true }
            return repaidAt >= start
        }

        // Total outstanding debt is always current state regardless of scope.
        let totalOutstandingDebt = debts.reduce(0.0) { $0 + max(0, $1.amount) }

        // Per-activity accumulation.
        var perCredits:      [UUID: Double]       = [:]
        var perElapsed:      [UUID: TimeInterval] = [:]
        var perSessionCount: [UUID: Int]          = [:]
        var totalEarned = 0.0
        var totalSpent  = 0.0

        for session in scopedSessions {
            // Sessions whose activity was deleted have no match — skip silently.
            guard let activity = activityMap[session.activityId] else { continue }
            let credits = activity.credits(for: session.elapsed)

            perCredits[activity.id,      default: 0] += credits
            perElapsed[activity.id,      default: 0] += session.elapsed
            perSessionCount[activity.id, default: 0] += 1

            switch activity.kind {
            case .charger: totalEarned += credits
            case .spender: totalSpent  += credits
            }
        }

        // ActivitySummary list — only activities with sessions in scope, sorted alpha.
        let summaries: [ActivitySummary] = activities
            .filter { perSessionCount[$0.id] != nil }
            .sorted { $0.name < $1.name }
            .map {
                ActivitySummary(
                    id:           $0.id,
                    name:         $0.name,
                    kind:         $0.kind,
                    category:     $0.category ?? .other,  // nil = pre-migration row
                    iconName:     $0.iconName,
                    sessionCount: perSessionCount[$0.id, default: 0],
                    totalElapsed: perElapsed[$0.id,      default: 0],
                    totalCredits: perCredits[$0.id,      default: 0]
                )
            }

        let questPayoff = scopedQuests.reduce(0.0) { $0 + $1.payoffCredits }
        let debtRepaid  = scopedRepaidDebts.reduce(0.0) { $0 + $1.originalAmount }

        // Completed quest entries, newest first within each category.
        let questEntries: [CompletedQuestEntry] = scopedQuests
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .map {
                CompletedQuestEntry(
                    id:            $0.id,
                    name:          $0.name,
                    category:      $0.category ?? .other,  // nil = pre-migration row
                    payoffCredits: $0.payoffCredits,
                    completedAt:   $0.completedAt ?? .distantPast
                )
            }

        // Build CategoryGroups in allCases order; skip empty ones.
        let groups: [CategoryGroup] = ActivityCategory.allCases.compactMap { cat in
            let catQuests   = questEntries.filter { $0.category == cat }
            let catChargers = summaries.filter    { $0.category == cat && $0.kind == .charger }
            let catSpenders = summaries.filter    { $0.category == cat && $0.kind == .spender }
            guard !catQuests.isEmpty || !catChargers.isEmpty || !catSpenders.isEmpty else { return nil }
            return CategoryGroup(category: cat, quests: catQuests, chargers: catChargers, spenders: catSpenders)
        }

        return DashboardStats(
            creditsEarned:        totalEarned,
            creditsSpent:         totalSpent,
            questPayoff:          questPayoff,
            debtRepaid:           debtRepaid,
            netDelta:             totalEarned + questPayoff - totalSpent - debtRepaid,
            totalOutstandingDebt: totalOutstandingDebt,
            categoryGroups:       groups
        )
    }
}
