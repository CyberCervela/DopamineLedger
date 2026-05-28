// ActivityListView.swift
// The home screen. BalanceCard pinned at top, segmented filter, activity list.

import SwiftUI
import SwiftData

enum ActivityFilter: String, CaseIterable {
    case all      = "filter.all"
    case chargers = "filter.chargers"
    case spenders = "filter.spenders"
    case quests   = "filter.quests"
}

struct ActivityListView: View {
    @Environment(\.theme)          private var theme
    @Environment(\.modelContext)   private var context
    @Environment(\.languageBundle) private var lBundle

    @Query(sort: \Activity.createdAt) private var activities:    [Activity]
    @Query                            private var ledgers:        [Ledger]
    @Query(filter: #Predicate<ActivityDebt> { $0.amount > 0 })
                                      private var debts:          [ActivityDebt]
    @Query(filter: #Predicate<Quest>  { $0.isCompleted == false })
                                      private var quests:         [Quest]
    @Query(filter: #Predicate<Session> { $0.endedAt == nil })
                                      private var activeSessions: [Session]

    @State private var filter:              ActivityFilter = .all
    @State private var showAddActivity:     Bool           = false
    @State private var showAddQuest:        Bool           = false
    @State private var showDebt:            Bool           = false
    @State private var showSettings:        Bool           = false
    @State private var showTemplateGallery: Bool           = false
    @State private var showAddChoiceDialog: Bool           = false
    @State private var activityToEdit:      Activity?      = nil
    @State private var questToEdit:         Quest?         = nil
    @State private var activityMenuFor:     Activity?      = nil
    @State private var activeSession:       Session?       = nil

    private var ledger: Ledger? { ledgers.first }
    private var totalDebt: Double { debts.reduce(0) { $0 + $1.amount } }

    private var filteredActivities: [Activity] {
        switch filter {
        case .chargers:     return activities.filter { $0.kind == .charger }
        case .spenders:     return activities.filter { $0.kind == .spender }
        case .all, .quests: return []
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: theme.spacing.xl) {
                customHeader
                BalanceCard(
                    balance:    ledger?.balance ?? 0,
                    totalDebt:  totalDebt,
                    onDebtTap:  { showDebt = true }
                )
                FilterPicker(selection: $filter)
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.top,        theme.spacing.md)
            .padding(.bottom,     theme.spacing.lg)

            ScrollView {
                VStack(spacing: theme.spacing.xl) {
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
            _ = Ledger.fetchOrCreate(in: context)
            if activeSession == nil, let leftover = activeSessions.first {
                activeSession = leftover
            }
        }
        .sheet(isPresented: $showAddActivity) {
            AddActivityView(mode: .create, initialKind: defaultKindForCurrentFilter)
        }
        .sheet(isPresented: $showTemplateGallery) {
            TemplateGalleryView()
        }
        .confirmationDialog(lBundle.l("activity.add.dialog.title"),
                            isPresented: $showAddChoiceDialog,
                            titleVisibility: .visible) {
            Button(lBundle.l("activity.add.from.template")) { showTemplateGallery = true }
            Button(lBundle.l("activity.add.create.own"))    { showAddActivity     = true }
        }
        .sheet(isPresented: $showAddQuest) {
            AddQuestView(mode: .create)
        }
        .sheet(isPresented: $showDebt) {
            DebtView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(item: $activityToEdit) { activity in
            AddActivityView(mode: .edit(activity))
        }
        .sheet(item: $questToEdit) { quest in
            AddQuestView(mode: .edit(quest))
        }
        .sheet(item: $activityMenuFor) { activity in
            ActivityMenuView(activity: activity) {
                startSession(for: activity)
            }
        }
        .sheet(item: $activeSession) { session in
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

    private func openActivity(_ activity: Activity) {
        // If this activity already has a running session (e.g., user swiped
        // down the sheet), re-open it instead of trying to start a new one.
        if let running = activeSessions.first(where: { $0.activityId == activity.id }) {
            activeSession = running
            return
        }
        // Block starting any new session while another is already running.
        guard activeSessions.isEmpty else { return }

        guard activity.kind == .spender else {
            startSession(for: activity)
            return
        }
        let balance = ledger?.balance ?? 0
        if hasDebt(for: activity) || balance <= 0 {
            activityMenuFor = activity
        } else {
            startSession(for: activity)
        }
    }

    private func hasDebt(for activity: Activity) -> Bool {
        debts.contains { $0.activityId == activity.id }
    }

    private func startSession(for activity: Activity) {
        guard activeSessions.isEmpty else { return }
        let session = Session(activityId: activity.id)
        context.insert(session)
        activeSession = session

        LiveActivityService.start(
            activityName:  activity.name,
            activityKind:  activity.kind,
            ratePerSecond: activity.ratePerSecond,
            startedAt:     session.startedAt
        )

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

    private func isActive(_ activity: Activity) -> Bool {
        activeSessions.first?.activityId == activity.id
    }

    private func debtAmount(for activity: Activity) -> Double {
        debts.filter { $0.activityId == activity.id }.reduce(0) { $0 + $1.amount }
    }

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
                        activity:   activity,
                        isActive:   isActive(activity),
                        debtAmount: debtAmount(for: activity),
                        balance:    ledger?.balance ?? 0,
                        onTap:      { openActivity(activity) },
                        onEdit:     { activityToEdit = activity },
                        onDelete:   { delete(activity) }
                    )
                }
            }
        }
    }

    private func delete(_ activity: Activity) {
        context.delete(activity)
    }

    private func complete(_ quest: Quest) {
        let ledger        = Ledger.fetchOrCreate(in: context)
        ledger.balance   += quest.payoffCredits
        ledger.updatedAt  = Date()
        quest.isCompleted = true
        quest.completedAt = Date()
    }

    private func deleteQuest(_ quest: Quest) {
        context.delete(quest)
    }

    @ViewBuilder
    private var combinedList: some View {
        if activities.isEmpty && quests.isEmpty {
            emptyState(icon: .balance, message: lBundle.l("home.empty.all"))
        } else {
            LazyVStack(spacing: theme.spacing.md) {
                ForEach(activities) { activity in
                    ActivityRow(
                        activity:   activity,
                        isActive:   isActive(activity),
                        debtAmount: debtAmount(for: activity),
                        balance:    ledger?.balance ?? 0,
                        onTap:      { openActivity(activity) },
                        onEdit:     { activityToEdit = activity },
                        onDelete:   { delete(activity) }
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
            emptyState(icon: .quest, message: lBundle.l("home.empty.quests"))
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

    private var customHeader: some View {
        HStack(spacing: 0) {
            NeuIconButton(icon: .settings, tint: theme.colors.textSecondary) {
                showSettings = true
            }
            Spacer()
            Text(lBundle.l("home.title"))
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.textPrimary)
            Spacer()
            NeuIconButton(icon: .add, tint: theme.colors.accent) {
                if filter == .quests { showAddQuest        = true }
                else                 { showAddChoiceDialog = true }
            }
        }
    }

    private func emptyMessage(for filter: ActivityFilter) -> String {
        switch filter {
        case .all:      return lBundle.l("home.empty.all")
        case .chargers: return lBundle.l("home.empty.chargers")
        case .spenders: return lBundle.l("home.empty.spenders")
        case .quests:   return lBundle.l("home.empty.quests")
        }
    }
}

// MARK: - ActivityRow

private struct ActivityRow: View {
    @Environment(\.theme)          private var theme
    @Environment(\.languageBundle) private var lBundle
    let activity:   Activity
    let isActive:   Bool
    let debtAmount: Double
    let balance:    Double
    let onTap:    () -> Void
    let onEdit:   () -> Void
    let onDelete: () -> Void

    @State private var pulsing = false

    private var ratePerMinute: Double { activity.ratePerSecond * 60 }
    private var iconColor: Color {
        activity.kind == .charger ? theme.colors.positive : theme.colors.negative
    }

    private var burndownSeconds: Double? {
        guard activity.kind == .spender,
              !isActive,
              balance > 0,
              activity.ratePerSecond > 0 else { return nil }
        return balance / activity.ratePerSecond
    }

    private func formatDuration(_ seconds: Double) -> String {
        let totalMins = Int(seconds / 60)
        if totalMins < 1 { return "< 1 min" }
        if totalMins < 60 { return "\(totalMins) min" }
        let hours = totalMins / 60
        let mins  = totalMins % 60
        return mins == 0 ? "\(hours) h" : "\(hours) h \(mins) m"
    }

    // Use the user-chosen icon, or fall back to the semantic kind icon for
    // activities created before the icon picker existed (default = "circle").
    private var rowIcon: Image {
        activity.iconName == "circle"
            ? theme.icon(activity.kind == .charger ? .charger : .spender)
            : IconResolver.activityIconImage(named: activity.iconName)
    }

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            ZStack {
                Circle()
                    .fill(theme.colors.surface)
                    .frame(width: 44, height: 44)
                    .shadow(color: theme.colors.shadowLight, radius: 6, x: -3, y: -3)
                    .shadow(color: theme.colors.shadowDark,  radius: 6, x:  3, y:  3)
                rowIcon
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(activity.name)
                    .font(theme.typography.bodyStrong)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(String(format: lBundle.l("session.rate"),
                            ratePerMinute.formatted(.number.precision(.fractionLength(1)))))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                if let secs = burndownSeconds {
                    Text(String(format: lBundle.l("row.activity.burndown"), formatDuration(secs)))
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                }
                if debtAmount > 0 {
                    Text(String(format: lBundle.l("row.activity.debt"),
                                debtAmount.formatted(.number.precision(.fractionLength(1)))))
                        .font(theme.typography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, theme.spacing.sm)
                        .padding(.vertical, 2)
                        .background(theme.colors.negative)
                        .clipShape(Capsule())
                }
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
        .overlay(
            RoundedRectangle(cornerRadius: theme.spacing.cornerRadius)
                .strokeBorder(
                    isActive ? theme.colors.accent.opacity(pulsing ? 1.0 : 0.25) : Color.clear,
                    lineWidth: 1.5
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onAppear {
            guard isActive else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
        .contextMenu {
            Button { onEdit() } label: {
                Label(lBundle.l("common.edit"), systemImage: "pencil")
            }
            Button(role: .destructive) { onDelete() } label: {
                Label(lBundle.l("common.delete"), systemImage: "trash")
            }
        }
    }
}

// MARK: - QuestRow

private struct QuestRow: View {
    @Environment(\.theme)          private var theme
    @Environment(\.languageBundle) private var lBundle
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
                Text(String(format: lBundle.l("row.quest.payoff"),
                            quest.payoffCredits.formatted(.number.precision(.fractionLength(0)))))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.positive)
            }

            Spacer()

            Button(action: onComplete) {
                Text(lBundle.l("row.quest.done"))
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
        .contextMenu {
            Button { onEdit() } label: {
                Label(lBundle.l("common.edit"), systemImage: "pencil")
            }
            Button(role: .destructive) { onDelete() } label: {
                Label(lBundle.l("common.delete"), systemImage: "trash")
            }
        }
    }
}

// MARK: - FilterPicker

private struct FilterPicker: View {
    @Binding var selection: ActivityFilter
    @Environment(\.theme)          private var theme
    @Environment(\.languageBundle) private var lBundle

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ActivityFilter.allCases, id: \.self) { option in
                let isSelected = selection == option
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = option }
                } label: {
                    Text(lBundle.l(option.rawValue))
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
