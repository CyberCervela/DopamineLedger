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
}
