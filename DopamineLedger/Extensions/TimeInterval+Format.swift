// TimeInterval+Format.swift
// Shared duration formatter used across ActivityListView, SessionView,
// and DashboardView. Previously three identical private copies.

import Foundation

extension TimeInterval {
    // Human-readable duration: "< 1 min", "45 min", "2 h", "2 h 30 m"
    var formattedDuration: String {
        let totalMins = Int(self / 60)
        if totalMins < 1  { return "< 1 min" }
        if totalMins < 60 { return "\(totalMins) min" }
        let hours = totalMins / 60
        let mins  = totalMins % 60
        return mins == 0 ? "\(hours) h" : "\(hours) h \(mins) m"
    }
}
