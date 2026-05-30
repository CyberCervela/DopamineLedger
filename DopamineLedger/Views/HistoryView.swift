// HistoryView.swift
// History tab — reverse-chronological log of completed sessions and
// completed quests, unified into a single timeline grouped by day.
//
// Design decision (D-012): Stats answers "how am I doing?" (aggregates,
// scope picker). History answers "what happened?" (individual events,
// no scope — always all time).
//
// Credits for session rows: elapsed × activity.ratePerSecond, the same
// approximation used in DashboardStats. If the user later changes an
// activity's rate, the displayed credit amount reflects the current rate,
// not the rate that was active at session time.
//
// Bundling: consecutive sessions of the same activity are collapsed into
// one expandable row. "Consecutive" means no other significant session or
// quest appears between them in the sorted timeline. Sub-2-minute sessions
// ("blips") are hidden entirely — they still count toward the balance but
// are too short to be meaningful in the log. Blips between same-activity
// sessions do NOT break a run.

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.theme)          private var theme
    @Environment(\.languageBundle) private var lBundle

    // All sessions and quests fetched without predicate; we filter and sort
    // client-side so we can merge them into a single unified timeline.
    @Query private var allSessions:   [Session]
    @Query private var allQuests:     [Quest]
    @Query private var allActivities: [Activity]

    // A unified event in the history timeline.
    private enum HistoryEntry {
        case session(Session, Activity?)
        case quest(Quest)
        // ≥ 2 consecutive same-activity sessions (all ≥ 2 min); newest-first.
        case sessionBundle([Session], Activity?)

        var date: Date {
            switch self {
            case .session(let s, _):
                return s.endedAt ?? s.startedAt
            case .quest(let q):
                return q.completedAt ?? .distantPast
            case .sessionBundle(let ss, _):
                // Newest session is first; use its end time as the bundle's position.
                return ss.first.map { $0.endedAt ?? $0.startedAt } ?? .distantPast
            }
        }
    }

    // Merged, sorted (newest first), bundled, and grouped by calendar day.
    private var dayGroups: [(header: String, entries: [HistoryEntry])] {
        let activityMap = Dictionary(uniqueKeysWithValues: allActivities.map { ($0.id, $0) })
        let calendar    = Calendar.current

        // Drop sub-2-minute sessions — blips that are meaningless in the log.
        let significantSessions = allSessions
            .filter { $0.endedAt != nil && $0.elapsed >= 120 }

        let sessionEntries: [HistoryEntry] = significantSessions
            .map { .session($0, activityMap[$0.activityId]) }

        let questEntries: [HistoryEntry] = allQuests
            .filter { $0.isCompleted && $0.completedAt != nil }
            .map    { .quest($0) }

        // Sort unified list newest-first before run detection.
        let sorted = (sessionEntries + questEntries)
            .sorted { $0.date > $1.date }

        // Walk the sorted list detecting consecutive same-activity runs.
        // A quest or a session with a different activityId breaks the run.
        var result:        [HistoryEntry] = []
        var runSessions:   [Session]      = []
        var runActivityId: UUID?          = nil

        func flushRun() {
            guard !runSessions.isEmpty, let id = runActivityId else { return }
            let activity = activityMap[id]
            if runSessions.count >= 2 {
                result.append(.sessionBundle(runSessions, activity))
            } else {
                result.append(.session(runSessions[0], activity))
            }
            runSessions   = []
            runActivityId = nil
        }

        for entry in sorted {
            switch entry {
            case .session(let s, _):
                if s.activityId == runActivityId {
                    runSessions.append(s)
                } else {
                    flushRun()
                    runSessions   = [s]
                    runActivityId = s.activityId
                }
            case .quest:
                flushRun()
                result.append(entry)
            case .sessionBundle:
                break  // unreachable at this stage
            }
        }
        flushRun()  // flush any trailing run

        // Group resulting entries by the start-of-day for each entry's date.
        var groups: [(key: Date, entries: [HistoryEntry])] = []
        for entry in result {
            let dayStart = calendar.startOfDay(for: entry.date)
            if let last = groups.last, last.key == dayStart {
                groups[groups.count - 1].entries.append(entry)
            } else {
                groups.append((key: dayStart, entries: [entry]))
            }
        }

        return groups.map { (header: dayHeader(for: $0.key, calendar: calendar), entries: $0.entries) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, theme.spacing.lg)
                .padding(.top,        theme.spacing.md)
                .padding(.bottom,     theme.spacing.lg)

            if dayGroups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: theme.spacing.xl) {
                        ForEach(dayGroups, id: \.header) { group in
                            VStack(alignment: .leading, spacing: theme.spacing.md) {
                                Text(group.header)
                                    .font(theme.typography.caption)
                                    .foregroundStyle(theme.colors.textSecondary)
                                    .kerning(2)
                                ForEach(Array(group.entries.enumerated()), id: \.offset) { _, entry in
                                    switch entry {
                                    case .session(let session, let activity):
                                        SessionHistoryRow(session: session, activity: activity)
                                    case .sessionBundle(let sessions, let activity):
                                        BundledSessionHistoryRow(sessions: sessions, activity: activity)
                                    case .quest(let quest):
                                        QuestHistoryRow(quest: quest)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, theme.spacing.lg)
                    .padding(.bottom,     theme.spacing.xxl)
                }
            }
        }
        .background(theme.colors.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Spacer()
            Text(lBundle.l("history.title"))
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.textPrimary)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text(lBundle.l("history.empty"))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacing.xxl)
            Spacer()
        }
    }

    // "TODAY", "YESTERDAY", or "MON 26 MAY" — all caps.
    // DateFormatter respects device locale automatically for day/month names.
    private func dayHeader(for dayStart: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(dayStart)     { return lBundle.l("scope.today").uppercased() }
        if calendar.isDateInYesterday(dayStart) { return "YESTERDAY" }
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f.string(from: dayStart).uppercased()
    }
}

