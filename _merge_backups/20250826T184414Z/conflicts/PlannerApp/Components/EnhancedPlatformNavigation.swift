//
//  EnhancedPlatformNavigation.swift
//  PlannerApp
//
//  Enhanced platform-specific navigation patterns for iOS, iPadOS, and macOS
//

import SwiftUI

// MARK: - Enhanced Platform Navigation
struct EnhancedPlatformNavigation<Content: View>: View {
    let content: Content
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        #if os(macOS)
        macOSNavigation
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            iPadNavigation
        } else {
            iPhoneNavigation
        }
        #endif
    }
    
    // MARK: - macOS Navigation
    private var macOSNavigation: some View {
        NavigationSplitView {
            MacOSSidebarView()
                .frame(minWidth: 200, idealWidth: 250)
        } detail: {
            content
                .frame(minWidth: 600, maxWidth: .infinity)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        MacOSToolbarButtons()
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    // MARK: - iPad Navigation
    private var iPadNavigation: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            IPadSidebarView()
                .frame(minWidth: 280, idealWidth: 320)
        } detail: {
            content
                .toolbar {
                    #if os(iOS)
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        IPadToolbarButtons()
                    }
                    #else
                    ToolbarItemGroup {
                        IPadToolbarButtons()
                    }
                    #endif
                }
        }

    }
    
    // MARK: - iPhone Navigation
    private var iPhoneNavigation: some View {
        NavigationStack {
            content
                .toolbar {
                    #if os(iOS)
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        IPhoneToolbarButtons()
                    }
                    #else
                    ToolbarItemGroup {
                        IPhoneToolbarButtons()
                    }
                    #endif
                }
        }
    }
}

// MARK: - macOS Sidebar
struct MacOSSidebarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab: Tab = .dashboard
    
    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case tasks = "Tasks"
        case goals = "Goals"
        case calendar = "Calendar"
        case journal = "Journal"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .tasks: return "checkmark.circle"
            case .goals: return "target"
            case .calendar: return "calendar"
            case .journal: return "book"
            case .settings: return "gear"
            }
        }
        
        var keyboardShortcut: KeyEquivalent? {
            switch self {
            case .dashboard: return "1"
            case .tasks: return "2"
            case .goals: return "3"
            case .calendar: return "4"
            case .journal: return "5"
            case .settings: return ","
            }
        }
    }
    
    var body: some View {
        List(Tab.allCases, id: \.self) { tab in
            NavigationLink(value: tab) {
                Label(tab.rawValue, systemImage: tab.icon)
                    .foregroundColor(
                        selectedTab == tab ? 
                        themeManager.currentTheme.primaryAccentColor : 
                        themeManager.currentTheme.primaryTextColor
                    )
            }
            .keyboardShortcut(tab.keyboardShortcut ?? KeyEquivalent(" "), modifiers: .command)
        }
        .listStyle(SidebarListStyle())
        .background(themeManager.currentTheme.secondaryBackgroundColor)
    }
}

// MARK: - iPad Sidebar
struct IPadSidebarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab: String = "Dashboard"
    
    let tabs = [
        ("Dashboard", "square.grid.2x2"),
        ("Tasks", "checkmark.circle"),
        ("Goals", "target"),
        ("Calendar", "calendar"),
        ("Journal", "book"),
        ("Settings", "gear")
    ]
    
    var body: some View {
        List {
            Section("PlannerApp") {
                ForEach(tabs, id: \.0) { tab in
                    HStack {
                        Image(systemName: tab.1)
                            .foregroundColor(themeManager.currentTheme.primaryAccentColor)
                            .frame(width: 24)
                        
                        Text(tab.0)
                            .font(.body)
                            .foregroundColor(themeManager.currentTheme.primaryTextColor)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .background(
                        selectedTab == tab.0 ? 
                        themeManager.currentTheme.primaryAccentColor.opacity(0.1) : 
                        Color.clear
                    )
                    .cornerRadius(8)
                    .onTapGesture {
                        selectedTab = tab.0
                        // Add haptic feedback
                        #if os(iOS)
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        #endif
                    }
                }
            }
            
            Spacer(minLength: 100)
            
            Section("Quick Actions") {
                QuickActionButton(title: "Add Task", icon: "plus.circle", color: .blue) {
                    // Handle add task
                }
                
                QuickActionButton(title: "Add Goal", icon: "target", color: .green) {
                    // Handle add goal
                }
                
                QuickActionButton(title: "Add Event", icon: "calendar.badge.plus", color: .orange) {
                    // Handle add event
                }
            }
        }
        .listStyle(SidebarListStyle())
        .background(themeManager.currentTheme.primaryBackgroundColor)
    }
}

// MARK: - Toolbar Buttons
struct MacOSToolbarButtons: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Button(action: {}) {
                Label("Search", systemImage: "magnifyingglass")
            }
            .keyboardShortcut("f", modifiers: .command)
            
            Button(action: {}) {
                Label("Add Item", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            
            Menu {
                Button("Export Data", action: {})
                Button("Import Data", action: {})
                Divider()
                Button("Preferences", action: {})
                    .keyboardShortcut(",", modifiers: .command)
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }
}

struct IPadToolbarButtons: View {
    var body: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "magnifyingglass")
            }
            
            Button(action: {}) {
                Image(systemName: "plus")
            }
            
            Menu {
                Button("Search", action: {})
                Button("Filter", action: {})
                Button("Sort", action: {})
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

struct IPhoneToolbarButtons: View {
    var body: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "plus")
            }
            
            Menu {
                Button("Search", action: {})
                Button("Filter", action: {})
                Button("Settings", action: {})
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(themeManager.currentTheme.primaryTextColor)
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Keyboard Shortcuts Support
struct KeyboardShortcutsView: View {
    var body: some View {
        VStack {
            Text("Keyboard Shortcuts")
                .font(.title2.bold())
                .padding()
            
            VStack(alignment: .leading, spacing: 8) {
                ShortcutRow(key: "⌘1", description: "Dashboard")
                ShortcutRow(key: "⌘2", description: "Tasks")
                ShortcutRow(key: "⌘3", description: "Goals")
                ShortcutRow(key: "⌘4", description: "Calendar")
                ShortcutRow(key: "⌘5", description: "Journal")
                ShortcutRow(key: "⌘,", description: "Settings")
                Divider()
                ShortcutRow(key: "⌘N", description: "New Item")
                ShortcutRow(key: "⌘F", description: "Search")
                ShortcutRow(key: "⌘R", description: "Refresh")
            }
            .padding()
        }
    }
}

struct ShortcutRow: View {
    let key: String
    let description: String
    
    var body: some View {
        HStack {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Text(description)
                .font(.body)
            
            Spacer()
        }
    }
}

#Preview {
    EnhancedPlatformNavigation {
        VStack {
            Text("Sample Content")
                .font(.title)
            Text("This shows enhanced platform navigation")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    .environmentObject(ThemeManager())
}
