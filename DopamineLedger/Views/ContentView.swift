// ContentView.swift
// Root view. Two-tab navigation shell: Home (activity list) and Stats (dashboard).
//
// Why no TabView: TabView always creates a UITabBarController underneath, and
// reliably hiding its system bar requires UIKit hacks. Since we own the tab bar
// entirely (NeuTabBar), we skip TabView and manage switching ourselves.
// Both views stay in the ZStack so @Query and @State are preserved across tabs.

import SwiftUI

enum AppTab { case home, stats }

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    #if DEBUG
    @Environment(\.modelContext) private var context
    #endif

    var body: some View {
        ZStack {
            ActivityListView()
                .opacity(selectedTab == .home ? 1 : 0)
            DashboardView()
                .opacity(selectedTab == .stats ? 1 : 0)
        }
        .safeAreaInset(edge: .bottom) {
            NeuTabBar(selection: $selectedTab)
        }
        #if DEBUG
        .task { DebugSeeder.seedIfNeeded(in: context) }
        #endif
    }
}

// MARK: - Custom neumorphic tab bar

private struct NeuTabBar: View {
    @Environment(\.theme)          private var theme
    @Environment(\.languageBundle) private var lBundle
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home,  icon: .home,  labelKey: "tab.home")
            tabButton(.stats, icon: .stats, labelKey: "tab.stats")
        }
        .padding(.vertical, theme.spacing.sm)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.cornerRadius))
        .shadow(color: theme.colors.shadowLight, radius: 10, x: -6, y: -6)
        .shadow(color: theme.colors.shadowDark,  radius: 10, x:  6, y:  6)
        .padding(.horizontal, theme.spacing.lg)
        .padding(.bottom, theme.spacing.sm)
    }

    @ViewBuilder
    private func tabButton(_ tab: AppTab, icon: SemanticIcon, labelKey: String) -> some View {
        let isSelected = selection == tab
        Button {
            selection = tab
        } label: {
            VStack(spacing: theme.spacing.xxs) {
                theme.icon(icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                Text(lBundle.l(labelKey))
                    .font(theme.typography.caption)
            }
            .foregroundStyle(isSelected ? theme.colors.accent : theme.colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environment(\.theme, NeuTheme())
        .modelContainer(for: [Activity.self, Session.self, ActivityDebt.self, Ledger.self, Quest.self],
                        inMemory: true)
}
