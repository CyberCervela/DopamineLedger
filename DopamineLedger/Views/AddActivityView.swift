// AddActivityView.swift
// Sheet for creating or editing an Activity, with optional guidance toggles
// that auto-suggest a rate based on the activity's qualitative properties.

import SwiftUI
import SwiftData

enum ActivityMode {
    case create
    case edit(Activity)
    // Pre-fills the form from a template chosen in TemplateGalleryView.
    case fromTemplate(ActivityTemplate)
}

struct AddActivityView: View {
    @Environment(\.theme)          private var theme
    @Environment(\.modelContext)   private var context
    @Environment(\.dismiss)        private var dismiss
    @Environment(\.languageBundle) private var lBundle

    let mode:    ActivityMode
    // Provided when this view is pushed inside TemplateGalleryView's
    // NavigationStack — calling it dismisses the containing sheet.
    // When nil (standalone sheet), dismiss() is called instead.
    let onSaved: (() -> Void)?

    @State private var name:            String
    @State private var kind:            ActivityKind
    @State private var category:        ActivityCategory
    @State private var ratePerMinute:   String
    @State private var iconName:        String
    // Guidance state — drives the rate field via applyGuidanceRate()
    @State private var isHighImpact:    Bool
    @State private var isHighEnjoyment: Bool
    @State private var toxicity:        SpenderToxicity
    // Linked app — "" = none, "custom" = user-entered URL, otherwise a catalog scheme.
    @State private var linkedAppSelection: String
    @State private var customURL:          String
    @State private var customName:         String

