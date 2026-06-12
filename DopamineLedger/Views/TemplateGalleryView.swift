// TemplateGalleryView.swift
// Browsable catalogue of pre-built activity templates grouped by category.
// Presented as a sheet; tapping a template pushes AddActivityView pre-filled
// via a NavigationStack, keeping Cancel/Save inside the same sheet surface.

import SwiftUI

struct TemplateGalleryView: View {
    @Environment(\.dismiss)        private var dismiss
    @Environment(\.theme)          private var theme
    @Environment(\.languageBundle) private var lBundle

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                galleryHeader

                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacing.xl) {
                        ForEach(ActivityCategory.allCases, id: \.self) { category in
                            let templates = ActivityTemplate.catalog.filter { $0.category == category }
                            if !templates.isEmpty {
                                categorySection(category: category, templates: templates)
                            }
                        }
                    }
                    .padding(.horizontal, theme.spacing.lg)
                    .padding(.vertical,   theme.spacing.lg)
                }
            }
            .background(theme.colors.background.ignoresSafeArea())
            // AddActivityView pushed here; onSaved dismisses this whole sheet.
            .navigationDestination(for: ActivityTemplate.self) { template in
                AddActivityView(mode: .fromTemplate(template), onSaved: { dismiss() })
                    .toolbar(.hidden, for: .navigationBar)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationBackground(theme.colors.background)
    }

    // MARK: - Header

    private var galleryHeader: some View {
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
            Text(lBundle.l("template.gallery.title"))
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.textPrimary)
        )
        .padding(.horizontal, theme.spacing.lg)
        .padding(.top,        theme.spacing.md)
        .padding(.bottom,     theme.spacing.sm)
    }

    // MARK: - Section

    @ViewBuilder
    private func categorySection(category: ActivityCategory, templates: [ActivityTemplate]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text(lBundle.l(category.labelKey).uppercased())
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .kerning(2)

            VStack(spacing: theme.spacing.sm) {
                ForEach(templates) { template in
                    NavigationLink(value: template) {
                        TemplateRow(template: template)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - TemplateRow

private struct TemplateRow: View {
    @Environment(\.theme) private var theme
    // Needed so the rate string follows the in-app language picker (every other
    // rate display in the app routes through lBundle); mirrors ActivityRow.
    @Environment(\.languageBundle) private var lBundle
    let template: ActivityTemplate

    private var iconColor: Color {
        template.kind == .charger ? theme.colors.positive : theme.colors.negative
    }

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            ZStack {
                Circle()
                    .fill(theme.colors.surface)
                    .frame(width: 44, height: 44)
                    .shadow(color: theme.colors.shadowLight, radius: 6, x: -3, y: -3)
                    .shadow(color: theme.colors.shadowDark,  radius: 6, x:  3, y:  3)
                IconResolver.activityIconImage(named: template.iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(template.name)
                    .font(theme.typography.bodyStrong)
                    .foregroundStyle(theme.colors.textPrimary)
                // Match every other rate display: localised format string +
                // the shared .abbreviated formatter (K/M/B), instead of a raw
                // "%.1f cr/min" that bypassed both localisation and formatting.
                Text(String(format: lBundle.l("session.rate"), template.ratePerMinute.abbreviated))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }

            Spacer()

            theme.icon(.forward)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.colors.textSecondary.opacity(0.5))
        }
        .padding(theme.spacing.lg)
        .neuCard()
    }
}

#Preview {
    TemplateGalleryView()
        .environment(\.theme, NeuTheme())
}
