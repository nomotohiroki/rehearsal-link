import SwiftUI

@main
struct RehearsalLinkApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }

        #if os(macOS)
            Settings {
                AISettingsView()
            }
        #endif
    }
}
