// ActivityListView.swift
// The home screen. BalanceCard pinned at top, segmented filter, activity list.

import SwiftUI
import SwiftData

// Which path the user chose when tapping + on the activity list.
// Used by the onDismiss callback to present the right next sheet.
enum AddActivityPath { case createOwn, fromTemplate }

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
    @Environment(\.scenePhase)     private var scenePhase

    @Query(filter: #Predicate<Activity> { $0.isArchived == false },
           sort: \Activity.createdAt) private var activities: [Activity]
    @Query                            private var ledgers:        [Ledger]
    @Query(filter: #Predicate<ActivityDebt> { $0.amount > 0 })
                                      private var debts:          [ActivityDebt]
    @Query(filter: #Predicate<Quest>  { $0.isCompleted == false && $0.isArchived == false })
                                      private var quests:         [Quest]
    @Query(filter: #Predicate<Session> { $0.endedAt == nil })
                                      private var activeSessions: [Session]

    @State private var filter:              ActivityFilter   = .all
    @State private var showAddActivity:     Bool             = false
    @State private var showAddQuest:        Bool             = false
    @State private var showDebt:            Bool             = false
    @State private var showSettings:        Bool             = false
    @State private var showTemplateGallery: Bool             = false
    @State private var showAddChoice:       Bool             = false
    @State private var pendingAddPath:      AddActivityPath? = nil
    @State private var activityToEdit:      Activity?        = nil
    @State private var questToEdit:         Quest?         = nil
    @State private var activityMenuFor:     Activity?      = nil
    @State private var activeSession:       Session?       = nil
    @State private var activityToArchive:   Activity?      = nil

    private var ledger: Ledger? { ledgers.first }
    private var totalDebt: Double { debts.reduce(0) { $0 + $1.amount } }

    // Hides next-period instances of recurring quests (availableAt > now).
    // One-shot quests (availableAt == nil) are always visible.
    private var filteredQuests: [Quest] {
        let now = Date()
        return quests.filter { $0.availableAt.map { $0 <= now } ?? true }
    }

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
            recoverLiveActivityIfNeeded()
            sweepExpiredRecurringQuests()
        }
        // When the app comes to the foreground (e.g. after a Siri intent ran while
        // backgrounded), re-check whether a Live Activity needs to be started.
        // Activity.request() is foreground-only, so the intent's call silently
        // failed; we start it here instead. Also re-sweep recurring quests in
        // case a period boundary passed while the app was backgrounded.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                recoverLiveActivityIfNeeded()
                sweepExpiredRecurringQuests()
            }
        }
        .sheet(isPresented: $showAddActivity) {
            AddActivityView(mode: .create, initialKind: defaultKindForCurrentFilter)
        }
        .sheet(isPresented: $showTemplateGallery) {
            TemplateGalleryView()
        }
        // After the choice sheet dismisses, open the appropriate next sheet.
        // Doing it in onDismiss avoids presenting two sheets simultaneously.
        .sheet(isPresented: $showAddChoice, onDismiss: {
            guard let path = pendingAddPath else { return }
            pendingAddPath = nil
            switch path {
            case .createOwn:    showAddActivity     = true
            case .fromTemplate: showTemplateGallery = true
            }
        }) {
            ActivityAddChoiceView { path in
                pendingAddPath = path
                showAddChoice  = false
            }
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
        // Confirmation before archiving an activity. Soft-delete keeps all session
        // history intact — the activity disappears from this list but its credits
        // and sessions remain in Stats and History forever.
        .alert(
            String(format: lBundle.l("activity.archive.title"),
                   activityToArchive?.name ?? ""),
            isPresented: Binding(
                get: { activityToArchive != nil },
                set: { if !$0 { activityToArchive = nil } }
            )
        ) {
            Button(lBundle.l("activity.archive.confirm"), role: .destructive) {
                if let a = activityToArchive { a.isArchived = true }
                activityToArchive = nil
            }
            Button(lBundle.l("common.cancel"), role: .cancel) {
                activityToArchive = nil
            }
        } message: {
            Text(lBundle.l("activity.archive.message"))
        }
    }

    // MARK: - Session lifecycle

    // Starts a Live Activity for any session that is running but has no Live
    // Activity visible. This covers the Siri-start case: Activity.request() is
    // foreground-only, so the intent's attempt silently no-ops; we retry here
    // as soon as the app becomes active.
    private func recoverLiveActivityIfNeeded() {
        guard !LiveActivityService.hasActiveActivity,
              let session = activeSessions.first else { return }
        guard let act = activities.first(where: { $0.id == session.activityId }) else { return }
        // adjustedStart accounts for any pauses so the timer shows correct elapsed.
        let adjustedStart = session.startedAt.addingTimeInterval(session.totalPausedSeconds)
        LiveActivityService.start(
            activityName:  act.name,
            activityKind:  act.kind,
            ratePerSecond: act.ratePerSecond,
            startedAt:     adjustedStart
        )
        if session.isPaused {
            LiveActivityService.update(
                adjustedStart: adjustedStart,
                isPaused:      true,
                pausedElapsed: session.elapsed,
                creditsMoved:  act.ratePerSecond * session.elapsed
            )
        }
    }

    private func openActivity(_ activity: Activity) {
        // Re-open an already-running session (e.g. user swiped down the sheet).
        if let running = activeSessions.first(where: { $0.activityId == activity.id }) {
            activeSession = running
            return
        }
        // Block starting any new session while one is already running.
        guard activeSessions.isEmpty else { return }
        // Always route through ActivityMenuView — no session starts on a bare tap.
        // The explicit Start button there is the only path to startSession(for:).
        activityMenuFor = activity
    }

    private func hasDebt(for activity: Activity) -> Bool {
        debts.contains { $0.activityId == activity.id }
    }

    private func startSession(for activity: Activity) {
        guard activeSessions.isEmpty else { return }
        let session = Session(activityId: activity.id)
        // Freeze the peak-hours multiplier at start time. A session that begins
        // during peak keeps its 1.5× bonus for its full lifetime (even through
        // pauses); stopping and restarting creates a fresh session that re-checks.
        session.timeMultiplier = PeakHoursService.isCurrentlyPeak() ? PeakHoursService.multiplier : 1.0
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
                        activity:        activity,
                        isActive:        isActive(activity),
                        anySessionActive: !activeSessions.isEmpty,
                        debtAmount:      debtAmount(for: activity),
                        balance:         ledger?.balance ?? 0,
                        onTap:           { openActivity(activity) },
                        onEdit:          { activityToEdit = activity },
                        onDelete:        { delete(activity) }
                    )
                }
            }
        }
    }

    private func delete(_ activity: Activity) {
        // Route through confirmation alert — actual archive is set there.
        activityToArchive = activity
    }

    private func complete(_ quest: Quest) {
        let ledger        = Ledger.fetchOrCreate(in: context)
        // A quest completed during peak hours earns the same bonus as a
        // charger session — making your bed at 07:00 is worth more than at 22:00.
        let multiplier    = PeakHoursService.isCurrentlyPeak() ? PeakHoursService.multiplier : 1.0
        ledger.balance   += quest.payoffCredits * multiplier
        ledger.updatedAt  = Date()
        quest.isCompleted = true
        quest.completedAt = Date()
        // For recurring quests, spawn the next-period instance immediately.
        // availableAt is set to the next period boundary so the new instance
        // stays hidden until the cycle rolls — no double-dipping same day/week/month.
        if let cadence = quest.recurringCadence {
            let next = Quest(
                name:             quest.name,
                payoffCredits:    quest.payoffCredits,
                iconName:         quest.iconName,
                category:         quest.category ?? .other,
                recurringCadence: cadence
            )
            // Quest.init sets availableAt = cadence.currentPeriodStart (visible now).
            // Override with nextPeriodStart so it's hidden until tomorrow/next week/etc.
            next.availableAt = cadence.nextPeriodStart(from: Date())
            context.insert(next)
        }
    }

    // Sweeps stale recurring quest instances. On each app open / foreground:
    // for each uncompleted recurring quest whose period has passed, hard-delete
    // it (silent expiry — no history entry) and insert a fresh one for today.
    // This means skipped periods never stack and never create guilt.
    private func sweepExpiredRecurringQuests() {
        for quest in Array(quests) where quest.recurringCadence != nil
                                     && !quest.isCompleted
                                     && !quest.isArchived {
            guard let cadence     = quest.recurringCadence,
                  let availableAt = quest.availableAt else { continue }
            let currentStart = cadence.currentPeriodStart
            guard availableAt < currentStart else { continue }
            let fresh = Quest(
                name:             quest.name,
                payoffCredits:    quest.payoffCredits,
                iconName:         quest.iconName,
                category:         quest.category ?? .other,
                recurringCadence: cadence
            )
            // Quest.init sets availableAt = cadence.currentPeriodStart, so
            // the fresh instance is immediately visible (currentPeriodStart ≤ now).
            context.delete(quest)
            context.insert(fresh)
        }
    }

    private func deleteQuest(_ quest: Quest) {
        if quest.isCompleted {
            // Credits already moved at completion — preserve history, soft-delete only.
            quest.isArchived = true
        } else {
            // No credits moved yet — safe to hard-delete.
            context.delete(quest)
        }
    }

    // Full-screen empty state shown on first launch (no activities or quests at all).
    // Uses a neumorphic card with two CTAs so new users have a clear path forward
    // without hunting for the + button.
    // No outer card — NeuTextButton pills are already raised surfaces.
    // Wrapping them in a neumorphic card would stack two shadow layers on the
    // same background, creating visual noise (card raised → buttons raised inside).
    @ViewBuilder
    private var homeEmptyState: some View {
        VStack(spacing: theme.spacing.lg) {
            theme.icon(.balance)
                .font(.system(size: 28))
                .foregroundStyle(theme.colors.textSecondary.opacity(0.4))
            Text(lBundle.l("home.empty.all"))
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
            VStack(spacing: theme.spacing.md) {
                NeuTextButton(
                    title:      lBundle.l("home.empty.all.browse"),
                    font:       theme.typography.caption,
                    foreground: theme.colors.accent,
                    action:     { showTemplateGallery = true }
                )
                NeuTextButton(
                    title:      lBundle.l("home.empty.all.create"),
                    font:       theme.typography.caption,
                    foreground: theme.colors.textSecondary,
                    action:     { showAddActivity = true }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.xxl)
    }

    @ViewBuilder
    private var combinedList: some View {
        if activities.isEmpty && filteredQuests.isEmpty {
            homeEmptyState
        } else {
            LazyVStack(spacing: theme.spacing.xl) {
                ForEach(ActivityCategory.allCases, id: \.self) { cat in
                    let catQuests   = filteredQuests.filter { ($0.category ?? .other) == cat }
                    let catChargers = activities.filter { ($0.category ?? .other) == cat && $0.kind == .charger }
                    let catSpenders = activities.filter { ($0.category ?? .other) == cat && $0.kind == .spender }
                    if !catQuests.isEmpty || !catChargers.isEmpty || !catSpenders.isEmpty {
                        VStack(alignment: .leading, spacing: theme.spacing.md) {
                            Text(lBundle.l(cat.labelKey).uppercased())
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.textSecondary)
                                .kerning(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            LazyVStack(spacing: theme.spacing.md) {
                                ForEach(catQuests) { quest in
                                    QuestRow(
                                        quest:      quest,
                                        onComplete: { complete(quest) },
                                        onEdit:     { questToEdit = quest },
                                        onDelete:   { deleteQuest(quest) }
                                    )
                                }
                                ForEach(catChargers) { activity in
                                    ActivityRow(
                                        activity:        activity,
                                        isActive:        isActive(activity),
                                        anySessionActive: !activeSessions.isEmpty,
                                        debtAmount:      debtAmount(for: activity),
                                        balance:         ledger?.balance ?? 0,
                                        onTap:           { openActivity(activity) },
                                        onEdit:          { activityToEdit = activity },
                                        onDelete:        { delete(activity) }
                                    )
                                }
                                ForEach(catSpenders) { activity in
                                    ActivityRow(
                                        activity:        activity,
                                        isActive:        isActive(activity),
                                        anySessionActive: !activeSessions.isEmpty,
                                        debtAmount:      debtAmount(for: activity),
                                        balance:         ledger?.balance ?? 0,
                                        onTap:           { openActivity(activity) },
                                        onEdit:          { activityToEdit = activity },
                                        onDelete:        { delete(activity) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var questList: some View {
        if filteredQuests.isEmpty {
            emptyState(icon: .quest, message: lBundle.l("home.empty.quests"))
        } else {
            LazyVStack(spacing: theme.spacing.xl) {
                questSection(lBundle.l("quest.cadence.daily"),
                             quests: filteredQuests.filter { $0.recurringCadence == .daily })
                questSection(lBundle.l("quest.cadence.weekly"),
                             quests: filteredQuests.filter { $0.recurringCadence == .weekly })
                questSection(lBundle.l("quest.cadence.monthly"),
                             quests: filteredQuests.filter { $0.recurringCadence == .monthly })
                questSection(lBundle.l("quest.section.goals"),
                             quests: filteredQuests.filter { $0.recurringCadence == nil })
            }
        }
    }

    // Renders a titled section of quest rows. Renders nothing when the list is
    // empty, so sections for cadences the user hasn't created stay hidden.
    @ViewBuilder
    private func questSection(_ title: String, quests: [Quest]) -> some View {
        if !quests.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                Text(title.uppercased())
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                    .kerning(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
    }

    @ViewBuilder
    private func emptyState(icon: SemanticIcon, message: String) -> some View {
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
                if filter == .quests { showAddQuest   = true }
                else                 { showAddChoice  = true }
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
    let activity:        Activity
    let isActive:        Bool
    // True when any session is running (not just this activity's).
    // Burn-down is hidden while any session is active — showing "X h left"
    // on an idle spender while a different spender is draining the balance
    // gives a misleading number (the balance will be lower when that session stops).
    let anySessionActive: Bool
    let debtAmount:      Double
    let balance:         Double
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
              !anySessionActive,
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
                            ratePerMinute.formatted(.number.precision(.fractionLength(0...1)))))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                if let secs = burndownSeconds {
                    Text(String(format: lBundle.l("row.activity.burndown"), formatDuration(secs)))
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                }
                if debtAmount > 0 {
                    Text(String(format: lBundle.l("row.activity.debt"),
                                debtAmount.formatted(.number.precision(.fractionLength(0...1)))))
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
                HStack(spacing: theme.spacing.sm) {
                    Text(String(format: lBundle.l("row.quest.payoff"),
                                quest.payoffCredits.formatted(.number.precision(.fractionLength(0...1)))))
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.positive)
                    if let cadence = quest.recurringCadence {
                        Text(lBundle.l(cadence.labelKey))
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                            .padding(.horizontal, theme.spacing.sm)
                            .padding(.vertical, 2)
                            .background(theme.colors.surface)
                            .clipShape(Capsule())
                            .shadow(color: theme.colors.shadowLight, radius: 2, x: -1, y: -1)
                            .shadow(color: theme.colors.shadowDark,  radius: 2, x:  1, y:  1)
                    }
                }
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
