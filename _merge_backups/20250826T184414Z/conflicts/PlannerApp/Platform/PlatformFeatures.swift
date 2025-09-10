//
//  PlatformFeatures.swift
//  PlannerApp
//
//  Platform-specific features for iOS, iPadOS, and macOS
//

import SwiftUI
#if os(iOS)
    import UIKit
    import WidgetKit
#elseif os(macOS)
    import AppKit
#endif

// MARK: - iOS Specific Features

#if os(iOS)
    // Widget support for iOS
    struct PlannerWidget: View {
        let tasks: [TaskModel]
        let goals: [Goal]

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Focus")
                    .font(.headline.bold())
                    .foregroundColor(.primary)

                if !tasks.isEmpty {
                    ForEach(tasks.prefix(3), id: \.id) { task in
                        HStack {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task.isCompleted ? .green : .gray)
                            Text(task.title)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                }

                if !goals.isEmpty {
                    Text("Active Goals")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    ForEach(goals.prefix(2), id: \.id) { goal in
                        HStack {
                            Image(systemName: "target")
                                .foregroundColor(.blue)
                            Text(goal.title)
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    // Shortcuts support
    enum ShortcutsIntentHandler {
        static func setupShortcuts() {
            // This would typically be implemented in a separate Intents extension
            // For now, we'll outline the structure
        }

        static func donateAddTaskIntent(taskTitle: String) {
            // Donate intent for Siri Shortcuts
        }

        static func donateAddGoalIntent(goalTitle: String) {
            // Donate intent for Siri Shortcuts
        }
    }

    // Live Activities support (iOS 16+)
    struct TaskProgressActivity: View {
        let taskTitle: String
        let progress: Double

        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text("Working on:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(taskTitle)
                        .font(.body.bold())
                        .lineLimit(1)
                }

                Spacer()

                VStack {
                    Text("\(Int(progress * 100))%")
                        .font(.title2.bold())
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
                .frame(width: 80)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    // Focus Modes integration
    enum FocusModeManager {
        static func configureFocusModes() {
            // Configure focus mode filters
            // This would integrate with iOS Focus Modes API
        }

        static func requestFocusPermission() {
            // Request permission to access focus status
        }
    }

#endif

// MARK: - iPadOS Specific Features

#if os(iOS)
    // Split View support for iPad
    struct SplitViewContainer<PrimaryContent: View, SecondaryContent: View>: View {
        let primaryContent: PrimaryContent
        let secondaryContent: SecondaryContent

        @Environment(\.horizontalSizeClass) var horizontalSizeClass

        init(@ViewBuilder primary: () -> PrimaryContent, @ViewBuilder secondary: () -> SecondaryContent) {
            self.primaryContent = primary()
            self.secondaryContent = secondary()
        }

        var body: some View {
            if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular {
                HStack(spacing: 0) {
                    primaryContent
                        .frame(maxWidth: .infinity)

                    Divider()

                    secondaryContent
                        .frame(maxWidth: .infinity)
                }
            } else {
                NavigationStack {
                    primaryContent
                }
            }
        }
    }

    // Scribble support for Apple Pencil
    struct ScribbleTextField: View {
        @Binding var text: String
        let placeholder: String

        var body: some View {
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onAppear {
                    // Enable Scribble for this text field
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        // Scribble is automatically supported in iOS 14+
                    }
                }
        }
    }

    // Drag and Drop support
    struct DragDropTaskView: View {
        let task: TaskModel
        let onDrop: (TaskModel) -> Void

        var body: some View {
            Text(task.title)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .draggable(task) {
                    Text(task.title)
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(8)
                }
                .dropDestination(for: TaskModel.self) { items, _ in
                    if let droppedTask = items.first {
                        onDrop(droppedTask)
                        return true
                    }
                    return false
                }
        }
    }

    // External keyboard support
    struct KeyboardShortcutHandler: View {
        @State private var isCommandKeyPressed = false

        var body: some View {
            Color.clear
                .onReceive(NotificationCenter.default.publisher(for: .init("KeyboardShortcut"))) { notification in
                    handleKeyboardShortcut(notification)
                }
        }

        private func handleKeyboardShortcut(_ notification: Notification) {
            guard let shortcut = notification.object as? String else { return }

            switch shortcut {
            case "cmd+n":
                // Handle new item
                break
            case "cmd+f":
                // Handle search
                break
            case "cmd+r":
                // Handle refresh
                break
            default:
                break
            }
        }
    }

#endif

// MARK: - macOS Specific Features

#if os(macOS)
    // Menu bar integration
    class MenuBarManager: ObservableObject {
        private var statusItem: NSStatusItem?

        func setupMenuBar() {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

            if let button = statusItem?.button {
                button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "PlannerApp")
                button.action = #selector(showQuickMenu)
                button.target = self
            }

            setupQuickMenu()
        }

        @objc private func showQuickMenu() {
            // Show quick actions menu
        }

        private func setupQuickMenu() {
            let menu = NSMenu()

            menu.addItem(NSMenuItem(title: "Quick Add Task", action: #selector(quickAddTask), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Quick Add Goal", action: #selector(quickAddGoal), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Show Dashboard", action: #selector(showDashboard), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Quit PlannerApp", action: #selector(quitApp), keyEquivalent: "q"))

            statusItem?.menu = menu
        }

        @objc private func quickAddTask() {
            // Implement quick add task
        }

        @objc private func quickAddGoal() {
            // Implement quick add goal
        }

        @objc private func showDashboard() {
            // Bring app to front
            NSApp.activate(ignoringOtherApps: true)
        }

        @objc private func quitApp() {
            NSApp.terminate(nil)
        }
    }

    // Touch Bar support (for compatible Macs)
    @available(macOS 10.12.2, *)
    class TouchBarProvider: NSViewController {
        // Add NSTouchBarDelegate conformance
        override func makeTouchBar() -> NSTouchBar? {
            let touchBar = NSTouchBar()
            touchBar.delegate = self
            touchBar.defaultItemIdentifiers = [
                .addTask,
                .addGoal,
                .search,
                .flexibleSpace,
                .calendar,
            ]

            return touchBar
        }
    }

    @available(macOS 10.12.2, *)
    extension TouchBarProvider: NSTouchBarDelegate {
        func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
            switch identifier {
            case .addTask:
                let item = NSCustomTouchBarItem(identifier: identifier)
                item.view = NSButton(title: "Add Task", target: self, action: #selector(addTask))
                return item

            case .addGoal:
                let item = NSCustomTouchBarItem(identifier: identifier)
                item.view = NSButton(title: "Add Goal", target: self, action: #selector(addGoal))
                return item

            case .search:
                let item = NSCustomTouchBarItem(identifier: identifier)
                item.view = NSButton(image: NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")!, target: self, action: #selector(search))
                return item

            case .calendar:
                let item = NSCustomTouchBarItem(identifier: identifier)
                item.view = NSButton(image: NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")!, target: self, action: #selector(showCalendar))
                return item

            default:
                return nil
            }
        }

        @objc private func addTask() {
            // Handle add task
        }

        @objc private func addGoal() {
            // Handle add goal
        }

        @objc private func search() {
            // Handle search
        }

        @objc private func showCalendar() {
            // Handle show calendar
        }
    }

    @available(macOS 10.12.2, *)
    extension NSTouchBarItem.Identifier {
        static let addTask = NSTouchBarItem.Identifier("com.plannerapp.addTask")
        static let addGoal = NSTouchBarItem.Identifier("com.plannerapp.addGoal")
        static let search = NSTouchBarItem.Identifier("com.plannerapp.search")
        static let flexibleSpace = NSTouchBarItem.Identifier.flexibleSpace
        static let calendar = NSTouchBarItem.Identifier("com.plannerapp.calendar")
    }

    // Multiple windows support
    enum WindowManager {
        static func openNewWindow(content: AnyView) {
            let windowController = NSWindowController(window: NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            ))

            windowController.window?.contentView = NSHostingView(rootView: content)
            windowController.window?.center()
            windowController.window?.makeKeyAndOrderFront(nil)
            windowController.showWindow(nil)
        }

        static func openPreferencesWindow() {
            // Implementation for preferences window
        }

        static func openQuickAddWindow() {
            // Implementation for quick add window
        }
    }

    // File system integration
    enum FileExportManager {
        static func exportToFile(_ data: some Codable, fileName: String) {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = fileName
            panel.allowedContentTypes = [.json]

            panel.begin { response in
                if response == .OK, let url = panel.url {
                    do {
                        let jsonData = try JSONEncoder().encode(data)
                        try jsonData.write(to: url)
                    } catch {
                        print("Export failed: \(error)")
                    }
                }
            }
        }

        static func importFromFile<T: Codable>(_ type: T.Type, completion: @escaping (T?) -> Void) {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.json]
            panel.allowsMultipleSelection = false

            panel.begin { response in
                if response == .OK, let url = panel.urls.first {
                    do {
                        let data = try Data(contentsOf: url)
                        let decoded = try JSONDecoder().decode(type, from: data)
                        completion(decoded)
                    } catch {
                        print("Import failed: \(error)")
                        completion(nil)
                    }
                }
            }
        }
    }

#endif

// MARK: - Cross-Platform Feature Interface

protocol PlatformFeatureProvider {
    func setupPlatformFeatures()
    func handleDeepLink(_ url: URL)
    func shareContent(_ content: String)
    func openSystemSettings()
}

// Platform-specific implementations
class iOSFeatureProvider: PlatformFeatureProvider {
    func setupPlatformFeatures() {
        #if os(iOS)
            ShortcutsIntentHandler.setupShortcuts()
            FocusModeManager.configureFocusModes()
        #endif
    }

    func handleDeepLink(_ url: URL) {
        // Handle iOS deep links
    }

    func shareContent(_ content: String) {
        #if os(iOS)
            let activityViewController = UIActivityViewController(activityItems: [content], applicationActivities: nil)
            // Present share sheet
        #endif
    }

    func openSystemSettings() {
        #if os(iOS)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        #endif
    }
}

class macOSFeatureProvider: PlatformFeatureProvider {
    func setupPlatformFeatures() {
        #if os(macOS)
            // Setup menu bar, touch bar, etc.
        #endif
    }

    func handleDeepLink(_ url: URL) {
        // Handle macOS URL schemes
    }

    func shareContent(_ content: String) {
        #if os(macOS)
            let sharingService = NSSharingService(named: .sendViaAirDrop)
            sharingService?.perform(withItems: [content])
        #endif
    }

    func openSystemSettings() {
        #if os(macOS)
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
        #endif
    }
}
