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

    // Mirrors the `balance` prop but is only ever mutated inside withAnimation,
    // so .contentTransition(.numericText()) sees an animated change and rolls
    // the digits. Updating the prop directly (no animation context) would make
    // the number jump rather than roll.
    @State private var animatedBalance: Double = 0
    // nil = resting state (textPrimary). Set to positive/negative on balance
    // change, then cleared after a short delay to fade back to neutral.
    @State private var flashColor: Color?

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

            Text(animatedBalance.abbreviated)
                .font(theme.typography.display)
                .foregroundStyle(flashColor ?? theme.colors.textPrimary)
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
                                    totalDebt.abbreviated))
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
        .neuCard(.lg)
        .onAppear {
            // Set without animation so the number doesn't roll on first render.
            animatedBalance = balance
        }
        .onChange(of: balance) { oldValue, newValue in
            let target = newValue > oldValue ? theme.colors.positive : theme.colors.negative
            // Roll the digits and flash the colour in the same animation so they
            // are perfectly synchronised.
            withAnimation(.easeInOut(duration: 0.4)) {
                animatedBalance = newValue
                flashColor = target
            }
            Task {
                try? await Task.sleep(for: .seconds(0.7))
                withAnimation(.easeOut(duration: 0.5)) { flashColor = nil }
            }
        }
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
