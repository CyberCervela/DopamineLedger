// BalanceCard.swift
// The pinned-top card showing the global credit balance and debt summary.
//
// Design: a neumorphic raised card — same background color as the screen,
// extruded purely by the dual-shadow technique (light top-left, dark bottom-right).
// No border, no fill difference from the parent background.

import SwiftUI
import SwiftData

struct BalanceCard: View {
    @Environment(\.theme) private var theme

    let balance:   Double
    let totalDebt: Double

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {

            // Label row
            HStack(spacing: theme.spacing.xs) {
                theme.icon(.balance)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary)
                Text("BALANCE")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                    .kerning(2)
            }

            // The big number — the primary focus of the home screen.
            // .contentTransition animates digit changes when balance updates.
            Text(balance, format: .number.precision(.fractionLength(1)))
                .font(theme.typography.display)
                .foregroundStyle(theme.colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .contentTransition(.numericText())
                .padding(.vertical, theme.spacing.sm)

            // Debt row — only visible when outstanding debt exists.
            // Red color is the only red on the home screen; draws the eye
            // without being aggressive when there's nothing to pay back.
            if totalDebt > 0 {
                HStack(spacing: theme.spacing.xs) {
                    theme.icon(.debt)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.colors.negative)
                    Text("\(totalDebt, format: .number.precision(.fractionLength(1))) credits in debt")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.negative)
                    Spacer()
                }
                .padding(.top, theme.spacing.xxs)
            }
        }
        .padding(theme.spacing.xl)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
        // Neumorphic dual shadow: white highlight top-left, cool-gray shadow bottom-right.
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
