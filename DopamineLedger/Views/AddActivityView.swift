// AddActivityView.swift
// Sheet for creating or editing an Activity.

import SwiftUI
import SwiftData

enum ActivityMode {
    case create
    case edit(Activity)
}

struct AddActivityView: View {
    @Environment(\.theme)          private var theme
    @Environment(\.modelContext)   private var context
    @Environment(\.dismiss)        private var dismiss
    @Environment(\.languageBundle) private var lBundle

    let mode: ActivityMode

    @State private var name:          String
    @State private var kind:          ActivityKind
    @State private var ratePerMinute: String
    @State private var iconName:      String

    init(mode: ActivityMode = .create, initialKind: ActivityKind = .charger) {
        self.mode = mode
        switch mode {
        case .create:
            _name          = State(initialValue: "")
            _kind          = State(initialValue: initialKind)
            _ratePerMinute = State(initialValue: "10")
            _iconName      = State(initialValue: initialKind == .charger ? "bolt.fill" : "hourglass")
        case .edit(let a):
            _name          = State(initialValue: a.name)
            _kind          = State(initialValue: a.kind)
            _ratePerMinute = State(initialValue: String(format: "%.1f", a.ratePerSecond * 60))
            // Normalize the old "circle" default to a kind-appropriate icon on first edit.
            _iconName      = State(initialValue: a.iconName == "circle"
                                       ? (a.kind == .charger ? "bolt.fill" : "hourglass")
                                       : a.iconName)
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
                    neuField(label: lBundle.l("activity.field.name").uppercased()) {
                        TextField(lBundle.l("activity.name.placeholder"), text: $name)
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textPrimary)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: theme.spacing.sm) {
                        label(lBundle.l("activity.field.type").uppercased())
                        HStack(spacing: theme.spacing.md) {
                            kindCard(.charger,
                                     title:    lBundle.l("activity.kind.charger.title"),
                                     subtitle: lBundle.l("activity.kind.charger.subtitle"))
                            kindCard(.spender,
                                     title:    lBundle.l("activity.kind.spender.title"),
                                     subtitle: lBundle.l("activity.kind.spender.subtitle"))
                        }
                    }

                    VStack(alignment: .leading, spacing: theme.spacing.sm) {
                        label(lBundle.l("activity.field.icon").uppercased())
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: theme.spacing.sm), count: 6),
                            spacing: theme.spacing.sm
                        ) {
                            ForEach(IconResolver.activityIcons, id: \.self) { symbol in
                                let selected = symbol == iconName
                                Button { iconName = symbol } label: {
                                    IconResolver.activityIconImage(named: symbol)
                                        .font(.system(size: 20))
                                        .foregroundStyle(selected ? theme.colors.accent : theme.colors.textSecondary)
                                        .frame(width: 40, height: 40)
                                        .background(theme.colors.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius - 4))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: theme.spacing.cornerRadius - 4)
                                                .strokeBorder(selected ? theme.colors.accent : Color.clear,
                                                              lineWidth: 1.5)
                                        )
                                        .shadow(color: theme.colors.shadowLight, radius: selected ? 2 : 4,
                                                x: selected ? -1 : -3, y: selected ? -1 : -3)
                                        .shadow(color: theme.colors.shadowDark,  radius: selected ? 2 : 4,
                                                x: selected ?  1 :  3, y: selected ?  1 :  3)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(theme.spacing.md)
                        .background(theme.colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
                        .shadow(color: theme.colors.shadowLight, radius: 8, x: -5, y: -5)
                        .shadow(color: theme.colors.shadowDark,  radius: 8, x:  5, y:  5)
                    }

                    neuField(label: lBundle.l("activity.field.rate").uppercased()) {
                        HStack {
                            TextField("10", text: $ratePerMinute)
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.textPrimary)
                                .keyboardType(.decimalPad)
                            Spacer()
                            Text(lBundle.l("activity.rate_suffix"))
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                    }

                    if let rate = parsedRate {
                        let hintKey = kind == .charger ? "activity.hint.earns" : "activity.hint.spends"
                        Text(String(format: lBundle.l(hintKey),
                                    rate.formatted(.number.precision(.fractionLength(1)))))
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
                    Text(lBundle.l(isEditing ? "activity.edit" : "activity.new"))
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(lBundle.l("common.cancel")) { dismiss() }
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(lBundle.l("common.save")) { save() }
                        .font(theme.typography.bodyStrong)
                        .foregroundStyle(isValid ? theme.colors.accent : theme.colors.textSecondary.opacity(0.5))
                        .disabled(!isValid)
                }
            }
        }
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
            .shadow(color: theme.colors.shadowLight, radius: selected ? 4 : 8, x: selected ? -3 : -5, y: selected ? -3 : -5)
            .shadow(color: theme.colors.shadowDark,  radius: selected ? 4 : 8, x: selected ? 3 :  5, y: selected ? 3 :  5)
            .overlay(
                RoundedRectangle(cornerRadius: theme.spacing.cornerRadius)
                    .strokeBorder(selected ? tint.opacity(0.35) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func save() {
        guard isValid, let rate = parsedRate else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .create:
            context.insert(Activity(name: trimmed, kind: kind, ratePerMinute: rate, iconName: iconName))
        case .edit(let activity):
            activity.name          = trimmed
            activity.kind          = kind
            activity.ratePerSecond = rate / 60.0
            activity.iconName      = iconName
        }
        dismiss()
    }
}

#Preview {
    AddActivityView(mode: .create)
        .environment(\.theme, NeuTheme())
        .modelContainer(for: [Activity.self], inMemory: true)
}