    init(mode: ActivityMode = .create, initialKind: ActivityKind = .charger, onSaved: (() -> Void)? = nil) {
        self.mode    = mode
        self.onSaved = onSaved

        switch mode {
        case .create:
            let k = initialKind
            _name              = State(initialValue: "")
            _kind              = State(initialValue: k)
            _category          = State(initialValue: .other)
            _isHighImpact      = State(initialValue: false)
            _isHighEnjoyment   = State(initialValue: false)
            _toxicity          = State(initialValue: .medium)
            // Default rate matches guidance defaults: charger (false,false)→3.0, spender medium→4.0
            let rate = k == .charger ? 3.0 : SpenderToxicity.medium.ratePerMinute
            _ratePerMinute     = State(initialValue: String(format: "%.1f", rate))
            _iconName          = State(initialValue: k == .charger ? "bolt.fill" : "hourglass")
            _linkedAppSelection = State(initialValue: "")
            _customURL         = State(initialValue: "")
            _customName        = State(initialValue: "")

        case .edit(let a):
            let ratePM = a.ratePerSecond * 60
            _name          = State(initialValue: a.name)
            _kind          = State(initialValue: a.kind)
            _category      = State(initialValue: a.category ?? .other)
            _ratePerMinute = State(initialValue: String(format: "%.1f", ratePM))
            // Normalize old "circle" default icon on first edit.
            _iconName      = State(initialValue: a.iconName == "circle"
                                       ? (a.kind == .charger ? "bolt.fill" : "hourglass")
                                       : a.iconName)
            // Reverse-map the stored rate to the nearest guidance position so
            // the toggles are meaningful immediately. Falls back to neutral for custom rates.
            if a.kind == .charger {
                let (hi, he)     = Self.chargerToggles(from: ratePM)
                _isHighImpact    = State(initialValue: hi)
                _isHighEnjoyment = State(initialValue: he)
                _toxicity        = State(initialValue: .medium)
            } else {
                _isHighImpact    = State(initialValue: false)
                _isHighEnjoyment = State(initialValue: false)
                _toxicity        = State(initialValue: Self.spenderToxicity(from: ratePM))
            }
            // Reverse-map stored linked app back to picker selection.
            if let scheme = a.linkedAppScheme, !scheme.isEmpty {
                if LinkedApp.catalog.contains(where: { $0.id == scheme }) {
                    _linkedAppSelection = State(initialValue: scheme)
                    _customURL          = State(initialValue: "")
                    _customName         = State(initialValue: "")
                } else {
                    _linkedAppSelection = State(initialValue: "custom")
                    _customURL          = State(initialValue: scheme)
                    _customName         = State(initialValue: a.linkedAppName ?? "")
                }
            } else {
                _linkedAppSelection = State(initialValue: "")
                _customURL          = State(initialValue: "")
                _customName         = State(initialValue: "")
            }

        case .fromTemplate(let t):
            _name            = State(initialValue: t.name)
            _kind            = State(initialValue: t.kind)
            _category        = State(initialValue: t.category)
            _iconName        = State(initialValue: t.iconName)
            _isHighImpact    = State(initialValue: t.isHighImpact    ?? false)
            _isHighEnjoyment = State(initialValue: t.isHighEnjoyment ?? false)
            _toxicity        = State(initialValue: t.toxicity        ?? .medium)
            _ratePerMinute   = State(initialValue: String(format: "%.1f", t.ratePerMinute))
            // Pre-select the linked app tile when the template ships with one.
            if let scheme = t.linkedAppScheme, !scheme.isEmpty {
                _linkedAppSelection = State(initialValue: scheme)
                _customURL          = State(initialValue: "")
                _customName         = State(initialValue: "")
            } else {
                _linkedAppSelection = State(initialValue: "")
                _customURL          = State(initialValue: "")
                _customName         = State(initialValue: "")
            }
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
        VStack(spacing: 0) {
            HStack {
                NeuTextButton(
                    title:      lBundle.l("common.cancel"),
                    font:       theme.typography.body,
                    foreground: theme.colors.textSecondary,
                    action:     { dismiss() }
                )
                Spacer()
                Text(lBundle.l(isEditing ? "activity.edit" : "activity.new"))
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
                        .neuCard()
                    }

                    // Guidance section — toggles or toxicity picker that auto-fill the rate below.
                    guidanceSection

                    // Category picker — groups this activity on the dashboard.
                    categorySection

                    // Linked app — optional gatekeeper: a button to open a chosen app
                    // appears in SessionView while this activity's session is running.
                    linkedAppSection

                    neuField(label: lBundle.l("activity.field.rate").uppercased()) {
                        HStack {
                            TextField("3.0", text: $ratePerMinute)
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
                                    rate.abbreviated))
                            .font(theme.typography.caption)
                            .foregroundStyle(kind == .charger ? theme.colors.positive : theme.colors.negative)
                            .multilineTextAlignment(.center)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(theme.spacing.lg)
                .animation(.easeInOut(duration: 0.2), value: parsedRate != nil)
                .animation(.easeInOut(duration: 0.2), value: kind)
            }
        }
        // Background covers both standalone-sheet and pushed-in-NavigationStack contexts.
        .background(theme.colors.background.ignoresSafeArea())
        .presentationBackground(theme.colors.background)
        .onChange(of: kind) { _, _ in resetGuidanceForKind(); applyGuidanceRate() }
        .onChange(of: isHighImpact)    { _, _ in applyGuidanceRate() }
        .onChange(of: isHighEnjoyment) { _, _ in applyGuidanceRate() }
        .onChange(of: toxicity)        { _, _ in applyGuidanceRate() }
    }

    // MARK: - Category section

