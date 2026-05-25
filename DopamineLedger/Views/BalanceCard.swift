// BalanceCard.swift
// The pinned-top card showing the global credit balance and debt summary.

import SwiftUI
import SwiftData

struct BalanceCard: View {
    @Environment(\.theme)          private var theme
    @Environment(\.languageBundle) private var lBundle

    let balance:    Double
    let totalDebt:  Double
    var onDebtTap:  (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {

            HStack(spacing: theme.spacing.xs) {
                theme.icon(.balance)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary)
                Text(lBundle.l("balance.label"))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                    .kerning(2)
            }

            Text(balance, format: .number.precision(.fractionLength(1)))
                .font(theme.typography.display)
                .foregroundStyle(theme.colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .contentTransition(.numericText())
                .padding(.vertical, theme.spacing.sm)

            if totalDebt > 0 {
                Button {
                    onDebtTap?()
                } label: {
                    HStack(spacing: theme.spacing.xs) {
                        theme.icon(.debt)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.colors.negative)
                        Text(String(format: lBundle.l("balance.in_debt"),
                                    totalDebt.formatted(.number.precision(.fractionLength(1)))))
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.negative)
                        Spacer()
                        if onDebtTap != nil {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(theme.colors.negative.opacity(0.6))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onDebtTap == nil)
                .padding(.top, theme.spacing.xxs)
            }
        }
        .padding(theme.spacing.xl)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
        .shadow(color: theme.colors.shadowLight, radius: 10, x: -6, y: -6)
        .shadow(color: theme.colors.shadowDark,  radius: 10, x:  6, y:  6)
    }
}

#Preview {
    VStack {
        BalanceCard(balance: 1_234.5, totalDebt: 0)
        BalanceCard(balance: 42.0,    totalDebt: 88.5)
    }
    .padding()
    .background(Color(red: 0.91, green: 0.91, blue: 0.933))
    .environment(\.theme, NeuTheme())
}
