import SwiftUI

@main
struct MiniPhoneApp: App {
    @State private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            SmokeTestView(settings: settings)
                .preferredColorScheme(.dark)
        }
    }
}
