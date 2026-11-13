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
        /// 应用商店：桌面上的图标被卸掉了，从这里装回来。
        case appStore
        /// 只读场景页，具体页面由 SceneKind 决定。
        case scene(SceneKind)
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
    /// 图形颜色。底色偏浅的图标必须换成深色，否则白图形看不见。
    var symbolTint: Color = .white
    /// 固定在桌面、不给卸。
    ///
    /// 应用商店是误删之后唯一的恢复入口，它自己被删掉就没有第二处能装回图标了。
    /// 这一格不进装卸列表，编辑态也不长减号。
    var isPinned: Bool = false

    static func == (lhs: PhoneApp, rhs: PhoneApp) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 主屏图标清单。
///
/// 按真机主屏的排布顺序放，一页凑满 4×6。顺序本身是拟真的一部分：
/// 用户扫一眼认得出「这是 iPhone 的桌面」，靠的就是肌肉记忆里的位置。
///
/// 配色统一走亮底：深色壁纸上的灰黑色图标会糊成一团，看起来发脏。
/// 需要深图形的地方用 `symbolTint` 单独指定。
enum AppCatalog {
    /// 主屏图标。
    ///
    /// 只放真的能用的：点开有内容、有东西可看。上一版为了「像真机」凑满 24 个，
    /// 其中一半是点了只弹一句「还没做」的占位——用户不会因为桌面像 iPhone 就高兴，
    /// 只会去点，然后发现是空的。电话、FaceTime、计算器这类功能没必要单独占一格：
    /// 通话已经进聊天，计算器没有任何场景。
    ///
    /// 和 Dock 严格不重叠：同一个 App 在桌面和底栏各出现一次，看起来像重复安装。
    /// 信息、西瓜皮、TA 的手机、设置这四个每天都要点的放进 Dock，桌面只留内容类的。
    static let home: [PhoneApp] = [
        PhoneApp(id: "music", name: "音乐", symbol: "music.note",
                 colors: [Color(red: 1.0, green: 0.46, blue: 0.52), Color(red: 0.97, green: 0.24, blue: 0.48)],
                 destination: .scene(.music)),

        PhoneApp(id: "calendar", name: "日历", symbol: "calendar",
                 colors: [Color(red: 1.0, green: 0.99, blue: 0.99), Color(red: 0.92, green: 0.93, blue: 0.96)],
                 destination: .scene(.calendar),
                 symbolTint: Color(red: 0.88, green: 0.26, blue: 0.28)),
        PhoneApp(id: "notes", name: "备忘录", symbol: "note.text",
                 colors: [Color(red: 1.0, green: 0.97, blue: 0.80), Color(red: 1.0, green: 0.92, blue: 0.60)],
                 destination: .scene(.notes),
                 symbolTint: Color(red: 0.56, green: 0.42, blue: 0.12)),
        // 「照片」这一格撤掉了。那个 App 是我自己加的，她没有要过：
        // 打开只有一屏空宫格，她也问过「这个 APP 到底干嘛的」。
        // 聊天发图、壁纸选图、头像选图各有自己的选择器，不经过它。
        // 2026-11-14 整块删除：PhotoLibraryScene 与 PhotoStore 一起拿掉。
        // 没有入口的壳子不算「以后可能用得上」，它只会让索引里多一条查不到的死路。
        // 真要做「给角色看照片」，重新设计，别翻旧代码。

        PhoneApp(id: "letters", name: "信件", symbol: "envelope.fill",
                 colors: [Color(red: 0.38, green: 0.78, blue: 1.0), Color(red: 0.14, green: 0.52, blue: 0.96)],
                 destination: .scene(.letters)),
        PhoneApp(id: "couple", name: "情侣空间", symbol: "flame.fill",
                 colors: [Color(red: 1.0, green: 0.62, blue: 0.70), Color(red: 0.90, green: 0.36, blue: 0.55)],
                 destination: .scene(.couple)),
        PhoneApp(id: "storygame", name: "文游", symbol: "text.book.closed.fill",
                 colors: [Color(red: 0.64, green: 0.56, blue: 0.98), Color(red: 0.42, green: 0.33, blue: 0.84)],
                 destination: .scene(.storyGame)),
        PhoneApp(id: "reading", name: "阅读", symbol: "books.vertical.fill",
                 colors: [Color(red: 1.0, green: 0.93, blue: 0.80), Color(red: 0.96, green: 0.80, blue: 0.58)],
                 destination: .scene(.reading),
                 symbolTint: Color(red: 0.46, green: 0.32, blue: 0.14)),
        // 应用商店放桌面，不放底栏：底栏固定四个是她定的。
        // 它是唯一的恢复入口，所以标记为不可卸。
        PhoneApp(id: "store", name: "应用商店", symbol: "bag.fill",
                 colors: [Color(red: 0.42, green: 0.72, blue: 1.0), Color(red: 0.20, green: 0.46, blue: 0.98)],
                 destination: .appStore,
                 isPinned: true)
    ]

    /// Dock 里固定四个。桌面上的同类入口已经全部撤掉，这里不再有第二份。
    ///
    /// 数量写死成四：多一格会让每个图标都变窄，也和真机底栏对不上。
    /// 应用商店原来占过第五格，已经挪回桌面第一屏。
    static let dock: [PhoneApp] = [
        PhoneApp(id: "dock.messages", name: "信息", symbol: "message.fill",
                 colors: [Color(red: 0.42, green: 0.96, blue: 0.54), Color(red: 0.16, green: 0.82, blue: 0.38)],
                 destination: .chat),
        PhoneApp(id: "dock.feed", name: "西瓜皮", symbol: "book.closed.fill",
                 colors: [Color(red: 1.0, green: 0.42, blue: 0.40), Color(red: 0.90, green: 0.14, blue: 0.22)],
                 destination: .scene(.feed)),
        PhoneApp(id: "dock.phonepeek", name: "TA 的手机", symbol: "iphone.gen3",
                 colors: [Color(red: 0.72, green: 0.74, blue: 0.86), Color(red: 0.44, green: 0.45, blue: 0.62)],
                 destination: .scene(.phonePeek)),
        PhoneApp(id: "dock.settings", name: "设置", symbol: "gearshape.fill",
                 colors: [Color(red: 0.86, green: 0.89, blue: 0.93), Color(red: 0.62, green: 0.67, blue: 0.74)],
                 destination: .settings,
                 symbolTint: Color(red: 0.20, green: 0.23, blue: 0.28))
    ]

    /// 默认不占桌面、但能从应用商店装上的。
    ///
    /// 动态墙之前只有外壳里的一个 destination，清单里找不到对应图标：
    /// 真机上点不到，截图状态也因为查不到 App 而退回主屏，拍出来是假图。
    /// 放进来之后两处都能走通；装不装由用户在商店里决定，默认桌面仍是 8 格。
    static let optional: [PhoneApp] = [
        PhoneApp(id: "moments", name: "动态", symbol: "newspaper.fill",
                 colors: [Color(red: 0.55, green: 0.80, blue: 0.95), Color(red: 0.26, green: 0.50, blue: 0.86)],
                 destination: .moments)
    ]

    /// 应用商店里能装回来的东西。固定的那格不参与装卸，否则没有恢复入口。
    static var installable: [PhoneApp] { home.filter { !$0.isPinned } + optional }

    /// 固定在桌面的 App id。老桌面布局里没有这些格子时会自动补上。
    static var pinnedIDs: [String] { home.filter(\.isPinned).map(\.id) }

    /// 清单里全部的 App。旧布局清理、图标查找都走这一份。
    static var all: [PhoneApp] { home + dock + optional }
}
