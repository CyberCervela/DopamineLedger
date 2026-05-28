// ActivityMenuView.swift
// Pre-session sheet for a spender that needs attention before starting.

import SwiftUI
import SwiftData

struct ActivityMenuView: View {
    @Environment(\.theme)          private var theme
    @Environment(\.modelContext)   private var context
    @Environment(\.dismiss)        private var dismiss
    @Environment(\.languageBundle) private var lBundle

    let activity: Activity
    let onStartSession: () -> Void

    @AppStorage("chillMode") private var chillMode: Bool = false

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

    private enum Centre { case debt, zeroBalanceWarning, cleared }
    private var centre: Centre {
        if totalDebt > 0 { return .debt }
        if balance   <= 0 { return .zeroBalanceWarning }
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
                    Text(lBundle.l("activitymenu.title"))
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
            Text(String(format: lBundle.l("session.rate"),
                        (activity.ratePerSecond * 60).formatted(.number.precision(.fractionLength(0...1)))))
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
        }
    }

    private var debtCard: some View {
        VStack(spacing: theme.spacing.xs) {
            Text(lBundle.l("activitymenu.credits_owed_label"))
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .kerning(2)
            Text(totalDebt, format: .number.precision(.fractionLength(0...1)))
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
            Button(action: repay) {
                Text(lBundle.l(canRepay ? "activitymenu.repay.can" : "activitymenu.repay.cannot"))
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

            if chillMode {
                Button {
                    dismiss()
                    onStartSession()
                } label: {
                    Text(lBundle.l("activitymenu.start_anyway"))
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
    }

    private var zeroBalanceCard: some View {
        VStack(spacing: theme.spacing.sm) {
            Text(lBundle.l("activitymenu.balance_label"))
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .kerning(2)
            Text(0, format: .number.precision(.fractionLength(0...1)))
                .font(theme.typography.display)
                .foregroundStyle(theme.colors.negative)
            Text(lBundle.l("activitymenu.zero_warning"))
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
            Text(lBundle.l("activitymenu.cleared"))
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.lg)
    }

    private var startSessionButton: some View {
        let filled = (centre == .cleared)
        return Button {
            dismiss()
            onStartSession()
        } label: {
            Text(lBundle.l(filled ? "activitymenu.start_session" : "activitymenu.start_anyway"))
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

    private func repay() {
        guard let ledger = ledger else { return }
        let outcome = RepayMath.apply(currentBalance: ledger.balance, totalDebt: totalDebt)
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
