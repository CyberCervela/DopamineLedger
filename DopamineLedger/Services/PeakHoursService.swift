// PeakHoursService.swift
// Pure service — reads UserDefaults directly so it can be called from
// anywhere (views, SessionFinalizer, AppIntents) without injecting
// @AppStorage or an environment value.
//
// The 6-hour window is a product constant: long enough to cover a full
// productive morning (exercise + deep work + reading), short enough that
// the 1.5× bonus feels meaningful rather than default.

import Foundation

enum PeakHoursService {

    // Product constant — not user-adjustable in v1.
    static let windowHours = 6
    // The multiplier applied when a session starts inside the peak window.
    static let multiplier: Double = 1.5

    // Whether the current moment falls inside the user's configured peak window.
    // Returns false immediately when the feature is disabled.
    static func isCurrentlyPeak(at date: Date = .now) -> Bool {
        guard UserDefaults.standard.bool(forKey: "peakEnabled") else { return false }
        let startHour   = UserDefaults.standard.integer(forKey: "peakStartHour")
        let startMinute = UserDefaults.standard.integer(forKey: "peakStartMinute")
        return isInWindow(date: date, startHour: startHour, startMinute: startMinute)
    }

    // Computed end time (hour, minute) for the given start, for UI display.
    static func peakEnd(startHour: Int, startMinute: Int) -> (hour: Int, minute: Int) {
        let totalMinutes = startHour * 60 + startMinute + windowHours * 60
        return (hour: (totalMinutes / 60) % 24, minute: totalMinutes % 60)
    }

    // MARK: - Internal — exposed for unit tests

    // Extracted from isCurrentlyPeak so tests can call it with explicit
    // inputs without touching UserDefaults.
    static func isInWindow(date: Date, startHour: Int, startMinute: Int) -> Bool {
        let cal     = Calendar.current
        let current = cal.component(.hour, from: date) * 60
                    + cal.component(.minute, from: date)
        let start   = startHour * 60 + startMinute
        let end     = start + windowHours * 60

        if end <= 24 * 60 {
            // Window fits within a single calendar day.
            return current >= start && current < end
        } else {
            // Window wraps midnight (e.g. 22:00 start → 04:00 end).
            // The user is in-peak if they're after the start OR before the
            // wrapped end — two disjoint ranges that together cover the window.
            let wrappedEnd = end - 24 * 60
            return current >= start || current < wrappedEnd
        }
    }
}
