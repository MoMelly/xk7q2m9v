import SwiftUI
import SwiftData

@main
struct MiniPhoneApp: App {
    @State private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            // 外壳永远是深色：液态玻璃要在深色底上才有折射感，
            // 跟随系统切到浅色会让整套观感垮掉。
            // 通知权限不在这里申请：授权框会盖住锁屏，且用户还没表达过
            // 需不需要提醒。请求点放在设置开关与第一条回复投递前。
            PhoneShellView(settings: settings)
                .preferredColorScheme(.dark)
        }
        .modelContainer(AppStore.container)
    }
}
