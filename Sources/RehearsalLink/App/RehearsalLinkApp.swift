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
                    .frame(width: 500, height: 450)
            }
        #endif
    }
}
