// LanguageBundle.swift
// In-app language switching infrastructure.
//
// Why not just use the device language?
// iOS uses the device language to pick the .lproj bundle automatically.
// But the user asked for an in-app language picker that overrides the
// device setting. SwiftUI's Text(LocalizedStringKey) ignores
// .environment(\.locale) for bundle selection — it always reads Bundle.main
// with the device's language. So we inject a resolved Bundle manually via
// a custom environment key, and every view reads from that bundle.
//
// How it works:
//   1. @AppStorage("languageCode") persists the user's choice.
//   2. DopamineLedgerApp resolves it to a Bundle via languageBundle(for:)
//      and injects it with .environment(\.languageBundle, bundle).
//   3. Views read @Environment(\.languageBundle) and call lBundle.l("key").
//   4. Bundle.l(_:) is just NSLocalizedString(_:bundle:comment:) — one line.

import Foundation
import SwiftUI

// MARK: - Supported languages

enum SupportedLanguage: String, CaseIterable, Identifiable {
    case en      = "en"
    case fr      = "fr"
    case de      = "de"
    case es      = "es"
    case zhHans  = "zh-Hans"
    case ja      = "ja"
    case ko      = "ko"

    var id: String { rawValue }

    // Native-script display name shown in the language picker.
    var displayName: String {
        switch self {
        case .en:     return "English"
        case .fr:     return "Français"
        case .de:     return "Deutsch"
        case .es:     return "Español"
        case .zhHans: return "中文"
        case .ja:     return "日本語"
        case .ko:     return "한국어"
        }
    }
}

// MARK: - Bundle resolution

// Resolves a language code to the matching .lproj Bundle inside the app bundle.
// Falls back to Bundle.main (English) if the .lproj folder isn't found.
func languageBundle(for code: String) -> Bundle {
    guard
        let path   = Bundle.main.path(forResource: code, ofType: "lproj"),
        let bundle = Bundle(path: path)
    else { return .main }
    return bundle
}

// MARK: - Environment key

private struct LanguageBundleKey: EnvironmentKey {
    static let defaultValue: Bundle = .main
}

extension EnvironmentValues {
    var languageBundle: Bundle {
        get { self[LanguageBundleKey.self] }
        set { self[LanguageBundleKey.self] = newValue }
    }
}

// MARK: - Convenience

extension Bundle {
    // Short lookup: reads the key from this specific bundle, ignoring the
    // device language. Every view uses this instead of bare string literals.
    func l(_ key: String) -> String {
        NSLocalizedString(key, bundle: self, comment: "")
    }
}
