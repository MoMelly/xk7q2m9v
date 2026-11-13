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
                .environment(WorldStore.shared)
                // 键盘不参与整棵树的排版。
                //
                // 这是个铺满屏幕的假手机，系统那套「按键盘压窄内容区」在这里算出来的
                // 数不对：截图量到键盘高 335，它只给 244，顶部安全区还从 62 掉到 0。
                // 一旦让它算，外壳整体被压短、Home 屏从底下漏出来。
                // 关掉之后根区域永远是整屏，键盘占位由外壳自己让（见 PhoneShellView）。
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .modelContainer(AppStore.container)
    }
}
