// PlannerApp/Views/Journal/JournalView.swift (Biometrics Removed - v10)
import SwiftUI

// Removed LocalAuthentication import

struct JournalView: View {
    // Access shared ThemeManager and data/settings
    @EnvironmentObject var themeManager: ThemeManager
    @State private var journalEntries: [JournalEntry] = []
    @State private var showAddEntry = false
    @State private var searchText = ""

    // --- Security State REMOVED ---
    // @AppStorage(AppSettingKeys.journalBiometricsEnabled) private var biometricsEnabled: Bool = false
    // @State private var isUnlocked: Bool = true // Assume always unlocked now
    // @State private var showingAuthenticationError = false
    // @State private var authenticationErrorMsg = ""
    // @State private var isAuthenticating = false

    // Filtered and sorted entries
    private var filteredEntries: [JournalEntry] {
        let sorted = journalEntries.sorted(by: { $0.date > $1.date })
        if searchText.isEmpty { return sorted }
        return sorted.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.body.localizedCaseInsensitiveContains(searchText) ||
                $0.mood.contains(searchText)
        }
    }

    // Removed init() related to isUnlocked state

    var body: some View {
        NavigationStack {
            // Directly show journal content, bypassing lock checks
            journalContent
                .navigationTitle("Journal")
                .toolbar {
                    // Always show toolbar items
                    ToolbarItem(placement: .primaryAction) {
                        Button { showAddEntry.toggle() } label: { Image(systemName: "plus") }
                    }
                    ToolbarItem(placement: .navigation) {
                        Button("Edit") {
                            // Custom edit implementation for macOS
                        }
                    }
                }
                .sheet(isPresented: $showAddEntry) {
                    AddJournalEntryView(journalEntries: $journalEntries)
                        .environmentObject(themeManager) // Pass ThemeManager
                        .onDisappear(perform: saveEntries)
                }
                .onAppear {
                    print("[JournalView Simplified] onAppear.")
                    // Only load entries
                    loadEntries()
                }
                // Apply theme accent color to toolbar items
                .accentColor(themeManager.currentTheme.primaryAccentColor)
            // Removed alert for authentication errors

        } // End NavigationStack
        // Removed .onChange(of: biometricsEnabled)
    }

    // --- View Builder for Journal Content ---
    @ViewBuilder
    private var journalContent: some View {
        VStack(spacing: 0) {
            List {
                if journalEntries.isEmpty {
                    makeEmptyStateText("No journal entries yet. Tap '+' to add one.")
                } else if filteredEntries.isEmpty && !searchText.isEmpty {
                    makeEmptyStateText("No results found for \"\(searchText)\"")
                } else {
                    ForEach(filteredEntries) { entry in
                        NavigationLink {
                            JournalDetailView(entry: entry)
                                .environmentObject(themeManager)
                        } label: {
                            JournalRow(entry: entry)
                                .environmentObject(themeManager)
                        }
                    }
                    .onDelete(perform: deleteEntry) // Use the updated deleteEntry function
                    .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)
                }
            }
            .background(themeManager.currentTheme.primaryBackgroundColor)
            .scrollContentBackground(.hidden)
            .searchable(text: $searchText, prompt: "Search Entries")
        }
        .background(themeManager.currentTheme.primaryBackgroundColor.ignoresSafeArea())
    }

    // Helper for empty state text (Unchanged)
    private func makeEmptyStateText(_ text: String) -> some View {
        Text(text)
            .foregroundColor(themeManager.currentTheme.secondaryTextColor)
            .font(themeManager.currentTheme.font(forName: themeManager.currentTheme.secondaryFontName, size: 15))
            .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical)
    }

    // --- View Builder for Locked State (REMOVED) ---

    // --- Authentication Function (REMOVED) ---

    // --- Data Functions ---
    private func deleteEntry(at offsets: IndexSet) {
        print("[JournalView Simplified] deleteEntry called with offsets: \(offsets)")
        let idsToDelete = offsets.map { offset -> UUID in
            return filteredEntries[offset].id
        }
        print("[JournalView Simplified] IDs to delete: \(idsToDelete)")
        journalEntries.removeAll { entry in
            idsToDelete.contains(entry.id)
        }
        saveEntries()
    }

    private func loadEntries() {
        print("[JournalView Simplified] loadEntries called")
        journalEntries = JournalDataManager.shared.load()
        print("[JournalView Simplified] Loaded \(journalEntries.count) entries.")
    }

    private func saveEntries() {
        print("[JournalView Simplified] saveEntries called")
        JournalDataManager.shared.save(entries: journalEntries)
    }
}

// --- JournalRow Subview (Unchanged) ---
struct JournalRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let entry: JournalEntry

    private var rowDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(entry.title)
                    .font(themeManager.currentTheme.font(forName: themeManager.currentTheme.primaryFontName, size: 17, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.primaryTextColor)
                    .lineLimit(1)
                Text(entry.date, formatter: rowDateFormatter)
                    .font(themeManager.currentTheme.font(forName: themeManager.currentTheme.secondaryFontName, size: 14))
                    .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                Text(entry.body)
                    .font(themeManager.currentTheme.font(forName: themeManager.currentTheme.secondaryFontName, size: 13))
                    .foregroundColor(themeManager.currentTheme.secondaryTextColor.opacity(0.8))
                    .lineLimit(1)
            }
            Spacer()
            Text(entry.mood)
                .font(.system(size: 30))
        }
        .padding(.vertical, 5)
    }
}

// --- Preview Provider (Unchanged) ---
struct JournalView_Previews: PreviewProvider {
    static var previews: some View {
        JournalView()
            .environmentObject(ThemeManager())
    }
}