// MARK: - Duration helper (shared by all row types in this file)

// Defined at file scope so SessionHistoryRow, BundledSessionHistoryRow,
// and BundleDetailRow can all use it without duplication.
private func formatHistoryDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    let h = total / 3600
    let m = (total % 3600) / 60
    return h > 0 ? "\(h)h \(m)m" : "\(m) min"
}

// MARK: - Session row

private struct SessionHistoryRow: View {
    @Environment(\.theme)          private var theme
    @Environment(\.languageBundle) private var lBundle
    let session:  Session
    let activity: Activity?

    private var kindColor: Color {
        switch activity?.kind {
        case .charger: return theme.colors.positive
        case .spender: return theme.colors.negative
        case nil:      return theme.colors.textSecondary
        }
    }

    private var rowIcon: Image {
        guard let activity else { return Image(systemName: "questionmark.circle") }
        return activity.iconName == "circle"
            ? Image(systemName: activity.kind == .charger ? "bolt.fill" : "hourglass")
            : IconResolver.activityIconImage(named: activity.iconName)
    }

    private var creditsText: String {
        guard let activity else { return "" }
        let credits = activity.ratePerSecond * session.elapsed
        let fmt = credits.formatted(.number.precision(.fractionLength(0...1)))
        return activity.kind == .charger ? "+\(fmt)" : "−\(fmt)"
    }

    private var creditsColor: Color {
        activity?.kind == .charger ? theme.colors.positive : theme.colors.negative
    }

    private var activityName: String {
        activity?.name ?? lBundle.l("history.deleted_activity")
    }

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            HistoryIconCircle(image: rowIcon, color: kindColor)

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(activityName)
                    .font(theme.typography.bodyStrong)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(subtitleText)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }

            Spacer()

            if activity != nil {
                Text(creditsText)
                    .font(theme.typography.bodyStrong)
                    .foregroundStyle(creditsColor)
            }
        }
        .padding(theme.spacing.lg)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
        .shadow(color: theme.colors.shadowLight, radius: 8, x: -5, y: -5)
        .shadow(color: theme.colors.shadowDark,  radius: 8, x:  5, y:  5)
    }

    private var subtitleText: String {
        "\(formatTime(session.startedAt)) · \(formatHistoryDuration(session.elapsed))"
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
}

// MARK: - Bundled session row

private struct BundledSessionHistoryRow: View {
    @Environment(\.theme)          private var theme
    @Environment(\.languageBundle) private var lBundle

    let sessions: [Session]   // newest-first, all ≥ 2 min
    let activity: Activity?

    @State private var isExpanded = false

    private var kindColor: Color {
        switch activity?.kind {
        case .charger: return theme.colors.positive
        case .spender: return theme.colors.negative
        case nil:      return theme.colors.textSecondary
        }
    }

    private var rowIcon: Image {
        guard let activity else { return Image(systemName: "questionmark.circle") }
        return activity.iconName == "circle"
            ? Image(systemName: activity.kind == .charger ? "bolt.fill" : "hourglass")
            : IconResolver.activityIconImage(named: activity.iconName)
    }

    private var activityName: String {
        activity?.name ?? lBundle.l("history.deleted_activity")
    }

    private var totalElapsed: TimeInterval {
        sessions.reduce(0) { $0 + $1.elapsed }
    }

    private var totalCreditsText: String {
        guard let activity else { return "" }
        let credits = activity.ratePerSecond * totalElapsed
        let fmt = credits.formatted(.number.precision(.fractionLength(0...1)))
        return activity.kind == .charger ? "+\(fmt)" : "−\(fmt)"
    }

    private var creditsColor: Color {
        activity?.kind == .charger ? theme.colors.positive : theme.colors.negative
    }

