// DebtView.swift
// Sheet for repaying outstanding ActivityDebt rows from the global balance.
//
// One row per activity (a single activity can have multiple debt rows
// because each spender overrun creates a new row). We sum them for the
// display and distribute the repayment back across those rows
// oldest-first when the user taps Repay.

import SwiftUI
import SwiftData

struct DebtView: View {
    @Environment(\.theme)        private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    // Only unpaid debts — same predicate as the home screen, so the row
    // disappears as soon as it's zeroed.
    @Query(filter: #Predicate<ActivityDebt> { $0.amount > 0 })
                                      private var debts:      [ActivityDebt]
    @Query                            private var activities: [Activity]
    @Query                            private var ledgers:    [Ledger]

    private var ledger: Ledger? { ledgers.first }

    // Group debt amounts by activityId so each activity gets one row.
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

                    // Current balance — prominent so the user sees the pool
                    // they're spending from before they tap Repay.
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
                    Text("Debt")
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(theme.typography.bodyStrong)
                        .foregroundStyle(theme.colors.accent)
                }
            }
        }
    }

    // MARK: - Subviews

    private var balanceHeader: some View {
        VStack(spacing: theme.spacing.xs) {
            Text("AVAILABLE BALANCE")
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
        // Repay is enabled only when the balance has something to spend.
        // RepayMath would handle the zero case correctly anyway, but the
        // button being disabled makes the state obvious.
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
                Text("\(total, format: .number.precision(.fractionLength(1))) credits owed")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.negative)
            }

            Spacer()

            Button { repay(activityId: activity.id) } label: {
                Text("Repay")
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
            Text("No outstanding debt.")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.xxl)
    }

    // MARK: - Repay logic

    // Pay down this activity's debt using as much of the current balance as
    // possible. RepayMath.apply returns the moved amount; RepayMath.split
    // then distributes it across the activity's debt rows oldest-first.
    // Rows that hit zero stop appearing thanks to the @Query predicate.
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
        for (row, newAmount) in zip(rows, newAmounts) {
            row.amount = newAmount
        }
    }
}

#Preview {
    DebtView()
        .environment(\.theme, NeuTheme())
        .modelContainer(for: [Activity.self, Session.self, ActivityDebt.self, Ledger.self, Quest.self],
                        inMemory: true)
}
