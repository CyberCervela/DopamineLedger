// ActivityTemplate.swift
// Static catalogue of pre-built activity presets and the guidance enums
// shared with AddActivityView.
//
// SpenderToxicity and the charger toggle logic encode the 2:1 philosophy:
//   • 1 min of the easiest charger (2.0 cr/min) → 2 min of a Low-tox spender.
//   • Medium-tox (2.0 cr/min) breaks even against the easiest charger: a
//     reminder that even "moderate" habits consume what you earned.
//   • High-tox (10.0 cr/min) is deliberately punishing — 30 min of deep work
//     buys only 18 min of social media, forcing a real trade-off.

import Foundation

// How addictive/harmful a spender activity is. Maps directly to cr/min cost
// so the philosophy is visible in the number the user sees.
enum SpenderToxicity: String, CaseIterable {
    case low, medium, high

    var ratePerMinute: Double {
        switch self {
        case .low:    return 1.0
        case .medium: return 2.0
        case .high:   return 10.0
        }
    }

    var labelKey: String {
        switch self {
        case .low:    return "activity.guidance.toxicity.low"
        case .medium: return "activity.guidance.toxicity.medium"
        case .high:   return "activity.guidance.toxicity.high"
        }
    }
}

// Grouping used by TemplateGalleryView to section the catalogue.
enum TemplateCategory: CaseIterable {
    case focusLearning, movement, rest, leisure, highRisk

    var labelKey: String {
        switch self {
        case .focusLearning: return "template.category.focus"
        case .movement:      return "template.category.movement"
        case .rest:          return "template.category.rest"
        case .leisure:       return "template.category.leisure"
        case .highRisk:      return "template.category.highrisk"
        }
    }
}

// A pre-built activity configuration the user can start from.
// Pure value type — templates pre-fill AddActivityView but are never
// persisted to SwiftData. The user creates a real Activity from them.
struct ActivityTemplate: Identifiable, Hashable {
    let id           = UUID()
    let name:        String
    let kind:        ActivityKind
    let iconName:    String
    let category:    TemplateCategory

    // Charger guidance (nil for spenders)
    let isHighImpact:    Bool?
    let isHighEnjoyment: Bool?
    // Spender guidance (nil for chargers)
    let toxicity: SpenderToxicity?

    // Derived from the guidance fields. Uses the same formula as
    // AddActivityView.applyGuidanceRate() — keep them in sync.
    var ratePerMinute: Double {
        if kind == .charger {
            switch (isHighImpact ?? false, isHighEnjoyment ?? false) {
            case (true,  false): return 6.0
            case (true,  true):  return 5.0
            case (false, false): return 3.0
            case (false, true):  return 2.0
            }
        } else {
            return toxicity?.ratePerMinute ?? 2.0
        }
    }

    // Hashable via id so ActivityTemplate can serve as a NavigationStack value.
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // MARK: - Catalogue

    static let catalog: [ActivityTemplate] = [
        // Chargers — Focus & Learning
        .init(name: "Deep Work",     kind: .charger, iconName: "book.fill",           category: .focusLearning, isHighImpact: true,  isHighEnjoyment: false, toxicity: nil),
        .init(name: "Learning",      kind: .charger, iconName: "graduationcap.fill",  category: .focusLearning, isHighImpact: true,  isHighEnjoyment: false, toxicity: nil),
        .init(name: "Creative Work", kind: .charger, iconName: "pencil",              category: .focusLearning, isHighImpact: true,  isHighEnjoyment: true,  toxicity: nil),
        .init(name: "Journaling",    kind: .charger, iconName: "doc.fill",               category: .focusLearning, isHighImpact: true,  isHighEnjoyment: false, toxicity: nil),
        .init(name: "Homework",      kind: .charger, iconName: "pencil.and.ruler.fill", category: .focusLearning, isHighImpact: true,  isHighEnjoyment: false, toxicity: nil),
        .init(name: "Reading",       kind: .charger, iconName: "book.closed.fill",      category: .focusLearning, isHighImpact: true,  isHighEnjoyment: true,  toxicity: nil),
        // Chargers — Movement
        .init(name: "Exercise",      kind: .charger, iconName: "figure.run",            category: .movement,      isHighImpact: true,  isHighEnjoyment: false, toxicity: nil),
        .init(name: "Walk",          kind: .charger, iconName: "figure.walk",           category: .movement,      isHighImpact: false, isHighEnjoyment: false, toxicity: nil),
        .init(name: "Chores",        kind: .charger, iconName: "house.fill",            category: .movement,      isHighImpact: false, isHighEnjoyment: false, toxicity: nil),
        // Chargers — Rest & Recovery
        .init(name: "Meditation",    kind: .charger, iconName: "leaf.fill",           category: .rest,          isHighImpact: true,  isHighEnjoyment: true,  toxicity: nil),
        .init(name: "Rest / Nap",    kind: .charger, iconName: "bed.double.fill",     category: .rest,          isHighImpact: false, isHighEnjoyment: true,  toxicity: nil),
        // Spenders — Leisure
        .init(name: "Streaming",     kind: .spender, iconName: "tv.fill",             category: .leisure,       isHighImpact: nil,   isHighEnjoyment: nil,   toxicity: .medium),
        .init(name: "Gaming",        kind: .spender, iconName: "gamecontroller.fill", category: .leisure,       isHighImpact: nil,   isHighEnjoyment: nil,   toxicity: .medium),
        .init(name: "Light Leisure", kind: .spender, iconName: "cup.and.saucer.fill", category: .leisure,       isHighImpact: nil,   isHighEnjoyment: nil,   toxicity: .low),
        // Spenders — High-Risk
        .init(name: "Social Media",  kind: .spender, iconName: "message.fill",        category: .highRisk,      isHighImpact: nil,   isHighEnjoyment: nil,   toxicity: .high),
        .init(name: "Browsing",      kind: .spender, iconName: "laptopcomputer",      category: .highRisk,      isHighImpact: nil,   isHighEnjoyment: nil,   toxicity: .medium),
    ]
}
