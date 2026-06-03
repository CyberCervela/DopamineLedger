// ActivityActionMenuView.swift
// Neumorphic long-press action sheet — shown when the user holds an activity
// or quest row. Two options: Edit (opens the editor form) or Remove/Delete
// (feeds the parent's confirmation alert). Follows the ActivityAddChoiceView
// pattern: same header shape, same neuCard cards, same dismiss flow.

import SwiftUI

struct ActivityActionMenuView: View {
    @Environment(\.theme)          private var theme
    @Environment(\.dismiss)        private var dismiss
    @Environment(\.languageBundle) private var lBundle

    let name:             String
    let editTitleKey:     String
    let editSubtitleKey:  String
    let removeTitleKey:   String
    let removeSubtitleKey: String
    let onEdit:   () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: theme.spacing.md) {
                actionCard(
                    iconName:      "pencil",
                    iconColor:     theme.colors.accent,
                    titleKey:      editTitleKey,
                    subtitleKey:   editSubtitleKey,
                    isDestructive: false,
                    action:        { dismiss(); onEdit() }
                )
                actionCard(
                    iconName:      "trash",
                    iconColor:     theme.colors.negative,
                    titleKey:      removeTitleKey,
                    subtitleKey:   removeSubtitleKey,
                    isDestructive: true,
                    action:        { dismiss(); onRemove() }
                )
            }
            .padding(theme.spacing.lg)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .presentationBackground(theme.colors.background)
        .presentationDetents([.height(280)])
    }

    // MARK: - Header
    // Title is an overlay so it centres across the full width without a
    // mirror button on the trailing side (a mirror renders a ghost pill — see
    // LESSONS_LEARNED.md §12).
    private var header: some View {
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
            Text(name)
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
        )
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top,        theme.spacing.md)
        .padding(.bottom,     theme.spacing.sm)
    }

    // MARK: - Action card

    @ViewBuilder
    private func actionCard(
        iconName:      String,
        iconColor:     Color,
        titleKey:      String,
        subtitleKey:   String,
        isDestructive: Bool,
        action:        @escaping () -> Void
    ) -> some View {
        Button(action: action) {
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
                        .foregroundStyle(isDestructive ? theme.colors.negative : theme.colors.textPrimary)
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
            .neuCard()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ActivityActionMenuView(
        name:              "Deep Work",
        editTitleKey:      "activity.action.edit.title",
        editSubtitleKey:   "activity.action.edit.subtitle",
        removeTitleKey:    "activity.action.remove.title",
        removeSubtitleKey: "activity.action.remove.subtitle",
        onEdit:   {},
        onRemove: {}
    )
    .environment(\.theme, NeuTheme())
}
