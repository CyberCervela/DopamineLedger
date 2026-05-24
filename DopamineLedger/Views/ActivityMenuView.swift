// ActivityMenuView.swift
// Pre-session sheet for a spender that needs attention before starting.
// Surfaces one of two situations:
//   1. Outstanding debt — show it and offer Repay before / instead of
//      starting a session.
//   2. Zero balance with no debt yet — warn that starting now will
//      immediately accrue debt at the 2× penalty rate.
//
// Chargers and clean spenders (balance > 0, no debt) skip this view and
// go straight to SessionView — no friction added to the common path.

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
    private var balance:   Double { ledger?.balance ?? 0 }

    // Display state — the view shows one of three centres based on the
    // current data. Computed live so it transitions naturally when the
    // user repays inside the sheet.
    private enum Centre {
        case debt
        case zeroBalanceWarning
        case cleared
    }
    private var centre: Centre {
        if totalDebt > 0          { return .debt }
        if balance   <= 0          { return .zeroBalanceWarning }
        return .cleared
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.xxl) {

                    header

                    switch centre {
                    case .debt:
                        debtCard
                        actionRow
                    case .zeroBalanceWarning:
                        zeroBalanceCard
                        startSessionButton
                    case .cleared:
                        // Debt was cleared while the sheet was open and there
                        // is balance to spend — collapse to a single CTA.
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

    // Zero-balance warning — same visual weight as the debt card so the
    // user reads it as "this is the thing you should know". The body text
    // explains the consequence ("2× rate") plainly rather than relying on
    // the user to remember the rule.
    private var zeroBalanceCard: some View {
        VStack(spacing: theme.spacing.sm) {
            Text("BALANCE")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .kerning(2)
            Text(0, format: .number.precision(.fractionLength(1)))
                .font(theme.typography.display)
                .foregroundStyle(theme.colors.negative)
            Text("Starting this spender now will accrue debt at 2× rate.")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.negative)
                .multilineTextAlignment(.center)
                .padding(.top, theme.spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacing.xl)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
        .shadow(color: theme.colors.shadowLight, radius: 10, x: -6, y: -6)
        .shadow(color: theme.colors.shadowDark,  radius: 10, x:  6, y:  6)
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

    // Filled accent for the "clean state, just start" case; raised
    // neumorphic (secondary weight) for the zero-balance warning so the
    // CTA doesn't read like a recommendation when we're actively flagging
    // a consequence.
    private var startSessionButton: some View {
        let filled = (centre == .cleared)
        return Button {
            dismiss()
            onStartSession()
        } label: {
            Text(filled ? "Start session" : "Start session anyway")
                .font(theme.typography.button.weight(filled ? .bold : .semibold))
                .kerning(filled ? 4 : 2)
                .foregroundStyle(filled ? Color.white : theme.colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, filled ? theme.spacing.lg : theme.spacing.md)
                .background(filled ? theme.colors.accent : theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
                .shadow(color: filled ? theme.colors.shadowDark  : theme.colors.shadowLight,
                        radius: filled ? 8 : 6,
                        x:      filled ? 4 : -4,
                        y:      filled ? 4 : -4)
                .shadow(color: filled ? .clear : theme.colors.shadowDark,
                        radius: 6, x: 4, y: 4)
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
