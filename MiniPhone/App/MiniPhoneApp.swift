import SwiftUI
import SwiftData

@main
struct MiniPhoneApp: App {
    @State private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            // 外壳永远是深色：液态玻璃要在深色底上才有折射感，
            // 跟随系统切到浅色会让整套观感垮掉。
            PhoneShellView(settings: settings)
                .preferredColorScheme(.dark)
                .task {
                    await ReplyNotifier.requestAuthorizationIfNeeded()
                }
        }
        .modelContainer(AppStore.container)
    }
}
