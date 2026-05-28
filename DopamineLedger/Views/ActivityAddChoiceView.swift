// ActivityAddChoiceView.swift
// Neumorphic "Add Activity" entry sheet — gives the user two clearly
// described paths before opening the full form or the template gallery.
// The onSelect callback fires with the chosen path; the caller dismisses
// this sheet and opens the appropriate next sheet via onDismiss.

import SwiftUI

struct ActivityAddChoiceView: View {
    @Environment(\.theme)          private var theme
    @Environment(\.dismiss)        private var dismiss
    @Environment(\.languageBundle) private var lBundle

    let onSelect: (AddActivityPath) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: theme.spacing.lg) {
                    choiceCard(
                        iconName:    "star.fill",
                        iconColor:   theme.colors.accent,
                        titleKey:    "activity.add.from.template",
                        subtitleKey: "activity.add.from.template.hint",
                        path:        .fromTemplate
                    )
                    choiceCard(
                        iconName:    "pencil",
                        iconColor:   theme.colors.textSecondary,
                        titleKey:    "activity.add.create.own",
                        subtitleKey: "activity.add.create.own.hint",
                        path:        .createOwn
                    )
                }
                .padding(theme.spacing.lg)
            }
        }
        .background(theme.colors.background.ignoresSafeArea())
        .presentationBackground(theme.colors.background)
    }

    // MARK: - Header

    private var header: some View {
        // Title is an overlay so it centres across the full header width
        // without a mirror button on the trailing side.
        HStack {
            NeuTextButton(
                title:      lBundle.l("common.cancel"),
                font:       theme.typography.body,
                foreground: theme.colors.textSecondary,
                action:     { dismiss() }
            )
            Spacer()
        }
        .overlay(
            Text(lBundle.l("activity.add.dialog.title"))
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.textPrimary)
        )
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top,        theme.spacing.md)
        .padding(.bottom,     theme.spacing.sm)
    }

    // MARK: - Choice card

    @ViewBuilder
    private func choiceCard(
        iconName:    String,
        iconColor:   Color,
        titleKey:    String,
        subtitleKey: String,
        path:        AddActivityPath
    ) -> some View {
        Button {
            onSelect(path)
        } label: {
            HStack(spacing: theme.spacing.md) {
                ZStack {
                    Circle()
                        .fill(theme.colors.surface)
                        .frame(width: 44, height: 44)
                        .shadow(color: theme.colors.shadowLight, radius: 6, x: -3, y: -3)
                        .shadow(color: theme.colors.shadowDark,  radius: 6, x:  3, y:  3)
                    IconResolver.activityIconImage(named: iconName)
                        .font(.system(size: 16))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                    Text(lBundle.l(titleKey))
                        .font(theme.typography.bodyStrong)
                        .foregroundStyle(theme.colors.textPrimary)
                    Text(lBundle.l(subtitleKey))
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                theme.icon(.forward)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary.opacity(0.5))
            }
            .padding(theme.spacing.lg)
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
            .shadow(color: theme.colors.shadowLight, radius: 8, x: -5, y: -5)
            .shadow(color: theme.colors.shadowDark,  radius: 8, x:  5, y:  5)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ActivityAddChoiceView { _ in }
        .environment(\.theme, NeuTheme())
}
