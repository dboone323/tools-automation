// Simple test version of SettingsView to verify compilation

import Foundation
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            Text("Settings")
                .navigationTitle("Settings")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(ThemeManager())
    }
}
