// AddQuestView.swift
// Sheet for creating or editing a Quest.

import SwiftUI
import SwiftData

enum QuestMode {
    case create
    case edit(Quest)
}

struct AddQuestView: View {
    @Environment(\.theme)          private var theme
    @Environment(\.modelContext)   private var context
    @Environment(\.dismiss)        private var dismiss
    @Environment(\.languageBundle) private var lBundle

    let mode: QuestMode

    @State private var name:     String
    @State private var payoff:   String
    @State private var category: ActivityCategory

    init(mode: QuestMode = .create) {
        self.mode = mode
        switch mode {
        case .create:
            _name     = State(initialValue: "")
            _payoff   = State(initialValue: "50")
            _category = State(initialValue: .other)
        case .edit(let q):
            _name     = State(initialValue: q.name)
            _payoff   = State(initialValue: String(format: "%.0f", q.payoffCredits))
            _category = State(initialValue: q.category ?? .other)
        }
    }

    private var isEditing: Bool { if case .edit = mode { true } else { false } }

    private var parsedPayoff: Double? {
        guard let v = Double(payoff), v > 0 else { return nil }
        return v
    }
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && parsedPayoff != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                NeuTextButton(
                    title:      lBundle.l("common.cancel"),
                    font:       theme.typography.body,
                    foreground: theme.colors.textSecondary,
                    action:     { dismiss() }
                )
                Spacer()
                Text(lBundle.l(isEditing ? "quest.edit" : "quest.new"))
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
                NeuTextButton(
                    title:      lBundle.l("common.save"),
                    font:       theme.typography.bodyStrong,
                    foreground: isValid ? theme.colors.accent : theme.colors.textSecondary.opacity(0.5),
                    action:     { save() }
                )
                .disabled(!isValid)
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.top,        theme.spacing.md)
            .padding(.bottom,     theme.spacing.sm)

            ScrollView {
                VStack(spacing: theme.spacing.xl) {
                    neuField(label: lBundle.l("quest.field.name").uppercased()) {
                        TextField(lBundle.l("quest.name.placeholder"), text: $name)
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textPrimary)
                            .autocorrectionDisabled()
                    }

                    neuField(label: lBundle.l("quest.field.payoff").uppercased()) {
                        HStack {
                            TextField("50", text: $payoff)
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.textPrimary)
                                .keyboardType(.numberPad)
                            Spacer()
                            Text(lBundle.l("quest.payoff_suffix"))
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                    }

                    // Category picker — places this quest in a life area on the dashboard.
                    VStack(alignment: .leading, spacing: theme.spacing.sm) {
                        label(lBundle.l("quest.field.category").uppercased())
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: theme.spacing.md), count: 3),
                            spacing: theme.spacing.md
                        ) {
                            ForEach(ActivityCategory.allCases, id: \.self) { cat in
                                categoryButton(cat)
                            }
                        }
                    }

                    if let payoff = parsedPayoff {
                        Text(String(format: lBundle.l("quest.hint"),
                                    payoff.formatted(.number.precision(.fractionLength(0)))))
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.positive)
                            .multilineTextAlignment(.center)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(theme.spacing.lg)
                .animation(.easeInOut(duration: 0.2), value: parsedPayoff != nil)
            }
        }
        .presentationBackground(theme.colors.background)
    }

    @ViewBuilder
    private func categoryButton(_ cat: ActivityCategory) -> some View {
        let selected = category == cat
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { category = cat }
        } label: {
            Text(lBundle.l(cat.labelKey))
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(selected ? theme.colors.accent : theme.colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacing.md)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
                .shadow(color: theme.colors.shadowLight, radius: selected ? 4 : 8,
                        x: selected ? -3 : -5, y: selected ? -3 : -5)
                .shadow(color: theme.colors.shadowDark,  radius: selected ? 4 : 8,
                        x: selected ?  3 :  5, y: selected ?  3 :  5)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.spacing.cornerRadius)
                        .strokeBorder(selected ? theme.colors.accent.opacity(0.35) : Color.clear,
                                      lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func label(_ text: String) -> some View {
        Text(text)
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.textSecondary)
            .kerning(2)
    }

    @ViewBuilder
    private func neuField<Content: View>(label labelText: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            label(labelText)
            content()
                .padding(theme.spacing.lg)
                .background(theme.colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
                .shadow(color: theme.colors.shadowLight, radius: 8, x: -5, y: -5)
                .shadow(color: theme.colors.shadowDark,  radius: 8, x:  5, y:  5)
        }
    }

    private func save() {
        guard isValid, let payoff = parsedPayoff else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .create:
            context.insert(Quest(name: trimmed, payoffCredits: payoff, category: category))
        case .edit(let quest):
            quest.name          = trimmed
            quest.payoffCredits = payoff
            quest.category      = category
        }
        dismiss()
    }
}

#Preview {
    AddQuestView(mode: .create)
        .environment(\.theme, NeuTheme())
        .modelContainer(for: [Quest.self], inMemory: true)
}
