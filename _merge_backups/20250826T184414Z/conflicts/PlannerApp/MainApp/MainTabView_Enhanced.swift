//
//  MainTabView_Enhanced.swift
//  PlannerApp
//
//  Enhanced cross-platform tab view with better iOS/macOS UX
//

import SwiftUI
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

struct MainTabView_Enhanced: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedTabTag: String
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    // Define constants for tab tags
    enum TabTags {
        static let dashboard = "Dashboard"
        static let tasks = "Tasks"
        static let calendar = "Calendar"
        static let goals = "Goals"
        static let journal = "Journal"
        static let settings = "Settings"
    }

    // Tab configuration
    struct TabConfiguration {
        let tag: String
        let title: String
        let icon: String
        let keyboardShortcut: KeyEquivalent?

        static let allTabs = [
            TabConfiguration(tag: TabTags.dashboard, title: "Dashboard", icon: "house", keyboardShortcut: "1"),
            TabConfiguration(tag: TabTags.tasks, title: "Tasks", icon: "checkmark.square", keyboardShortcut: "2"),
            TabConfiguration(tag: TabTags.calendar, title: "Calendar", icon: "calendar", keyboardShortcut: "3"),
            TabConfiguration(tag: TabTags.goals, title: "Goals", icon: "target", keyboardShortcut: "4"),
            TabConfiguration(tag: TabTags.journal, title: "Journal", icon: "book", keyboardShortcut: "5"),
            TabConfiguration(tag: TabTags.settings, title: "Settings", icon: "gear", keyboardShortcut: ","),
        ]
    }

    var body: some View {
        #if os(macOS)
            macOSLayout
        #elseif os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        #endif
    }

    // MARK: - macOS Layout

    #if os(macOS)
        private var macOSLayout: some View {
            NavigationSplitView {
                // Sidebar
                List(TabConfiguration.allTabs, id: \.tag, selection: $selectedTabTag) { tab in
                    Label(tab.title, systemImage: tab.icon)
                        .foregroundColor(
                            selectedTabTag == tab.tag ?
                                themeManager.currentTheme.primaryAccentColor :
                                themeManager.currentTheme.primaryTextColor
                        )
                        .tag(tab.tag)
                }
                .listStyle(SidebarListStyle())
                .frame(minWidth: 200, idealWidth: 250)
                .background(themeManager.currentTheme.secondaryBackgroundColor)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: toggleSidebar) {
                            Image(systemName: "sidebar.left")
                        }
                        .help("Toggle Sidebar")
                    }
                }
            } detail: {
                contentForSelectedTab
                    .frame(minWidth: 600)
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            macOSToolbarButtons
                        }
                    }
            }
            .navigationSplitViewStyle(.balanced)
            .background(themeManager.currentTheme.primaryBackgroundColor)
        }
    #endif

    // MARK: - iPad Layout

    #if os(iOS)
        private var iPadLayout: some View {
            NavigationSplitView {
                List {
                    ForEach(TabConfiguration.allTabs, id: \.tag) { tab in
                        HStack {
                            Image(systemName: tab.icon)
                                .foregroundColor(themeManager.currentTheme.primaryAccentColor)
                                .frame(width: 24)

                            Text(tab.title)
                                .font(.body)
                                .foregroundColor(themeManager.currentTheme.primaryTextColor)

                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .background(
                            selectedTabTag == tab.tag ?
                                themeManager.currentTheme.primaryAccentColor.opacity(0.1) :
                                Color.clear
                        )
                        .cornerRadius(8)
                        .onTapGesture {
                            selectedTabTag = tab.tag
                        }
                    }
                }
                .listStyle(SidebarListStyle())
                .frame(minWidth: 280, idealWidth: 320)
                .background(themeManager.currentTheme.primaryBackgroundColor)
            } detail: {
                NavigationStack {
                    contentForSelectedTab
                }
            }
        }
    #endif

    // MARK: - iPhone Layout (Traditional TabView)

    #if os(iOS)
        private var iPhoneLayout: some View {
            TabView(selection: $selectedTabTag) {
                ForEach(TabConfiguration.allTabs, id: \.tag) { tab in
                    contentForTab(tab.tag)
                        .tabItem {
                            Label(tab.title, systemImage: tab.icon)
                        }
                        .tag(tab.tag)
                }
            }
            .accentColor(themeManager.currentTheme.primaryAccentColor)
            .environment(\.colorScheme, themeManager.currentTheme.primaryBackgroundColor.isDark() ? .dark : .light)
        }
    #endif

    // MARK: - Content Views

    @ViewBuilder
    private var contentForSelectedTab: some View {
        contentForTab(selectedTabTag)
    }

    @ViewBuilder
    private func contentForTab(_ tag: String) -> some View {
        switch tag {
        case TabTags.dashboard:
            DashboardView()
        case TabTags.tasks:
            TaskManagerView()
        case TabTags.calendar:
            CalendarView()
        case TabTags.goals:
            GoalsView()
        case TabTags.journal:
            JournalView()
        case TabTags.settings:
            SettingsView()
        default:
            DashboardView()
        }
    }

    // MARK: - Toolbar Buttons

    #if os(macOS)
        @ViewBuilder
        private var macOSToolbarButtons: some View {
            Button(action: addNewItem) {
                Image(systemName: "plus")
            }
            .help("Add New Item")

            Button(action: searchAction) {
                Image(systemName: "magnifyingglass")
            }
            .help("Search")
            .keyboardShortcut("f", modifiers: .command)

            Button(action: syncAction) {
                Image(systemName: "arrow.clockwise")
            }
            .help("Sync")
            .keyboardShortcut("r", modifiers: .command)
        }
    #endif

    #if os(iOS)
        @ViewBuilder
        private var iPadToolbarButtons: some View {
            Button(action: addNewItem) {
                Image(systemName: "plus")
            }

            Button(action: searchAction) {
                Image(systemName: "magnifyingglass")
            }

            Button(action: syncAction) {
                Image(systemName: "arrow.clockwise")
            }
        }
    #endif

    // MARK: - Actions

    private func addNewItem() {
        // Add new item based on current tab
        print("Add new item for tab: \(selectedTabTag)")
    }

    private func searchAction() {
        // Open search
        print("Search action")
    }

    private func syncAction() {
        // Sync data
        print("Sync action")
    }

    #if os(macOS)
        private func toggleSidebar() {
            NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
        }
    #endif
}

#Preview {
    MainTabView_Enhanced(selectedTabTag: .constant("Dashboard"))
        .environmentObject(ThemeManager())
}
