// ActivityMenuView.swift
// Pre-session sheet for a spender that has outstanding debt. Lets the user
// pay down this activity's debt before (or instead of) starting a session.
//
// Why intercept only spenders with debt? Chargers can't accrue debt by
// design (SessionMath never produces it for them), and a clean spender
// shouldn't add a tap to the common path. So the parent (ActivityListView)
// only presents this view when there's debt to surface.

import SwiftUI
import SwiftData

struct ActivityMenuView: View {
    @Environment(\.theme)        private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    let activity: Activity
    // Called after dismissal when the user picks "Start session". The parent
    // owns the session-creation logic (notifications, active-session state),
    // so we just signal intent.
    let onStartSession: () -> Void

    // Pulls this activity's unpaid debt rows. Updates live as Repay zeros them.
    @Query                            private var allDebts: [ActivityDebt]
    @Query                            private var ledgers:  [Ledger]

    private var ledger: Ledger? { ledgers.first }

    private var rows: [ActivityDebt] {
        allDebts
            .filter { $0.activityId == activity.id && $0.amount > 0 }
            .sorted { $0.createdAt < $1.createdAt }
    }
    private var totalDebt: Double { rows.reduce(0) { $0 + $1.amount } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.xxl) {

                    header

                    if totalDebt > 0 {
                        debtCard
                        actionRow
                    } else {
                        // Debt was cleared while the sheet was open — collapse
                        // to a single CTA so the user can leave or proceed.
                        clearedState
                        startSessionButton
                    }
                }
                .padding(theme.spacing.lg)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Activity")
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

    private var header: some View {
        VStack(spacing: theme.spacing.md) {
            ZStack {
                Circle()
                    .fill(theme.colors.surface)
                    .frame(width: 72, height: 72)
                    .shadow(color: theme.colors.shadowLight, radius: 10, x: -6, y: -6)
                    .shadow(color: theme.colors.shadowDark,  radius: 10, x:  6, y:  6)
                theme.icon(.spender)
                    .font(.system(size: 28))
                    .foregroundStyle(theme.colors.negative)
            }
            Text(activity.name)
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.textPrimary)
            Text("\(activity.ratePerSecond * 60, format: .number.precision(.fractionLength(1))) cr / min")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
        }
    }

    private var debtCard: some View {
        VStack(spacing: theme.spacing.xs) {
            Text("CREDITS OWED")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .kerning(2)
            Text(totalDebt, format: .number.precision(.fractionLength(1)))
                .font(theme.typography.display)
                .foregroundStyle(theme.colors.negative)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacing.xl)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
        .shadow(color: theme.colors.shadowLight, radius: 10, x: -6, y: -6)
        .shadow(color: theme.colors.shadowDark,  radius: 10, x:  6, y:  6)
    }

    private var actionRow: some View {
        let canRepay = (ledger?.balance ?? 0) > 0
        return VStack(spacing: theme.spacing.md) {
            // Repay — primary action when there's debt to clear.
            Button(action: repay) {
                Text(canRepay ? "Repay (uses balance)" : "Repay — need balance")
                    .font(theme.typography.button.weight(.semibold))
                    .foregroundStyle(canRepay ? Color.white : theme.colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacing.lg)
                    .background(canRepay ? theme.colors.accent : theme.colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
                    .shadow(color: theme.colors.shadowDark.opacity(canRepay ? 1 : 0),
                            radius: 8, x: 4, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!canRepay)

            // Secondary — start anyway, accepting the 2× debt overhead.
            // Neumorphic raised surface (not filled accent) so Repay reads
            // as the recommended action.
            Button {
                dismiss()
                onStartSession()
            } label: {
                Text("Start session anyway")
                    .font(theme.typography.button.weight(.semibold))
                    .foregroundStyle(theme.colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacing.md)
                    .background(theme.colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
                    .shadow(color: theme.colors.shadowLight, radius: 6, x: -4, y: -4)
                    .shadow(color: theme.colors.shadowDark,  radius: 6, x:  4, y:  4)
            }
            .buttonStyle(.plain)
        }
    }

    private var clearedState: some View {
        VStack(spacing: theme.spacing.md) {
            theme.icon(.balance)
                .font(.system(size: 28))
                .foregroundStyle(theme.colors.positive)
            Text("All debt cleared.")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.lg)
    }

    private var startSessionButton: some View {
        Button {
            dismiss()
            onStartSession()
        } label: {
            Text("Start session")
                .font(theme.typography.button.weight(.bold))
                .kerning(4)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacing.lg)
                .background(theme.colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
                .shadow(color: theme.colors.shadowDark, radius: 8, x: 4, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Repay logic
    //
    // Same shape as DebtView.repay — RepayMath.apply for the amount,
    // RepayMath.split for the per-row distribution. Kept inline (rather
    // than extracted to a service) because the two call sites are small,
    // and pulling them apart now would obscure where mutations happen.

    private func repay() {
        guard let ledger = ledger else { return }
        let outcome = RepayMath.apply(currentBalance: ledger.balance, totalDebt: totalDebt)
        guard outcome.amountRepaid > 0 else { return }

        ledger.balance   = outcome.newBalance
        ledger.updatedAt = Date()

        let newAmounts = RepayMath.split(outcome.amountRepaid, across: rows.map(\.amount))
        for (row, newAmount) in zip(rows, newAmounts) {
            row.amount = newAmount
        }
    }
}
