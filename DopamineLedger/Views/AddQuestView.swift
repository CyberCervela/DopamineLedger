// AddQuestView.swift
// Sheet for creating or editing a Quest.
//
// Mirrors AddActivityView's structure — same NavigationStack chrome,
// same neuField + label helpers, same Mode-based init pattern. Keeping
// the shapes parallel means a change to one is easy to mirror in the other.

import SwiftUI
import SwiftData

enum QuestMode {
    case create
    case edit(Quest)
}

struct AddQuestView: View {
    @Environment(\.theme)        private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    let mode: QuestMode

    @State private var name:   String
    @State private var payoff: String  // String so the decimal field is editable

    init(mode: QuestMode = .create) {
        self.mode = mode
        switch mode {
        case .create:
            _name   = State(initialValue: "")
            _payoff = State(initialValue: "50")
        case .edit(let q):
            _name   = State(initialValue: q.name)
            _payoff = State(initialValue: String(format: "%.0f", q.payoffCredits))
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
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.xl) {
                    neuField(label: "NAME") {
                        TextField("e.g. File tax declaration", text: $name)
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textPrimary)
                            .autocorrectionDisabled()
                    }

                    neuField(label: "PAYOFF — CREDITS ON COMPLETION") {
                        HStack {
                            TextField("50", text: $payoff)
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.textPrimary)
                                .keyboardType(.numberPad)
                            Spacer()
                            Text("credits")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                    }

                    // Plain-language hint — mirrors the rate hint in AddActivityView.
                    if let payoff = parsedPayoff {
                        Text("Completing this quest will add \(payoff, format: .number.precision(.fractionLength(0))) credits to your balance.")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.positive)
                            .multilineTextAlignment(.center)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(theme.spacing.lg)
                .animation(.easeInOut(duration: 0.2), value: parsedPayoff != nil)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(isEditing ? "Edit Quest" : "New Quest")
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .font(theme.typography.bodyStrong)
                        .foregroundStyle(isValid ? theme.colors.accent : theme.colors.textSecondary.opacity(0.5))
                        .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - Reusable pieces (mirrors AddActivityView — kept local on purpose
    // so each sheet stays standalone; promote to a shared helper if a third
    // sheet needs the same chrome.)

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

    // MARK: - Save

    private func save() {
        guard isValid, let payoff = parsedPayoff else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .create:
            context.insert(Quest(name: trimmed, payoffCredits: payoff))
        case .edit(let quest):
            quest.name          = trimmed
            quest.payoffCredits = payoff
        }
        dismiss()
    }
}

#Preview {
    AddQuestView(mode: .create)
        .environment(\.theme, NeuTheme())
        .modelContainer(for: [Quest.self], inMemory: true)
}
