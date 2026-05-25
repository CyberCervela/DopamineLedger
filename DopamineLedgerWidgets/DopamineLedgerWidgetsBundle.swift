// DopamineLedgerWidgetsBundle.swift
// Entry point for the widget extension. All widgets and Live Activities
// declared in this bundle are registered with the system here.

import WidgetKit
import SwiftUI

@main
struct DopamineLedgerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SessionLiveActivity()
    }
}
