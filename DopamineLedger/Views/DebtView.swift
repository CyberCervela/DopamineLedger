// DebtView.swift
// Sheet for repaying outstanding ActivityDebt rows from the global balance.

import SwiftUI
import SwiftData

struct DebtView: View {
    @Environment(\.theme)          private var theme
    @Environment(\.modelContext)   private var context
    @Environment(\.dismiss)        private var dismiss
    @Environment(\.languageBundle) private var lBundle

    @Query(filter: #Predicate<ActivityDebt> { $0.amount > 0 })
                                      private var debts:      [ActivityDebt]
    @Query                            private var activities: [Activity]
    @Query                            private var ledgers:    [Ledger]

    private var ledger: Ledger? { ledgers.first }

    private var debtsByActivity: [(activity: Activity, total: Double)] {
        let totals = Dictionary(grouping: debts, by: \.activityId)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        return totals.compactMap { (id, total) -> (Activity, Double)? in
            guard let activity = activities.first(where: { $0.id == id }) else { return nil }
            return (activity, total)
        }
        .sorted { $0.0.name < $1.0.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.xl) {
                    balanceHeader
                    if debtsByActivity.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: theme.spacing.md) {
                            ForEach(debtsByActivity, id: \.activity.id) { entry in
                                debtRow(activity: entry.activity, total: entry.total)
                            }
                        }
                    }
                }
                .padding(theme.spacing.lg)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(lBundle.l("debt.title"))
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(lBundle.l("common.done")) { dismiss() }
                        .font(theme.typography.bodyStrong)
                        .foregroundStyle(theme.colors.accent)
                }
            }
        }
    }

    private var balanceHeader: some View {
        VStack(spacing: theme.spacing.xs) {
            Text(lBundle.l("debt.available_balance"))
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .kerning(2)
            Text(ledger?.balance ?? 0, format: .number.precision(.fractionLength(1)))
                .font(theme.typography.display)
                .foregroundStyle(theme.colors.textPrimary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacing.xl)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
        .shadow(color: theme.colors.shadowLight, radius: 10, x: -6, y: -6)
        .shadow(color: theme.colors.shadowDark,  radius: 10, x:  6, y:  6)
    }

    @ViewBuilder
    private func debtRow(activity: Activity, total: Double) -> some View {
        let canRepay = (ledger?.balance ?? 0) > 0

        HStack(spacing: theme.spacing.md) {
            ZStack {
                Circle()
                    .fill(theme.colors.surface)
                    .frame(width: 44, height: 44)
                    .shadow(color: theme.colors.shadowLight, radius: 6, x: -3, y: -3)
                    .shadow(color: theme.colors.shadowDark,  radius: 6, x:  3, y:  3)
                theme.icon(activity.kind == .charger ? .charger : .spender)
                    .font(.system(size: 16))
                    .foregroundStyle(theme.colors.negative)
            }

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(activity.name)
                    .font(theme.typography.bodyStrong)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(String(format: lBundle.l("debt.credits_owed"),
                            total.formatted(.number.precision(.fractionLength(1)))))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.negative)
            }

            Spacer()

            Button { repay(activityId: activity.id) } label: {
                Text(lBundle.l("debt.repay_button"))
                    .font(theme.typography.button.weight(.semibold))
                    .foregroundStyle(canRepay ? Color.white : theme.colors.textSecondary)
                    .padding(.horizontal, theme.spacing.lg)
                    .padding(.vertical,   theme.spacing.sm)
                    .background(canRepay ? theme.colors.accent : theme.colors.surface)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canRepay)
        }
        .padding(theme.spacing.lg)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
        .shadow(color: theme.colors.shadowLight, radius: 8, x: -5, y: -5)
        .shadow(color: theme.colors.shadowDark,  radius: 8, x:  5, y:  5)
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacing.lg) {
            theme.icon(.balance)
                .font(.system(size: 36))
                .foregroundStyle(theme.colors.textSecondary.opacity(0.5))
            Text(lBundle.l("debt.empty"))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.xxl)
    }

    private func repay(activityId: UUID) {
        guard let ledger = ledger else { return }
        let rows  = debts
            .filter { $0.activityId == activityId }
            .sorted { $0.createdAt < $1.createdAt }
        let total = rows.reduce(0) { $0 + $1.amount }

        let outcome = RepayMath.apply(currentBalance: ledger.balance, totalDebt: total)
        guard outcome.amountRepaid > 0 else { return }

        ledger.balance   = outcome.newBalance
        ledger.updatedAt = Date()

        let newAmounts = RepayMath.split(outcome.amountRepaid, across: rows.map(\.amount))
        let now = Date()
        for (row, newAmount) in zip(rows, newAmounts) {
            row.amount = newAmount
            if newAmount == 0 { row.repaidAt = now }
        }
    }
}

#Preview {
    DebtView()
        .environment(\.theme, NeuTheme())
        .modelContainer(for: [Activity.self, Session.self, ActivityDebt.self, Ledger.self, Quest.self],
                        inMemory: true)
}
