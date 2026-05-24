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
    // Sessions with no endedAt are "running". The app enforces at most one
    // at a time via the UI, so .first is what we treat as "the" active session.
    @Query(filter: #Predicate<Session> { $0.endedAt == nil })
                                      private var activeSessions: [Session]

    @State private var filter:          ActivityFilter = .all
    @State private var showAddActivity: Bool           = false
    @State private var showAddQuest:    Bool           = false
    @State private var showDebt:        Bool           = false
    @State private var activityToEdit:  Activity?      = nil
    @State private var questToEdit:     Quest?         = nil
    // When non-nil, the ActivityMenuView sheet is presented for this spender
    // (only used when there is outstanding debt — see openActivity).
    @State private var activityMenuFor: Activity?      = nil
    // When non-nil, the SessionView sheet is presented for this session.
    // Bound through to SessionView so it can clear us after STOP.
    @State private var activeSession:   Session?       = nil

    // Ledger is a singleton; .first is safe after fetchOrCreate runs in .task.
    private var ledger: Ledger? { ledgers.first }

    private var totalDebt: Double {
        debts.reduce(0) { $0 + $1.amount }
    }

    // Only meaningful for .chargers / .spenders. .all and .quests have their
    // own dedicated list views (combinedList / questList) so they don't call this.
    private var filteredActivities: [Activity] {
        switch filter {
        case .chargers:     return activities.filter { $0.kind == .charger }
        case .spenders:     return activities.filter { $0.kind == .spender }
        case .all, .quests: return []
        }
    }

    var body: some View {
        // Pinned upper section + scrolling list. We deliberately don't use
        // NavigationStack here: the app doesn't push anywhere from this view
        // (everything is presented as a sheet), and iOS's stock toolbar
        // wraps toolbar buttons in a translucent capsule that clashes with
        // the neumorphic surface. Owning the header gives us full control.
        VStack(spacing: 0) {

            // Pinned upper section — header, balance, filter picker.
            // Lives outside the ScrollView so it stays fixed when the list
            // below is scrolled.
            VStack(spacing: theme.spacing.xl) {
                customHeader
                BalanceCard(
                    balance:    ledger?.balance ?? 0,
                    totalDebt:  totalDebt,
                    onDebtTap:  { showDebt = true }
                )
                // Custom segmented picker — replaces system Picker(.segmented)
                // because SwiftUI's wrapper ignores UIAppearance text-color
                // overrides, making white-on-dark selected text impossible
                // to achieve reliably through the UIKit proxy.
                FilterPicker(selection: $filter)
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.top,        theme.spacing.md)
            .padding(.bottom,     theme.spacing.lg)

            // Scrollable list — only this region moves on swipe.
            ScrollView {
                VStack(spacing: theme.spacing.xl) {
                    // Pick the list view for the current filter.
                    // "All" shows activities followed by quests (grouped, not
                    // interleaved chronologically) so each row's type stays
                    // visually obvious without needing section headers.
                    switch filter {
                    case .all:                  combinedList
                    case .chargers, .spenders:  activityList
                    case .quests:               questList
                    }
                }
                .padding(.horizontal, theme.spacing.lg)
                .padding(.bottom,     theme.spacing.xxl)
            }
        }
        .background(theme.colors.background.ignoresSafeArea())
        .task {
            // Ensure the singleton Ledger row exists before any balance reads.
            _ = Ledger.fetchOrCreate(in: context)
            // Resume a session that was active when the app last closed —
            // otherwise it would silently keep ticking with no way back in.
            // .task on this root view runs once per appearance, which here
            // means once per app launch.
            if activeSession == nil, let leftover = activeSessions.first {
                activeSession = leftover
            }
        }
        .sheet(isPresented: $showAddActivity) {
            // Default the new activity to whichever kind the user is filtering by,
            // so tapping + from "Spenders" doesn't surprise them with a charger pre-selected.
            AddActivityView(mode: .create, initialKind: defaultKindForCurrentFilter)
        }
        .sheet(isPresented: $showAddQuest) {
            AddQuestView(mode: .create)
        }
        .sheet(isPresented: $showDebt) {
            DebtView()
        }
        .sheet(item: $activityToEdit) { activity in
            AddActivityView(mode: .edit(activity))
        }
        .sheet(item: $questToEdit) { quest in
            AddQuestView(mode: .edit(quest))
        }
        .sheet(item: $activityMenuFor) { activity in
            ActivityMenuView(activity: activity) {
                // After the menu dismisses with "Start session", proceed
                // through the normal start path so notifications + active-
                // session state still go through one funnel.
                startSession(for: activity)
            }
        }
        .sheet(item: $activeSession) { session in
            // Look up the activity for this session. In practice the UI never
            // lets an activity be deleted while one of its sessions is open
            // (the SessionView sheet blocks the list), but if it ever happens
            // we degrade with a finalize-and-dismiss rather than a crash.
            if let activity = activities.first(where: { $0.id == session.activityId }) {
                SessionView(session: session, activity: activity, presented: $activeSession)
            } else {
                Color.clear.onAppear {
                    SessionFinalizer.finalize(session: session, in: context)
                    activeSession = nil
                }
            }
        }
    }

    // MARK: - Session lifecycle

    // Row-tap entry point. Spenders with outstanding debt detour through
    // the ActivityMenuView so the user can repay before (or instead of)
    // starting a session. Chargers and clean spenders go straight in.
    private func openActivity(_ activity: Activity) {
        if activity.kind == .spender && hasDebt(for: activity) {
            activityMenuFor = activity
        } else {
            startSession(for: activity)
        }
    }

    private func hasDebt(for activity: Activity) -> Bool {
        debts.contains { $0.activityId == activity.id }
    }

    private func startSession(for activity: Activity) {
        // Defensive guard — the UI shouldn't reach here while another session
        // is active (the SessionView sheet covers the list). Belt + braces.
        guard activeSessions.isEmpty else { return }

        let session = Session(activityId: activity.id)
        context.insert(session)
        activeSession = session

        // Spender sessions get a 5-min warning + zero alarm so the user is
        // notified even if the app is backgrounded. Charger sessions never
        // overrun (no debt possible), so no notifications needed.
        if activity.kind == .spender {
            let balance = Ledger.fetchOrCreate(in: context).balance
            Task {
                await NotificationScheduler.scheduleSpenderSession(
                    sessionId:     session.id,
                    activityName:  activity.name,
                    balance:       balance,
                    ratePerSecond: activity.ratePerSecond
                )
            }
        }
    }

    private var defaultKindForCurrentFilter: ActivityKind {
        switch filter {
        case .spenders:                       return .spender
        case .chargers, .all, .quests:        return .charger
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
                    ActivityRow(
                        activity: activity,
                        onTap:    { openActivity(activity) },
                        onEdit:   { activityToEdit = activity },
                        onDelete: { delete(activity) }
                    )
                }
            }
        }
    }

    // Delete in the parent so the row stays a dumb presentational view.
    // SwiftData propagates the removal to @Query automatically — no manual refresh.
    private func delete(_ activity: Activity) {
        context.delete(activity)
    }

    // Quest completion — soft-delete (flip isCompleted, stamp completedAt)
    // so the row is filtered out of the active list by the existing
    // @Query predicate. Pay out the bounty by adding payoffCredits to the
    // ledger balance. Soft-delete (rather than context.delete) preserves
    // history for a future "completed quests" view (see Quest.swift).
    private func complete(_ quest: Quest) {
        let ledger        = Ledger.fetchOrCreate(in: context)
        ledger.balance   += quest.payoffCredits
        ledger.updatedAt  = Date()
        quest.isCompleted = true
        quest.completedAt = Date()
    }

    // Hard-delete a quest entirely — separate from completion (which keeps
    // the row for history). Used from the long-press context menu.
    private func deleteQuest(_ quest: Quest) {
        context.delete(quest)
    }

    // Used by the "All" filter — activities at the top, quests below,
    // single empty state when both are empty.
    @ViewBuilder
    private var combinedList: some View {
        if activities.isEmpty && quests.isEmpty {
            emptyState(icon: .balance, message: "Nothing yet.\nTap + to add your first.")
        } else {
            LazyVStack(spacing: theme.spacing.md) {
                ForEach(activities) { activity in
                    ActivityRow(
                        activity: activity,
                        onTap:    { openActivity(activity) },
                        onEdit:   { activityToEdit = activity },
                        onDelete: { delete(activity) }
                    )
                }
                ForEach(quests) { quest in
                    QuestRow(
                        quest:      quest,
                        onComplete: { complete(quest) },
                        onEdit:     { questToEdit = quest },
                        onDelete:   { deleteQuest(quest) }
                    )
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
                    QuestRow(
                        quest:      quest,
                        onComplete: { complete(quest) },
                        onEdit:     { questToEdit = quest },
                        onDelete:   { deleteQuest(quest) }
                    )
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

    // Custom header bar replacing the SwiftUI toolbar. Built as a plain
    // HStack so the gear + add icons can use the neumorphic disc style
    // shared by other on-surface icons in the app (NeuIconButton, below).
    private var customHeader: some View {
        HStack(spacing: 0) {
            NeuIconButton(icon: .settings, tint: theme.colors.textSecondary) {
                // Settings sheet — wired in a later step (step 6).
            }
            Spacer()
            Text("Dopamine Ledger")
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.textPrimary)
            Spacer()
            NeuIconButton(icon: .add, tint: theme.colors.accent) {
                // + means "add a quest" on the Quests tab and "add an
                // activity" everywhere else — same icon, context-aware
                // destination.
                if filter == .quests { showAddQuest = true }
                else                 { showAddActivity = true }
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
    let onTap:    () -> Void
    let onEdit:   () -> Void
    let onDelete: () -> Void

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
        // Tap whole row to start a session — the play icon is the visual hint.
        // contentShape extends the hit area so taps anywhere inside the card
        // (including the empty Spacer between text and icon) count.
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        // Long-press for Edit / Delete. SwiftUI's .swipeActions only works inside
        // a List; since this screen uses LazyVStack (so the neumorphic surface
        // shows through between cards), a context menu is the right idiom here.
        .contextMenu {
            Button { onEdit() } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - QuestRow

private struct QuestRow: View {
    @Environment(\.theme) private var theme
    let quest:      Quest
    let onComplete: () -> Void
    let onEdit:     () -> Void
    let onDelete:   () -> Void

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

            // "Done" pill — tap pays out the quest, flips isCompleted,
            // and the row disappears (the active-quests @Query filters
            // completed ones out). No confirmation: payoff is positive,
            // so a mistap costs the user nothing.
            Button(action: onComplete) {
                Text("Done")
                    .font(theme.typography.button.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, theme.spacing.lg)
                    .padding(.vertical,   theme.spacing.sm)
                    .background(theme.colors.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacing.lg)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
        .shadow(color: theme.colors.shadowLight, radius: 8, x: -5, y: -5)
        .shadow(color: theme.colors.shadowDark,  radius: 8, x:  5, y:  5)
        // Long-press menu for Edit / Delete — parallel to ActivityRow.
        .contextMenu {
            Button { onEdit() } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
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

// MARK: - NeuIconButton
//
// Small neumorphic disc with an icon — used in the custom header where
// the stock SwiftUI toolbar item style (a translucent capsule) would
// clash with the on-surface neumorphic vocabulary. Shadow radius is
// smaller than card-sized neumorphic surfaces so the disc reads as a
// control, not a card.

private struct NeuIconButton: View {
    @Environment(\.theme) private var theme
    let icon:   SemanticIcon
    let tint:   Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(theme.colors.surface)
                    .frame(width: 38, height: 38)
                    .shadow(color: theme.colors.shadowLight, radius: 5, x: -3, y: -3)
                    .shadow(color: theme.colors.shadowDark,  radius: 5, x:  3, y:  3)
                theme.icon(icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ActivityListView()
        .environment(\.theme, NeuTheme())
        .modelContainer(for: [Activity.self, Session.self, ActivityDebt.self, Ledger.self, Quest.self],
                        inMemory: true)
}
