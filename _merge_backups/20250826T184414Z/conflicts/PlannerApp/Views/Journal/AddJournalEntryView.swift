import SwiftUI
import Foundation

struct AddJournalEntryView: View {
    @Environment(\.dismiss) var dismiss // Use dismiss environment
    @Binding var journalEntries: [JournalEntry] // Assumes using model from PlannerApp/Models/

    @State private var title = ""
    @State private var entryBody = "" // Renamed for clarity
    @State private var date = Date()
    @State private var mood = "😊" // Default mood
    
    // Focus states for iOS keyboard management
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isEntryBodyFocused: Bool

    let moods = ["😊", "😢", "😡", "😌", "😔", "🤩", "🥱", "🤔", "🥳", "😐"] // Expanded moods

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !entryBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with buttons for better macOS compatibility
            HStack {
                Button("Cancel") {
                    #if os(iOS)
                    HapticManager.lightImpact()
                    #endif
                    dismiss()
                }
                #if os(iOS)
                .buttonStyle(.iOSSecondary)
                #endif
                .foregroundColor(.blue)
                
                Spacer()
                
                Text("New Journal Entry")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Save") {
                    #if os(iOS)
                    HapticManager.notificationSuccess()
                    #endif
                    saveEntry()
                    dismiss()
                }
                #if os(iOS)
                .buttonStyle(.iOSPrimary)
                #endif
                .disabled(!isFormValid)
                .foregroundColor(isFormValid ? .blue : .gray)
            }
            .padding()
            #if os(macOS)
            .background(Color(NSColor.controlBackgroundColor))
            #else
            .background(Color(.systemBackground))
            #endif
            #if os(iOS)
            .iOSEnhancedTouchTarget()
            #endif
            
            Form {
                TextField("Title", text: $title)
                    .focused($isTitleFocused)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .onSubmit {
                        isTitleFocused = false
                        isEntryBodyFocused = true
                    }
                    #endif

                // Consider a Segmented Picker for fewer options or keep Wheel
                Picker("Mood", selection: $mood) {
                    ForEach(moods, id: \.self) { mood in
                        Text(mood).tag(mood) // Ensure tag is set for selection
                    }
                }
                #if os(iOS)
                .pickerStyle(.menu) // Better for iOS touch interaction
                .onChange(of: mood) { _, _ in
                    HapticManager.selectionChanged()
                }
                #endif

                DatePicker("Date", selection: $date, displayedComponents: .date)

                Section("Entry") { // Use Section header
                    TextEditor(text: $entryBody) // Use entryBody state variable
                        .frame(height: 200) // Increased height
                        .focused($isEntryBodyFocused)
                        #if os(iOS)
                        .scrollContentBackground(.hidden)
                        #endif
                }
            }
            #if os(iOS)
            .iOSKeyboardDismiss()
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isTitleFocused = false
                            isEntryBodyFocused = false
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .buttonStyle(.iOSPrimary)
                        .foregroundColor(.blue)
                        .font(.body.weight(.semibold))
                    }
                }
            }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 400)
        #else
        .iOSPopupOptimizations()
        #endif
    }

    private func saveEntry() {
        let newEntry = JournalEntry(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: entryBody.trimmingCharacters(in: .whitespacesAndNewlines), // Use entryBody
            date: date,
            mood: mood
        )
        journalEntries.append(newEntry)
        
        // Save to persistent storage via data manager
        JournalDataManager.shared.save(entries: journalEntries)
    }
}

// struct AddJournalEntryView_Previews: PreviewProvider {
//     static var previews: some View {
//         AddJournalEntryView(journalEntries: .constant([]))
//     }
// }
