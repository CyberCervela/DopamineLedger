// DashboardView.swift
// Stats tab — time-scoped summary of earned/spent credits, per-activity
// breakdown, and completed quest history.
//
// Data flow: @Query arrays → DashboardStats.compute() → pure struct → subviews.
// No business logic lives here; every number comes from the stats struct so
// the view is purely presentational.

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.theme)          private var theme
    @Environment(\.languageBundle) private var lBundle

    // Full @Query arrays — DashboardStats.compute() does its own filtering by
    // scope, so we don't predicate here. The sets are small and rarely change.
    @Query private var sessions:   [Session]
    @Query private var quests:     [Quest]
    @Query private var activities: [Activity]
    @Query private var debts:      [ActivityDebt]

    @State private var scope: DashboardScope = .today

    private var stats: DashboardStats {
        DashboardStats.compute(
            sessions:   sessions,
            quests:     quests,
            activities: activities,
            debts:      debts,
            scope:      scope
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: theme.spacing.xl) {
                header
                ScopePicker(selection: $scope)
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.top,        theme.spacing.md)
            .padding(.bottom,     theme.spacing.lg)

            ScrollView {
                VStack(spacing: theme.spacing.xl) {
                    SummaryCard(stats: stats)
                    if stats.categoryGroups.isEmpty {
                        SectionEmptyState(icon: .stats, message: lBundle.l("stats.no_sessions"))
                    } else {
                        ForEach(stats.categoryGroups) { group in
                            CategoryGroupSection(group: group)
                        }
                    }
                }
                .padding(.horizontal, theme.spacing.lg)
                .padding(.bottom,     theme.spacing.xxl)
            }
        }
        .background(theme.colors.background.ignoresSafeArea())
    }

    private var header: some View {
        // Mirror the visual weight of the home header (spacers + centred title)
        // without action buttons — stats screen is read-only.
        HStack {
            Spacer()
            Text(lBundle.l("stats.title"))
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.textPrimary)
            Spacer()
        }
    }
}

// MARK: - ScopePicker

// Identical visual treatment to FilterPicker in ActivityListView — pill buttons
// inside a neumorphic container, accent fill on the selected item.
private struct ScopePicker: View {
    @Binding var selection: DashboardScope
    @Environment(\.theme)          private var theme
    @Environment(\.languageBundle) private var lBundle

    var body: some View {
        HStack(spacing: 4) {
            ForEach(DashboardScope.allCases) { scope in
                let isSelected = selection == scope
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = scope }
                } label: {
                    Text(lBundle.l(scope.rawValue))
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.white : theme.colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: theme.spacing.cornerRadius - 6)
                                .fill(isSelected ? theme.colors.accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius - 2))
        .shadow(color: theme.colors.shadowLight, radius: 6, x: -4, y: -4)
        .shadow(color: theme.colors.shadowDark,  radius: 6, x:  4, y:  4)
    }
}

// MARK: - SummaryCard

private struct SummaryCard: View {
    @Environment(\.theme)          private var theme
    @Environment(\.languageBundle) private var lBundle
    let stats: DashboardStats

    private var netDeltaColor: Color {
        if stats.netDelta >  0.05 { return theme.colors.positive }
        if stats.netDelta < -0.05 { return theme.colors.negative }
        return theme.colors.textSecondary
    }

    // Formats the net delta with an explicit +/− prefix.
    // 0.05 threshold avoids "+0.0" from floating-point noise.
    private var netDeltaText: String {
        let abs = Swift.abs(stats.netDelta)
        let fmt = abs.formatted(.number.precision(.fractionLength(0...1)))
        if stats.netDelta >  0.05 { return "+\(fmt)" }
        if stats.netDelta < -0.05 { return "−\(fmt)" }
        return "0"
    }

    var body: some View {
        VStack(spacing: theme.spacing.lg) {

            // Net delta — the headline number for the scope
            VStack(spacing: theme.spacing.xxs) {
                Text(lBundle.l("stats.net_delta_label"))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                    .kerning(2)
                Text(netDeltaText)
                    .font(theme.typography.display)
                    .foregroundStyle(netDeltaColor)
                    .contentTransition(.numericText())
            }

            Divider()
                .overlay(theme.colors.divider)

            // Breakdown rows
            VStack(spacing: theme.spacing.sm) {
                StatRow(
                    label: lBundle.l("stats.earned_label"),
                    value: stats.creditsEarned,
                    sign:  .positive
                )
                StatRow(
                    label: lBundle.l("stats.spent_label"),
                    value: stats.creditsSpent,
                    sign:  .negative
                )
                if stats.questPayoff > 0.05 {
                    StatRow(
                        label: lBundle.l("stats.quests_label"),
                        value: stats.questPayoff,
                        sign:  .positive
                    )
                }
                if stats.debtRepaid > 0.05 {
                    StatRow(
                        label: lBundle.l("stats.debt_repaid_label"),
                        value: stats.debtRepaid,
                        sign:  .negative
                    )
                }
            }

            // Outstanding debt — always current state, not scoped
            if stats.totalOutstandingDebt > 0.05 {
                Divider()
                    .overlay(theme.colors.divider)
                HStack(spacing: theme.spacing.xs) {
                    theme.icon(.debt)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.colors.negative)
                    Text(lBundle.l("stats.outstanding_debt_label"))
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.negative)
                    Spacer()
                    Text(stats.totalOutstandingDebt.formatted(.number.precision(.fractionLength(0...1))))
                        .font(theme.typography.caption.weight(.semibold))
                        .foregroundStyle(theme.colors.negative)
                }
            }
        }
        .padding(theme.spacing.xl)
        .neuCard(.lg)
    }
}

