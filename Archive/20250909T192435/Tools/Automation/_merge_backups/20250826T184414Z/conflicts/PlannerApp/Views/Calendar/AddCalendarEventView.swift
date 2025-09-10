import Foundation
import SwiftUI

struct AddCalendarEventView: View {
    @Environment(\.dismiss) var dismiss // Use dismiss environment
    @Binding var events: [CalendarEvent] // Assumes using model from PlannerApp/Models/

    @State private var title = ""
    @State private var date = Date()

    // Focus state for iOS keyboard management
    @FocusState private var isTitleFocused: Bool

    private var isTitleValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

                Text("New Event")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Button("Save") {
                    #if os(iOS)
                        HapticManager.notificationSuccess()
                    #endif
                    saveEvent()
                    dismiss()
                }
                #if os(iOS)
                .buttonStyle(.iOSPrimary)
                #endif
                .disabled(!isTitleValid)
                .foregroundColor(isTitleValid ? .blue : .gray)
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
                TextField("Event Title", text: $title)
                    .focused($isTitleFocused)
                #if os(iOS)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit {
                        isTitleFocused = false
                    }
                #endif
                DatePicker("Event Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
            }
            #if os(iOS)
            .iOSKeyboardDismiss()
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isTitleFocused = false
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

    private func saveEvent() {
        let newEvent = CalendarEvent(title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                     date: date)
        events.append(newEvent)

        // Save to persistent storage via data manager
        CalendarDataManager.shared.save(events: events)
    }
}

// struct AddCalendarEventView_Previews: PreviewProvider {
//     static var previews: some View {
//         AddCalendarEventView(events: .constant([]))
//     }
// }
