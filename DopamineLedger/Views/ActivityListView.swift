// ActivityListView.swift
// The home screen. BalanceCard pinned at top, segmented filter, activity list.
//
// Data flows: @Query fetches from SwiftData; Ledger.fetchOrCreate ensures
// the singleton balance row exists on first launch. No view-model layer —
// @Query + ModelContext directly per the round-2 architecture decision.

import SwiftUI
import SwiftData

// Which activity kind is currently shown in the list.
enum ActivityFilter: String, CaseIterable {
    case all      = "All"
    case chargers = "Chargers"
    case spenders = "Spenders"
    case quests   = "Quests"
}

struct ActivityListView: View {
    @Environment(\.theme)        private var theme
    @Environment(\.modelContext) private var context

    @Query(sort: \Activity.createdAt) private var activities:  [Activity]
    @Query                            private var ledgers:      [Ledger]
    // Filter debt to unpaid rows only (amount > 0 = still owed).
    @Query(filter: #Predicate<ActivityDebt> { $0.amount > 0 })
                                      private var debts:        [ActivityDebt]
    @Query(filter: #Predicate<Quest>  { $0.isCompleted == false })
                                      private var quests:       [Quest]

    @State private var filter: ActivityFilter = .all

    // Ledger is a singleton; .first is safe after fetchOrCreate runs in .task.
    private var ledger: Ledger? { ledgers.first }

    private var totalDebt: Double {
        debts.reduce(0) { $0 + $1.amount }
    }

    private var filteredActivities: [Activity] {
        switch filter {
        case .all:      return activities
        case .chargers: return activities.filter { $0.kind == .charger }
        case .spenders: return activities.filter { $0.kind == .spender }
        case .quests:   return []  // quests are a separate model; shown below
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.xl) {

                    // Balance card — always visible at top.
                    BalanceCard(
                        balance:   ledger?.balance ?? 0,
                        totalDebt: totalDebt
                    )

                    // Custom segmented picker — replaces system Picker(.segmented)
                    // because SwiftUI's wrapper ignores UIAppearance text-color
                    // overrides, making white-on-dark selected text impossible
                    // to achieve reliably through the UIKit proxy.
                    FilterPicker(selection: $filter)

                    // Activity / quest rows — or empty state.
                    if filter == .quests {
                        questList
                    } else {
                        activityList
                    }
                }
                .padding(.horizontal, theme.spacing.lg)
                .padding(.top, theme.spacing.md)
                .padding(.bottom, theme.spacing.xxl)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .task {
            // Ensure the singleton Ledger row exists before any balance reads.
            _ = Ledger.fetchOrCreate(in: context)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var activityList: some View {
        let items = filteredActivities
        if items.isEmpty {
            emptyState(
                icon:    filter == .chargers ? .charger : (filter == .spenders ? .spender : .balance),
                message: emptyMessage(for: filter)
            )
        } else {
            LazyVStack(spacing: theme.spacing.md) {
                ForEach(items) { activity in
                    ActivityRow(activity: activity)
                }
            }
        }
    }

    @ViewBuilder
    private var questList: some View {
        if quests.isEmpty {
            emptyState(icon: .quest, message: "No active quests.\nTap + to add one.")
        } else {
            LazyVStack(spacing: theme.spacing.md) {
                ForEach(quests) { quest in
                    QuestRow(quest: quest)
                }
            }
        }
    }

    @ViewBuilder
    private func emptyState(icon: SemanticIcon, message: String) -> some View {
        VStack(spacing: theme.spacing.lg) {
            theme.icon(icon)
                .font(.system(size: 36))
                .foregroundStyle(theme.colors.textSecondary.opacity(0.5))
            Text(message)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.xxl)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Title — custom so the theme font applies (nav title ignores SwiftUI fonts).
        ToolbarItem(placement: .principal) {
            Text("Dopamine Ledger")
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.textPrimary)
        }
        ToolbarItem(placement: .navigationBarLeading) {
            Button { /* settings sheet — wired in a later step */ } label: {
                theme.icon(.settings)
                    .foregroundStyle(theme.colors.textSecondary)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { /* add sheet — wired in a later step */ } label: {
                theme.icon(.add)
                    .foregroundStyle(theme.colors.accent)
            }
        }
    }

    private func emptyMessage(for filter: ActivityFilter) -> String {
        switch filter {
        case .all:      return "No activities yet.\nTap + to add your first."
        case .chargers: return "No chargers yet.\nChargers earn credits over time."
        case .spenders: return "No spenders yet.\nSpenders spend credits over time."
        case .quests:   return ""
        }
    }
}

// MARK: - ActivityRow

private struct ActivityRow: View {
    @Environment(\.theme) private var theme
    let activity: Activity

    private var ratePerMinute: Double { activity.ratePerSecond * 60 }
    private var iconColor: Color {
        activity.kind == .charger ? theme.colors.positive : theme.colors.negative
    }

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            // Kind icon in a small neumorphic circle.
            ZStack {
                Circle()
                    .fill(theme.colors.surface)
                    .frame(width: 44, height: 44)
                    .shadow(color: theme.colors.shadowLight, radius: 6, x: -3, y: -3)
                    .shadow(color: theme.colors.shadowDark,  radius: 6, x:  3, y:  3)
                theme.icon(activity.kind == .charger ? .charger : .spender)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(activity.name)
                    .font(theme.typography.bodyStrong)
                    .foregroundStyle(theme.colors.textPrimary)
                Text("\(ratePerMinute, format: .number.precision(.fractionLength(1))) cr / min")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }

            Spacer()

            theme.icon(.play)
                .font(.system(size: 14))
                .foregroundStyle(theme.colors.accent)
        }
        .padding(theme.spacing.lg)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
        .shadow(color: theme.colors.shadowLight, radius: 8, x: -5, y: -5)
        .shadow(color: theme.colors.shadowDark,  radius: 8, x:  5, y:  5)
    }
}

// MARK: - QuestRow

private struct QuestRow: View {
    @Environment(\.theme) private var theme
    let quest: Quest

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            ZStack {
                Circle()
                    .fill(theme.colors.surface)
                    .frame(width: 44, height: 44)
                    .shadow(color: theme.colors.shadowLight, radius: 6, x: -3, y: -3)
                    .shadow(color: theme.colors.shadowDark,  radius: 6, x:  3, y:  3)
                theme.icon(.quest)
                    .font(.system(size: 16))
                    .foregroundStyle(theme.colors.neutral)
            }

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(quest.name)
                    .font(theme.typography.bodyStrong)
                    .foregroundStyle(theme.colors.textPrimary)
                Text("+\(quest.payoffCredits, format: .number.precision(.fractionLength(0))) credits on completion")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.positive)
            }

            Spacer()

            Text("Done")
                .font(theme.typography.button)
                .foregroundStyle(theme.colors.accent)
        }
        .padding(theme.spacing.lg)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
        .shadow(color: theme.colors.shadowLight, radius: 8, x: -5, y: -5)
        .shadow(color: theme.colors.shadowDark,  radius: 8, x:  5, y:  5)
    }
}

// MARK: - FilterPicker
//
// Custom segmented control built in pure SwiftUI. The system Picker(.segmented)
// ignores UIAppearance text-color overrides for the selected state, making it
// impossible to show white text on the dark charcoal pill reliably. Owning the
// rendering means we style it exactly once, here, and it just works.

private struct FilterPicker: View {
    @Binding var selection: ActivityFilter
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ActivityFilter.allCases, id: \.self) { option in
                let isSelected = selection == option
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = option }
                } label: {
                    Text(option.rawValue)
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

#Preview {
    ActivityListView()
        .environment(\.theme, NeuTheme())
        .modelContainer(for: [Activity.self, Session.self, ActivityDebt.self, Ledger.self, Quest.self],
                        inMemory: true)
}