    @ViewBuilder
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            label(lBundle.l("activity.field.category").uppercased())
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: theme.spacing.md), count: 3),
                spacing: theme.spacing.md
            ) {
                ForEach(ActivityCategory.allCases, id: \.self) { cat in
                    categoryButton(cat)
                }
            }
        }
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

    // MARK: - Linked app section

    @ViewBuilder
    private var linkedAppSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            label(lBundle.l("activity.field.linked_app").uppercased())
            Text(lBundle.l("activity.linked_app.hint"))
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)

            // 3-column grid: None + catalog apps + Custom website
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: theme.spacing.md), count: 3),
                spacing: theme.spacing.md
            ) {
                linkedAppTile(scheme: "", sfSymbol: "slash.circle",
                              name: lBundle.l("activity.linked_app.none"))
                ForEach(LinkedApp.catalog) { app in
                    linkedAppTile(scheme: app.id, sfSymbol: app.sfSymbol, name: app.name)
                }
                linkedAppTile(scheme: "custom", sfSymbol: "link",
                              name: lBundle.l("activity.linked_app.custom"))
            }

            // Custom URL fields — animate in when the "Website" tile is selected.
            if linkedAppSelection == "custom" {
                VStack(spacing: theme.spacing.sm) {
                    neuField(label: lBundle.l("activity.linked_app.url_label").uppercased()) {
                        TextField("https://example.com", text: $customURL)
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textPrimary)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    neuField(label: lBundle.l("activity.linked_app.name_label").uppercased()) {
                        TextField(lBundle.l("activity.linked_app.name_placeholder"), text: $customName)
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textPrimary)
                            .autocorrectionDisabled()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: linkedAppSelection)
    }

    @ViewBuilder
    private func linkedAppTile(scheme: String, sfSymbol: String, name: String) -> some View {
        let selected = linkedAppSelection == scheme
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { linkedAppSelection = scheme }
        } label: {
            VStack(spacing: theme.spacing.xs) {
                // SF Symbol used as a generic placeholder icon — not a brand asset,
                // not part of the theme system. Intentional direct Image call here.
                Image(systemName: sfSymbol)
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? theme.colors.accent : theme.colors.textSecondary)
                Text(name)
                    .font(theme.typography.caption)
                    .foregroundStyle(selected ? theme.colors.accent : theme.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
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

    // MARK: - Guidance section

    @ViewBuilder
    private var guidanceSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            label(lBundle.l("activity.guidance.label").uppercased())
            if kind == .charger {
                chargerGuidanceCard
            } else {
                spenderGuidanceCard
            }
        }
    }

    @ViewBuilder
    private var chargerGuidanceCard: some View {
        VStack(spacing: 0) {
            guidanceToggleRow(
                labelKey: "activity.guidance.charger.impact",
                hintKey:  "activity.guidance.charger.impact.hint",
                binding:  $isHighImpact
            )
            Rectangle()
                .fill(theme.colors.divider)
                .frame(height: 1)
                .padding(.horizontal, theme.spacing.lg)
            guidanceToggleRow(
                labelKey: "activity.guidance.charger.enjoyment",
                hintKey:  "activity.guidance.charger.enjoyment.hint",
                binding:  $isHighEnjoyment
            )
        }
        .neuCard()
    }

    @ViewBuilder
    private func guidanceToggleRow(labelKey: String, hintKey: String, binding: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(lBundle.l(labelKey))
                    .font(theme.typography.bodyStrong)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(lBundle.l(hintKey))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(theme.colors.accent)
        }
        .padding(theme.spacing.lg)
    }

    @ViewBuilder
    private var spenderGuidanceCard: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            HStack(spacing: theme.spacing.sm) {
                ForEach(SpenderToxicity.allCases, id: \.self) { level in
                    toxicityButton(level)
                }
            }
            Text(lBundle.l("activity.guidance.spender.toxicity.hint"))
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
        }
    }

    @ViewBuilder
    private func toxicityButton(_ level: SpenderToxicity) -> some View {
        let selected = toxicity == level
        let tint: Color = {
            switch level {
            case .low:    return theme.colors.positive
            case .medium: return theme.colors.neutral
            case .high:   return theme.colors.negative
            }
        }()

        Button {
            withAnimation(.easeInOut(duration: 0.18)) { toxicity = level }
        } label: {
            Text(lBundle.l(level.labelKey))
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(selected ? tint : theme.colors.textSecondary)
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
                        .strokeBorder(selected ? tint.opacity(0.35) : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Guidance logic

    // Updates the rate field to match the current guidance toggle state.
    // The rate field remains directly editable as an escape hatch — typing
    // over the auto-filled value is always allowed.
    private func applyGuidanceRate() {
        let rate: Double
        if kind == .charger {
            switch (isHighImpact, isHighEnjoyment) {
            case (true,  false): rate = 6.0
            case (true,  true):  rate = 5.0
            case (false, false): rate = 3.0
            case (false, true):  rate = 2.0
            }
        } else {
            rate = toxicity.ratePerMinute
        }
        ratePerMinute = String(format: "%.1f", rate)
    }

    // Resets guidance toggles to neutral defaults when the user switches kind.
    private func resetGuidanceForKind() {
        if kind == .charger {
            isHighImpact    = false
            isHighEnjoyment = false
        } else {
            toxicity = .medium
        }
    }

    // Reverse-maps a stored rate to the nearest charger toggle combination.
    // Falls back to (false, false) for custom rates that don't match any preset.
    private static func chargerToggles(from ratePerMinute: Double) -> (Bool, Bool) {
        switch ratePerMinute {
        case 6.0: return (true,  false)
        case 5.0: return (true,  true)
        case 2.0: return (false, true)
        default:  return (false, false)
        }
    }

    // Reverse-maps a stored rate to the nearest SpenderToxicity level.
    // Explicit cases cover template-generated rates; anything else (including
    // the old 1.0 / 2.0 defaults before the rate bump) falls back to .medium.
    private static func spenderToxicity(from ratePerMinute: Double) -> SpenderToxicity {
        switch ratePerMinute {
        case 2.0:  return .low
        case 4.0:  return .medium
        case 10.0: return .high
        default:   return .medium
        }
    }

    // MARK: - Shared helpers (unchanged)

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
                .neuCard()
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
        let saved: Activity
        switch mode {
        case .create:
            let a = Activity(name: trimmed, kind: kind, ratePerMinute: rate, iconName: iconName, category: category)
            context.insert(a)
            saved = a
        case .fromTemplate:
            // If the user already has an activity with this name, update it rather than
            // creating a duplicate. Matching by name is intentional — templates have unique
            // names and the user expects "re-apply" to behave like "edit".
            let existing = (try? context.fetch(FetchDescriptor<Activity>()))?.first(where: {
                $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
            })
            if let existing {
                existing.kind          = kind
                existing.ratePerSecond = rate / 60.0
                existing.iconName      = iconName
                existing.category      = category
                existing.isArchived    = false   // restore if previously removed
                saved = existing
            } else {
                let a = Activity(name: trimmed, kind: kind, ratePerMinute: rate, iconName: iconName, category: category)
                context.insert(a)
                saved = a
            }
        case .edit(let activity):
            activity.name          = trimmed
            activity.kind          = kind
            activity.ratePerSecond = rate / 60.0
            activity.iconName      = iconName
            activity.category      = category
            saved = activity
        }
        applyLinkedApp(to: saved)
        if let onSaved { onSaved() } else { dismiss() }
    }

    private func applyLinkedApp(to activity: Activity) {
        if linkedAppSelection.isEmpty {
            activity.linkedAppScheme = nil
            activity.linkedAppName   = nil
        } else if linkedAppSelection == "custom" {
            let raw = customURL.trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty else {
                activity.linkedAppScheme = nil
                activity.linkedAppName   = nil
                return
            }
            let url = raw.hasPrefix("http") ? raw : "https://\(raw)"
            let label = customName.trimmingCharacters(in: .whitespaces)
            activity.linkedAppScheme = url
            activity.linkedAppName   = label.isEmpty ? (URL(string: url)?.host ?? url) : label
        } else if let app = LinkedApp.catalog.first(where: { $0.id == linkedAppSelection }) {
            activity.linkedAppScheme = app.id
            activity.linkedAppName   = app.name
        }
    }
}

#Preview {
    AddActivityView(mode: .create)
        .environment(\.theme, NeuTheme())
        .modelContainer(for: [Activity.self], inMemory: true)
}
