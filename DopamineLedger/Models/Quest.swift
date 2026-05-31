// Transplanted from round 1. Cleaned 2026-05-23.
// No direct test coverage — straightforward CRUD model; exercised
// through the view layer.

import Foundation
import SwiftData

// A user-defined one-shot goal. Unlike Activities (which earn or spend
// credits over time), a Quest pays out a single lump-sum reward the moment
// the user taps "Done".
//
// Examples: "File tax declaration" (high payoff for high friction),
// "Reply to that email I've been avoiding" (small payoff for small friction).
//
// Why soft-delete (isCompleted flag) instead of hard-delete on completion?
// We want a future "quest history" view — showing what you've accomplished
// today/this week/this year. Keeping completed quests in the store costs
// nothing now and unlocks that feature later.
@Model
final class Quest {
    var id:            UUID
    var name:          String
    // The credit reward when this quest is marked Done. User-defined per quest,
    // so a tax declaration can pay out 500 while a single email might pay out 20.
    var payoffCredits: Double
    var iconName:      String
    // Optional so SwiftData stores NULL for rows that predate this field.
    // Read via ?? .other — see Activity.swift comment for the full reason.
    var category:      ActivityCategory?
    var createdAt:     Date
    // false while the quest is active and shown in the list;
    // true once Done has been tapped — filtered out of the active list.
    var isCompleted:   Bool
    var completedAt:   Date?
    // Soft-delete flag — mirrors Activity.isArchived. Completed quests are never
    // hard-deleted: the payoff credit already moved at completion time and the
    // history entry should remain. Incomplete quests (no credits moved) can be
    // hard-deleted safely. Default false keeps lightweight migration safe.
    var isArchived:    Bool = false

    init(name: String, payoffCredits: Double, iconName: String = "star", category: ActivityCategory = .other) {
        self.id            = UUID()
        self.name          = name
        self.payoffCredits = payoffCredits
        self.iconName      = iconName
        self.category      = category
        self.createdAt     = Date()
        self.isCompleted   = false
        self.completedAt   = nil
    }
}
