import SwiftUI

/// 桌面上的一个图标。
///
/// 图标本身不依赖真实 App 的图片资源，全部由「渐变底座 + SF Symbol」拼成，
/// 这样既没有素材版权问题，也能保证在任何尺寸下都清晰。
struct PhoneApp: Identifiable, Hashable {
    /// 打开后去哪儿。
    enum Destination: Hashable {
        /// 真的能用：会话列表。
        case chat
        /// 真的能用：角色动态墙。
        case moments
        /// 真的能用：进设置。
        case settings
        /// 还没做，点了给一条提示。
        case placeholder
    }

    let id: String
    let name: String
    /// SF Symbol 名称。
    let symbol: String
    /// 图标底色渐变，从上到下。
    let colors: [Color]
    let destination: Destination
    /// 图形颜色。底色偏浅的图标（日历、备忘录这类）必须换成深色，否则白图形看不见。
    var symbolTint: Color = .white

    static func == (lhs: PhoneApp, rhs: PhoneApp) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 主屏图标清单。
///
/// 按真机主屏的排布顺序放，一页凑满 4×6。顺序本身是拟真的一部分：
/// 用户扫一眼认得出「这是 iPhone 的桌面」，靠的就是肌肉记忆里的位置。
enum AppCatalog {
    /// 主屏图标，24 个刚好一页。
    static let home: [PhoneApp] = [
        PhoneApp(id: "messages", name: "信息", symbol: "message.fill",
                 colors: [Color(red: 0.36, green: 0.94, blue: 0.46), Color(red: 0.10, green: 0.77, blue: 0.29)],
                 destination: .chat),
        PhoneApp(id: "phone", name: "电话", symbol: "phone.fill",
                 colors: [Color(red: 0.36, green: 0.90, blue: 0.42), Color(red: 0.13, green: 0.70, blue: 0.32)],
                 destination: .placeholder),
        PhoneApp(id: "facetime", name: "FaceTime 通话", symbol: "video.fill",
                 colors: [Color(red: 0.34, green: 0.90, blue: 0.44), Color(red: 0.10, green: 0.66, blue: 0.36)],
                 destination: .placeholder),
        PhoneApp(id: "mail", name: "邮件", symbol: "envelope.fill",
                 colors: [Color(red: 0.24, green: 0.68, blue: 0.99), Color(red: 0.06, green: 0.42, blue: 0.94)],
                 destination: .placeholder),

        PhoneApp(id: "safari", name: "Safari 浏览器", symbol: "safari.fill",
                 colors: [Color(red: 0.30, green: 0.78, blue: 0.99), Color(red: 0.10, green: 0.52, blue: 0.94)],
                 destination: .placeholder),
        PhoneApp(id: "photos", name: "照片", symbol: "photo.fill",
                 colors: [Color(red: 0.99, green: 0.86, blue: 0.36), Color(red: 0.95, green: 0.44, blue: 0.42)],
                 destination: .moments),
        PhoneApp(id: "camera", name: "相机", symbol: "camera.fill",
                 colors: [Color(red: 0.42, green: 0.43, blue: 0.46), Color(red: 0.17, green: 0.18, blue: 0.20)],
                 destination: .placeholder),
        PhoneApp(id: "clock", name: "时钟", symbol: "clock.fill",
                 colors: [Color(red: 0.16, green: 0.17, blue: 0.19), Color(red: 0.04, green: 0.04, blue: 0.05)],
                 destination: .placeholder),

        PhoneApp(id: "weather", name: "天气", symbol: "cloud.sun.fill",
                 colors: [Color(red: 0.32, green: 0.60, blue: 0.97), Color(red: 0.12, green: 0.34, blue: 0.78)],
                 destination: .placeholder),
        PhoneApp(id: "calendar", name: "日历", symbol: "calendar",
                 colors: [Color(red: 0.98, green: 0.98, blue: 0.98), Color(red: 0.90, green: 0.90, blue: 0.92)],
                 destination: .placeholder,
                 symbolTint: Color(white: 0.18)),
        PhoneApp(id: "notes", name: "备忘录", symbol: "note.text",
                 colors: [Color(red: 1.0, green: 0.96, blue: 0.76), Color(red: 0.99, green: 0.90, blue: 0.55)],
                 destination: .placeholder,
                 symbolTint: Color(red: 0.55, green: 0.42, blue: 0.12)),
        PhoneApp(id: "reminders", name: "提醒事项", symbol: "checklist",
                 colors: [Color(red: 0.99, green: 0.99, blue: 0.99), Color(red: 0.92, green: 0.92, blue: 0.94)],
                 destination: .placeholder,
                 symbolTint: Color(white: 0.18)),

        PhoneApp(id: "maps", name: "地图", symbol: "map.fill",
                 colors: [Color(red: 0.60, green: 0.86, blue: 0.56), Color(red: 0.32, green: 0.72, blue: 0.60)],
                 destination: .placeholder),
        PhoneApp(id: "music", name: "音乐", symbol: "music.note",
                 colors: [Color(red: 0.99, green: 0.35, blue: 0.42), Color(red: 0.95, green: 0.16, blue: 0.42)],
                 destination: .placeholder),
        PhoneApp(id: "podcasts", name: "播客", symbol: "waveform",
                 colors: [Color(red: 0.68, green: 0.44, blue: 0.94), Color(red: 0.44, green: 0.22, blue: 0.78)],
                 destination: .placeholder),
        PhoneApp(id: "appstore", name: "App Store", symbol: "storefront.fill",
                 colors: [Color(red: 0.32, green: 0.72, blue: 0.99), Color(red: 0.10, green: 0.44, blue: 0.92)],
                 destination: .placeholder),

        PhoneApp(id: "wallet", name: "钱包", symbol: "wallet.pass.fill",
                 colors: [Color(red: 0.18, green: 0.19, blue: 0.22), Color(red: 0.06, green: 0.06, blue: 0.08)],
                 destination: .placeholder),
        PhoneApp(id: "health", name: "健康", symbol: "heart.fill",
                 colors: [Color(red: 1.0, green: 0.99, blue: 0.99), Color(red: 0.94, green: 0.93, blue: 0.95)],
                 destination: .placeholder,
                 symbolTint: Color(red: 0.95, green: 0.24, blue: 0.36)),
        PhoneApp(id: "files", name: "文件", symbol: "folder.fill",
                 colors: [Color(red: 0.40, green: 0.74, blue: 0.99), Color(red: 0.16, green: 0.50, blue: 0.96)],
                 destination: .placeholder),
        PhoneApp(id: "shortcuts", name: "快捷指令", symbol: "sparkles",
                 colors: [Color(red: 0.52, green: 0.46, blue: 0.96), Color(red: 0.30, green: 0.24, blue: 0.82)],
                 destination: .placeholder),

        PhoneApp(id: "calculator", name: "计算器", symbol: "function",
                 colors: [Color(red: 0.20, green: 0.20, blue: 0.21), Color(red: 0.08, green: 0.08, blue: 0.09)],
                 destination: .placeholder),
        PhoneApp(id: "translate", name: "翻译", symbol: "translate",
                 colors: [Color(red: 0.34, green: 0.66, blue: 0.98), Color(red: 0.14, green: 0.40, blue: 0.88)],
                 destination: .placeholder),
        PhoneApp(id: "voice", name: "语音备忘录", symbol: "mic.fill",
                 colors: [Color(red: 0.22, green: 0.22, blue: 0.24), Color(red: 0.07, green: 0.07, blue: 0.08)],
                 destination: .placeholder),
        PhoneApp(id: "settings", name: "设置", symbol: "gearshape.fill",
                 colors: [Color(red: 0.62, green: 0.64, blue: 0.67), Color(red: 0.34, green: 0.36, blue: 0.39)],
                 destination: .settings)
    ]

    /// Dock 里的四个。信息放第一位，因为它是唯一每天都要点开的。
    static let dock: [PhoneApp] = [
        PhoneApp(id: "dock.messages", name: "信息", symbol: "message.fill",
                 colors: [Color(red: 0.36, green: 0.94, blue: 0.46), Color(red: 0.10, green: 0.77, blue: 0.29)],
                 destination: .chat),
        PhoneApp(id: "dock.safari", name: "Safari 浏览器", symbol: "safari.fill",
                 colors: [Color(red: 0.30, green: 0.78, blue: 0.99), Color(red: 0.10, green: 0.52, blue: 0.94)],
                 destination: .placeholder),
        PhoneApp(id: "dock.phone", name: "电话", symbol: "phone.fill",
                 colors: [Color(red: 0.36, green: 0.90, blue: 0.42), Color(red: 0.13, green: 0.70, blue: 0.32)],
                 destination: .placeholder),
        PhoneApp(id: "dock.settings", name: "设置", symbol: "gearshape.fill",
                 colors: [Color(red: 0.62, green: 0.64, blue: 0.67), Color(red: 0.34, green: 0.36, blue: 0.39)],
                 destination: .settings)
    ]
}
