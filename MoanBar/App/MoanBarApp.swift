import SwiftUI

@main
struct MoanBarApp: App {

    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        // Menu bar icon + popover window
        MenuBarExtra {
            MenuBarView()
                .environmentObject(viewModel)
        } label: {
            // Use SF Symbol; swap for a custom NSImage asset later.
            Label("MoanBar", systemImage: "hand.tap.fill")
        }
        .menuBarExtraStyle(.window)

        // Settings window — opened via Cmd-, or from the menu
        Settings {
            SettingsView()
                .environmentObject(viewModel)
                .frame(width: 500)
        }
    }
}
