//
//  PlatformAdaptiveNavigation.swift
//  PlannerApp
//
//  Platform-specific navigation that adapts to iOS, iPadOS, and macOS
//

import SwiftUI

struct PlatformAdaptiveNavigation<Content: View>: View {
    let content: Content
    @EnvironmentObject var themeManager: ThemeManager
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            SidebarView()
        } detail: {
            content
        }
        .navigationSplitViewStyle(.balanced)
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad layout
            NavigationSplitView {
                SidebarView()
            } detail: {
                content
            }
        } else {
            // iPhone layout
            NavigationStack {
                content
            }
        }
        #endif
    }
}

struct SidebarView: View {
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
            case .dashboard: return "house.fill"
            case .tasks: return "checkmark.circle.fill"
            case .goals: return "target"
            case .calendar: return "calendar"
            case .journal: return "book.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    var body: some View {
        #if os(macOS)
        List(Tab.allCases, id: \.self, selection: $selectedTab) { tab in
            NavigationLink(value: tab) {
                Label(tab.rawValue, systemImage: tab.icon)
            }
        }
        .navigationTitle("PlannerApp")
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
        #else
        // iOS/iPadOS: Use regular List without selection binding
        List(Tab.allCases, id: \.self) { tab in
            NavigationLink(value: tab) {
                Label(tab.rawValue, systemImage: tab.icon)
            }
        }
        .navigationTitle("PlannerApp")
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
        #endif
    }
}

// MARK: - Platform-Specific Toolbar

struct PlatformToolbar: ViewModifier {
    let title: String
    let primaryActions: [ToolbarAction]
    let secondaryActions: [ToolbarAction]
    
    struct ToolbarAction {
        let title: String
        let icon: String
        let action: () -> Void
        let isDestructive: Bool
        
        init(title: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) {
            self.title = title
            self.icon = icon
            self.isDestructive = isDestructive
            self.action = action
        }
    }
    
    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .toolbar {
                #if os(macOS)
                ToolbarItemGroup(placement: .primaryAction) {
                    ForEach(primaryActions.indices, id: \.self) { index in
                        let action = primaryActions[index]
                        Button(action: action.action) {
                            Label(action.title, systemImage: action.icon)
                        }
                        .help(action.title)
                    }
                }
                
                ToolbarItemGroup(placement: .secondaryAction) {
                    Menu("More") {
                        ForEach(secondaryActions.indices, id: \.self) { index in
                            let action = secondaryActions[index]
                            Button(action.title, action: action.action)
                        }
                    }
                }
                #else
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    ForEach(primaryActions.indices, id: \.self) { index in
                        let action = primaryActions[index]
                        Button(action: action.action) {
                            Image(systemName: action.icon)
                        }
                    }
                    
                    if !secondaryActions.isEmpty {
                        Menu {
                            ForEach(secondaryActions.indices, id: \.self) { index in
                                let action = secondaryActions[index]
                                Button(action.title, action: action.action)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                #endif
            }
    }
}

extension View {
    func platformToolbar(
        title: String,
        primaryActions: [PlatformToolbar.ToolbarAction] = [],
        secondaryActions: [PlatformToolbar.ToolbarAction] = []
    ) -> some View {
        modifier(PlatformToolbar(
            title: title,
            primaryActions: primaryActions,
            secondaryActions: secondaryActions
        ))
    }
}

// MARK: - Platform-Specific Context Menu

struct PlatformContextMenu<MenuContent: View>: ViewModifier {
    let menuContent: MenuContent
    
    init(@ViewBuilder menuContent: () -> MenuContent) {
        self.menuContent = menuContent()
    }
    
    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .contextMenu {
                menuContent
            }
        #else
        content
            .contextMenu {
                menuContent
            }
        #endif
    }
}

extension View {
    func platformContextMenu<MenuContent: View>(
        @ViewBuilder menuContent: () -> MenuContent
    ) -> some View {
        modifier(PlatformContextMenu(menuContent: menuContent))
    }
}

// MARK: - Adaptive Grid Layout

struct AdaptiveGrid<Content: View>: View {
    let content: Content
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    private var columns: [GridItem] {
        #if os(macOS)
        return Array(repeating: .init(.flexible()), count: 3)
        #else
        if horizontalSizeClass == .regular {
            // iPad or iPhone landscape
            return Array(repeating: .init(.flexible()), count: 2)
        } else {
            // iPhone portrait
            return [.init(.flexible())]
        }
        #endif
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            content
        }
    }
}

// MARK: - Platform-Specific Sheet Presentation

struct PlatformSheet<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let sheetContent: SheetContent
    
    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> SheetContent) {
        self._isPresented = isPresented
        self.sheetContent = content()
    }
    
    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .sheet(isPresented: $isPresented) {
                self.sheetContent
                    .frame(minWidth: 400, minHeight: 300)
            }
        #else
        content
            .sheet(isPresented: $isPresented) {
                NavigationStack {
                    self.sheetContent
                }
            }
        #endif
    }
}

extension View {
    func platformSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: () -> SheetContent
    ) -> some View {
        modifier(PlatformSheet(isPresented: isPresented, content: content))
    }
}

// MARK: - Example Usage

struct ExamplePlatformView: View {
    @State private var showingAddItem = false
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        PlatformAdaptiveNavigation {
            ScrollView {
                AdaptiveGrid {
                    ForEach(0..<6, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.currentTheme.secondaryBackgroundColor)
                            .frame(height: 120)
                            .overlay(
                                Text("Item \(index + 1)")
                                    .foregroundColor(themeManager.currentTheme.primaryTextColor)
                            )
                            .platformContextMenu {
                                Button("Edit") { }
                                Button("Delete", role: .destructive) { }
                            }
                    }
                }
                .padding()
            }
            .platformToolbar(
                title: "Example View",
                primaryActions: [
                    .init(title: "Add Item", icon: "plus") {
                        showingAddItem = true
                    }
                ],
                secondaryActions: [
                    .init(title: "Sort", icon: "arrow.up.arrow.down") { },
                    .init(title: "Filter", icon: "line.3.horizontal.decrease.circle") { }
                ]
            )
            .platformSheet(isPresented: $showingAddItem) {
                Text("Add Item Sheet")
                    .navigationTitle("Add Item")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingAddItem = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                showingAddItem = false
                            }
                        }
                    }
            }
        }
    }
}

#Preview {
    ExamplePlatformView()
        .environmentObject(ThemeManager())
}