// A single label + value row inside SummaryCard.
private enum SignDirection { case positive, negative }

private struct StatRow: View {
    @Environment(\.theme) private var theme
    let label: String
    let value: Double
    let sign:  SignDirection

    private var activeColor: Color {
        sign == .positive ? theme.colors.positive : theme.colors.negative
    }
    private var prefix: String { sign == .positive ? "+" : "−" }

    var body: some View {
        HStack {
            Text(label)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
            Spacer()
            // Mute the colour when value is zero — no signal to convey.
            Text("\(prefix)\(value.formatted(.number.precision(.fractionLength(0...1))))")
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(value > 0.05 ? activeColor : theme.colors.textSecondary)
        }
    }
}

// MARK: - CategoryGroupSection

// One card group per life-area category. Within the group: quests first,
// then chargers, then spenders — all alphabetical within their sub-kind.
private struct CategoryGroupSection: View {
    @Environment(\.theme)          private var theme
    @Environment(\.languageBundle) private var lBundle
    let group: CategoryGroup

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            SectionHeader(text: lBundle.l(group.category.labelKey).uppercased())
            LazyVStack(spacing: theme.spacing.md) {
                ForEach(group.quests)   { CompletedQuestRow(entry: $0) }
                ForEach(group.chargers) { ActivitySummaryRow(summary: $0) }
                ForEach(group.spenders) { ActivitySummaryRow(summary: $0) }
            }
        }
    }
}

private struct ActivitySummaryRow: View {
    @Environment(\.theme)          private var theme
    @Environment(\.languageBundle) private var lBundle
    let summary: ActivitySummary

    private var iconColor: Color {
        summary.kind == .charger ? theme.colors.positive : theme.colors.negative
    }
    private var rowIcon: Image {
        summary.iconName == "circle"
            ? theme.icon(summary.kind == .charger ? .charger : .spender)
            : IconResolver.activityIconImage(named: summary.iconName)
    }
    private var creditsColor: Color {
        summary.kind == .charger ? theme.colors.positive : theme.colors.negative
    }
    private var creditsPrefix: String { summary.kind == .charger ? "+" : "−" }

    private var sessionLabel: String {
        summary.sessionCount == 1
            ? lBundle.l("stats.sessions_one")
            : String(format: lBundle.l("stats.sessions_other"), summary.sessionCount)
    }

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            IconCircle(image: rowIcon, color: iconColor)

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(summary.name)
                    .font(theme.typography.bodyStrong)
                    .foregroundStyle(theme.colors.textPrimary)
                Text("\(sessionLabel) · \(formatDuration(summary.totalElapsed))")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }

            Spacer()

            Text("\(creditsPrefix)\(summary.totalCredits.formatted(.number.precision(.fractionLength(0...1))))")
                .font(theme.typography.bodyStrong)
                .foregroundStyle(creditsColor)
        }
        .padding(theme.spacing.lg)
        .neuCard()
    }
}

private struct CompletedQuestRow: View {
    @Environment(\.theme)          private var theme
    @Environment(\.languageBundle) private var lBundle
    let entry: CompletedQuestEntry

    private var relativeDate: String {
        // RelativeDateTimeFormatter uses the system locale — acceptable for MVP.
        // A future pass could thread the in-app language through here.
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: entry.completedAt, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            IconCircle(
                image: theme.icon(.quest),
                color: theme.colors.positive
            )

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(entry.name)
                    .font(theme.typography.bodyStrong)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(relativeDate)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }

            Spacer()

            Text("+\(entry.payoffCredits.formatted(.number.precision(.fractionLength(0...1))))")
                .font(theme.typography.bodyStrong)
                .foregroundStyle(theme.colors.positive)
        }
        .padding(theme.spacing.lg)
        .neuCard()
    }
}

// MARK: - Shared helpers

// Icon circle matching the style used throughout the app (ActivityRow, DebtView…).
private struct IconCircle: View {
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

private struct SectionHeader: View {
    @Environment(\.theme) private var theme
    let text: String

    var body: some View {
        Text(text)
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.textSecondary)
            .kerning(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SectionEmptyState: View {
    @Environment(\.theme) private var theme
    let icon:    SemanticIcon
    let message: String

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            theme.icon(icon)
                .font(.system(size: 28))
                .foregroundStyle(theme.colors.textSecondary.opacity(0.4))
            Text(message)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.xl)
    }
}

// formatDuration is also in ActivityListView and SessionView — backlog item
// exists to consolidate into a shared utility.
private func formatDuration(_ seconds: TimeInterval) -> String {
    let totalMins = Int(seconds / 60)
    if totalMins < 1  { return "< 1 min" }
    if totalMins < 60 { return "\(totalMins) min" }
    let hours = totalMins / 60
    let mins  = totalMins % 60
    return mins == 0 ? "\(hours) h" : "\(hours) h \(mins) m"
}

#Preview {
    DashboardView()
        .environment(\.theme, NeuTheme())
        .modelContainer(for: [Activity.self, Session.self, ActivityDebt.self, Ledger.self, Quest.self],
                        inMemory: true)
}
