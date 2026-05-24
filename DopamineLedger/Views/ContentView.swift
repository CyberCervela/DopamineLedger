// ContentView.swift
// Root view — delegates immediately to ActivityListView.
// Kept as a thin wrapper so the app entry point stays stable while
// the navigation structure grows beneath it.

import SwiftUI

struct ContentView: View {
    var body: some View {
        ActivityListView()
    }
}

#Preview {
    ContentView()
        .environment(\.theme, NeuTheme())
        .modelContainer(for: [Activity.self, Session.self, ActivityDebt.self, Ledger.self, Quest.self],
                        inMemory: true)
}
