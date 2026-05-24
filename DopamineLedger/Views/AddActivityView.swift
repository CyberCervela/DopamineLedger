// AddActivityView.swift
// Sheet for creating or editing an Activity.
//
// Mode enum keeps the same view doing double duty — the only differences
// are the title and whether save() inserts a new row or mutates an existing one.
// Initialising @State from a parameter requires the init() overload below;
// SwiftUI doesn't let you do this with default values directly.

import SwiftUI
import SwiftData

enum ActivityMode {
    case create
    case edit(Activity)
}

struct AddActivityView: View {
    @Environment(\.theme)        private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    let mode: ActivityMode

    @State private var name:          String
    @State private var kind:          ActivityKind
    @State private var ratePerMinute: String  // String so the decimal field is editable

    // initialKind is only consulted in .create mode; .edit always uses the
    // existing activity's kind. Defaults to .charger so existing call sites
    // (previews, etc.) keep working without change.
    init(mode: ActivityMode = .create, initialKind: ActivityKind = .charger) {
        self.mode = mode
        switch mode {
        case .create:
            _name          = State(initialValue: "")
            _kind          = State(initialValue: initialKind)
            _ratePerMinute = State(initialValue: "10")
        case .edit(let a):
            _name          = State(initialValue: a.name)
            _kind          = State(initialValue: a.kind)
            _ratePerMinute = State(initialValue: String(format: "%.1f", a.ratePerSecond * 60))
        }
    }

    private var isEditing: Bool { if case .edit = mode { true } else { false } }

    private var parsedRate: Double? {
        guard let v = Double(ratePerMinute), v > 0 else { return nil }
        return v
    }
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && parsedRate != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.xl) {
                    neuField(label: "NAME") {
                        TextField("e.g. Reading", text: $name)
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textPrimary)
                            .autocorrectionDisabled()
                    }

                    // Kind selector — two raised cards, selected one gets a
                    // colour-tinted border and slightly reduced shadow (pressed feel).
                    VStack(alignment: .leading, spacing: theme.spacing.sm) {
                        label("TYPE")
                        HStack(spacing: theme.spacing.md) {
                            kindCard(.charger, title: "Charger", subtitle: "earns credits")
                            kindCard(.spender, title: "Spender", subtitle: "spends credits")
                        }
                    }

                    neuField(label: "RATE — CREDITS / MIN") {
                        HStack {
                            TextField("10", text: $ratePerMinute)
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.textPrimary)
                                .keyboardType(.decimalPad)
                            Spacer()
                            Text("cr / min")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                    }

                    // Contextual hint — reminds the user what the rate means
                    // in plain language. Hides until a valid rate is entered.
                    if let rate = parsedRate {
                        let verb = kind == .charger ? "earns" : "spends"
                        Text("This activity \(verb) \(rate, format: .number.precision(.fractionLength(1))) credits per minute.")
                            .font(theme.typography.caption)
                            .foregroundStyle(kind == .charger ? theme.colors.positive : theme.colors.negative)
                            .multilineTextAlignment(.center)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(theme.spacing.lg)
                .animation(.easeInOut(duration: 0.2), value: parsedRate != nil)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(isEditing ? "Edit Activity" : "New Activity")
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

    // MARK: - Reusable pieces

    @ViewBuilder
    private func label(_ text: String) -> some View {
        Text(text)
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.textSecondary)
            .kerning(2)
    }

    // Neumorphic field container — raised card wrapping any input.
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

    @ViewBuilder
    private func kindCard(_ k: ActivityKind, title: String, subtitle: String) -> some View {
        let selected = kind == k
        let tint = k == .charger ? theme.colors.positive : theme.colors.negative

        Button {
            withAnimation(.easeInOut(duration: 0.18)) { kind = k }
        } label: {
            VStack(spacing: theme.spacing.sm) {
                theme.icon(k == .charger ? .charger : .spender)
                    .font(.system(size: 26))
                    .foregroundStyle(selected ? tint : theme.colors.textSecondary)
                Text(title)
                    .font(theme.typography.bodyStrong)
                    .foregroundStyle(selected ? tint : theme.colors.textPrimary)
                Text(subtitle)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(theme.spacing.lg)
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
            // Reduced shadow radius on selected = subtle "pressed in" feel.
            .shadow(color: theme.colors.shadowLight, radius: selected ? 4 : 8, x: selected ? -3 : -5, y: selected ? -3 : -5)
            .shadow(color: theme.colors.shadowDark,  radius: selected ? 4 : 8, x: selected ? 3 :  5, y: selected ? 3 :  5)
            .overlay(
                RoundedRectangle(cornerRadius: theme.spacing.cornerRadius)
                    .strokeBorder(selected ? tint.opacity(0.35) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private func save() {
        guard isValid, let rate = parsedRate else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .create:
            context.insert(Activity(name: trimmed, kind: kind, ratePerMinute: rate))
        case .edit(let activity):
            activity.name          = trimmed
            activity.kind          = kind
            activity.ratePerSecond = rate / 60.0
        }
        dismiss()
    }
}

#Preview {
    AddActivityView(mode: .create)
        .environment(\.theme, NeuTheme())
        .modelContainer(for: [Activity.self], inMemory: true)
}
