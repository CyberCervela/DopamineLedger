// Double+Credits.swift
// Display-only formatter for credit amounts.
// < 100,000  → full number with up to 1 decimal (existing behaviour, e.g. "9,999.5")
// ≥ 100,000  → abbreviated to K / M / B  (e.g. "100K", "1.2M", "2B")
// Negative values preserve the minus sign (e.g. "-150K" for debt displays).

import Foundation

extension Double {
    var abbreviated: String {
        let absVal = abs(self)
        let sign   = self < 0 ? "-" : ""
        switch absVal {
        case 1_000_000_000...: return sign + Self.compact(absVal / 1_000_000_000, suffix: "B")
        case     1_000_000...: return sign + Self.compact(absVal / 1_000_000,     suffix: "M")
        case       100_000...: return sign + Self.compact(absVal / 1_000,         suffix: "K")
        default:               return self.formatted(.number.precision(.fractionLength(0...1)))
        }
    }

    // Rounds to 1 decimal place; drops the ".0" when the result is a whole number.
    // 100.0 → "100K", 123.456 → "123.5K", 1.0 → "1M", 1.234 → "1.2M"
    private static func compact(_ value: Double, suffix: String) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rounded))\(suffix)"
        }
        return String(format: "%.1f", rounded) + suffix
    }

    // Parses a number the user typed into a numeric/decimal-pad field.
    //
    // Why this exists: the plain `Double(_ string:)` initialiser is US-English
    // only — it accepts "2.5" but NOT "2,5". On a French/German/Spanish device
    // the decimal-pad key is "," so the user literally cannot type a dot, and
    // `Double("2,5")` returns nil → Save silently disables. We normalise the
    // comma to a dot before parsing so both conventions work.
    //
    // We do NOT use a locale-aware NumberFormatter here on purpose: the decimal
    // pad has no grouping-separator key, so the input is always a bare number
    // with at most one separator. A simple comma→dot swap is enough and avoids
    // formatter edge cases. (Consequence: a literal "1,000" parses as 1.0, not
    // a thousand — acceptable because users can't type grouped numbers on this
    // keyboard, and seeded fields are kept grouping-free at the call site.)
    init?(userInput: String) {
        let normalised = userInput
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalised), value.isFinite else { return nil }
        // Reject "inf"/"nan": Double("inf") parses successfully and would slip
        // past a `> 0` guard at the call site, so we filter non-finite here.
        self = value
    }
}