    // "19:45 → 20:18 · 5 sessions · 29 min"
    // sessions is newest-first, so last = earliest start, first = latest end.
    private var subtitleText: String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        let startTime = f.string(from: sessions.last?.startedAt  ?? sessions[0].startedAt)
        let endTime   = f.string(from: sessions.first?.endedAt   ?? sessions[0].startedAt)
        let countStr  = String(format: lBundle.l("history.bundle.sessions"), sessions.count)
        let duration  = formatHistoryDuration(totalElapsed)
        return "\(startTime) → \(endTime) · \(countStr) · \(duration)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Summary header — always visible, tappable to expand/collapse.
            HStack(spacing: theme.spacing.md) {
                HistoryIconCircle(image: rowIcon, color: kindColor)

                VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                    Text(activityName)
                        .font(theme.typography.bodyStrong)
                        .foregroundStyle(theme.colors.textPrimary)
                    Text(subtitleText)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                }

                Spacer()

                if activity != nil {
                    Text(totalCreditsText)
                        .font(theme.typography.bodyStrong)
                        .foregroundStyle(creditsColor)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
            .padding(theme.spacing.lg)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            }

            // Individual sessions revealed on expand.
            if isExpanded {
                Rectangle()
                    .fill(theme.colors.textSecondary.opacity(0.1))
                    .frame(height: 1)
                    .padding(.horizontal, theme.spacing.lg)

                ForEach(sessions, id: \.id) { session in
                    BundleDetailRow(session: session, activity: activity)
                }
                .padding(.bottom, theme.spacing.sm)
            }
        }
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
        .shadow(color: theme.colors.shadowLight, radius: 8, x: -5, y: -5)
        .shadow(color: theme.colors.shadowDark,  radius: 8, x:  5, y:  5)
    }
}

// MARK: - Bundle detail row (compact, no card — shown when bundle is expanded)

private struct BundleDetailRow: View {
    @Environment(\.theme) private var theme

    let session:  Session
    let activity: Activity?

    private var creditsText: String {
        guard let activity else { return "" }
        let credits = activity.ratePerSecond * session.elapsed
        let fmt = credits.formatted(.number.precision(.fractionLength(0...1)))
        return activity.kind == .charger ? "+\(fmt)" : "−\(fmt)"
    }

    private var creditsColor: Color {
        activity?.kind == .charger ? theme.colors.positive : theme.colors.negative
    }

    private var subtitleText: String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return "\(f.string(from: session.startedAt)) · \(formatHistoryDuration(session.elapsed))"
    }

    var body: some View {
        HStack {
            Text(subtitleText)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
            Spacer()
            if activity != nil {
                Text(creditsText)
                    .font(theme.typography.caption)
                    .foregroundStyle(creditsColor)
            }
        }
        // Indent to align with the text column in the bundle header.
        // Header layout: lg padding + 44pt icon + md spacing = text start.
        .padding(.leading,   theme.spacing.lg + 44 + theme.spacing.md)
        .padding(.trailing,  theme.spacing.lg)
        .padding(.vertical,  theme.spacing.xs)
    }
}

// MARK: - Quest row

private struct QuestHistoryRow: View {
    @Environment(\.theme)          private var theme
    @Environment(\.languageBundle) private var lBundle
    let quest: Quest

    private var rowIcon: Image {
        quest.iconName == "circle"
            ? Image(systemName: "checkmark.seal.fill")
            : IconResolver.activityIconImage(named: quest.iconName)
    }

    private var questSubtitle: String {
        let caption = lBundle.l("history.quest.caption").uppercased()
        guard let completedAt = quest.completedAt else { return caption }
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return "\(f.string(from: completedAt)) · \(caption)"
    }

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            HistoryIconCircle(image: rowIcon, color: theme.colors.accent)

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(quest.name)
                    .font(theme.typography.bodyStrong)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(questSubtitle)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.accent)
                    .kerning(1)
            }

            Spacer()

            Text("+\(quest.payoffCredits.formatted(.number.precision(.fractionLength(0...1))))")
                .font(theme.typography.bodyStrong)
                .foregroundStyle(theme.colors.positive)
        }
        .padding(theme.spacing.lg)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
        .shadow(color: theme.colors.shadowLight, radius: 8, x: -5, y: -5)
        .shadow(color: theme.colors.shadowDark,  radius: 8, x:  5, y:  5)
    }
}

// MARK: - Shared icon circle

// Same visual treatment as ActivityRow / DebtView — 44pt neumorphic circle.
// Defined privately here to avoid depending on DashboardView's private IconCircle.
private struct HistoryIconCircle: View {
    @Environment(\.theme) private var theme
    let image: Image
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(theme.colors.surface)
                .frame(width: 44, height: 44)
                .shadow(color: theme.colors.shadowLight, radius: 6, x: -3, y: -3)
                .shadow(color: theme.colors.shadowDark,  radius: 6, x:  3, y:  3)
            image
                .font(.system(size: 16))
                .foregroundStyle(color)
        }
    }
}

#Preview {
    HistoryView()
        .environment(\.theme, NeuTheme())
        .modelContainer(for: [Activity.self, Session.self, Quest.self],
                        inMemory: true)
}
