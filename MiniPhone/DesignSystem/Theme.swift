import SwiftUI

/// 白 + 复古绿的色板。刻意压暗、压低饱和，
/// 避免那种一眼看上去像模板 App 的亮绿色。
enum Theme {
    static let ink = Color(red: 0.07, green: 0.11, blue: 0.10)
    static let deepGreen = Color(red: 0.10, green: 0.22, blue: 0.18)
    static let retroGreen = Color(red: 0.29, green: 0.47, blue: 0.39)
    static let mint = Color(red: 0.62, green: 0.82, blue: 0.71)
    static let cream = Color(red: 0.97, green: 0.96, blue: 0.92)
    /// 错误提示用的暖红。压暗过，深色底上不刺眼。
    static let warning = Color(red: 1.0, green: 0.62, blue: 0.55)

    /// 设置页与场景页的浅色体系。
    ///
    /// 外壳是深色模式，这些必须写成绝对色值，不能用 `.primary` 之类会跟着配色方案
    /// 翻转的语义色。夜间由 `ThemeStore` 统一翻过来，页面不用各写一套。
    static var settingsBackground: Color {
        ThemeStore.shared.isNight
            ? Color(red: 0.10, green: 0.10, blue: 0.12)
            : Color(red: 0.95, green: 0.96, blue: 0.97)
    }
    static var cardSurface: Color {
        ThemeStore.shared.isNight
            ? Color(red: 0.16, green: 0.16, blue: 0.18)
            : Color(red: 1.0, green: 1.0, blue: 1.0)
    }
    static var secondaryInk: Color {
        ThemeStore.shared.isNight
            ? Color.white.opacity(0.58)
            : Color(red: 0.43, green: 0.45, blue: 0.48)
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [deepGreen, ink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    // MARK: - 浅色 App 的语义色

    /// systemGroupedBackground。浅色 App 的页面底色，夜间压成近黑。
    static var groupedBackground: Color {
        ThemeStore.shared.isNight
            ? Color(red: 0.08, green: 0.08, blue: 0.10)
            : Color(red: 0.949, green: 0.949, blue: 0.969)
    }
    /// 分组列表里的行与卡片。
    static var rowSurface: Color {
        ThemeStore.shared.isNight
            ? Color(red: 0.15, green: 0.15, blue: 0.17)
            : Color.white
    }
    /// 浅色 App 的主文字。
    static var label: Color {
        ThemeStore.shared.isNight ? Color.white : Color.black
    }
    /// 浅色 App 的次文字。
    static var secondaryLabel: Color {
        ThemeStore.shared.isNight
            ? Color.white.opacity(0.55)
            : Color(red: 0.235, green: 0.235, blue: 0.263).opacity(0.6)
    }
    /// 行内分隔线。
    static var separator: Color {
        ThemeStore.shared.isNight
            ? Color.white.opacity(0.14)
            : Color(red: 0.776, green: 0.776, blue: 0.784)
    }
    /// 系统蓝。浅色 App 的 tint，夜里提亮一档。
    static var tint: Color {
        ThemeStore.shared.isNight
            ? Color(red: 0.36, green: 0.62, blue: 1.0)
            : Color(red: 0.0, green: 0.478, blue: 1.0)
    }
    /// 品牌色。以前写死一个番茄红，现在跟主题走；
    /// 选中态、加购按钮、价格都读这里，换主题色整套界面一起变。
    static var brand: Color { ThemeStore.shared.accent }
    /// 价格数字，比品牌色再深一档，白底上更立得住。
    static var price: Color { ThemeStore.shared.accentDeep }
    /// 笔记里的话题链接蓝。
    static let link = Color(red: 0.20, green: 0.42, blue: 0.86)

    /// 设置页、场景页左侧彩色小图标的底色。视图里不写字面色值，都从这里取。
    enum IconTint {
        static let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
        static let purple = Color(red: 0.45, green: 0.40, blue: 0.80)
        static let pink = Color(red: 0.90, green: 0.35, blue: 0.42)
        static let gray = Color(red: 0.48, green: 0.50, blue: 0.55)
        static let green = Color(red: 0.35, green: 0.60, blue: 0.40)
        static let indigo = Color(red: 0.55, green: 0.42, blue: 0.78)
        static let teal = Color(red: 0.20, green: 0.62, blue: 0.66)
        static let yellow = Color(red: 0.93, green: 0.72, blue: 0.18)
        /// 情侣空间的玫瑰色。比 `pink` 淡一档，那个番茄红压在大面积卡片上太吵。
        static let rose = Color(red: 0.90, green: 0.42, blue: 0.58)
    }

    /// 「西瓜皮」自己的那套色。
    ///
    /// 底色还是社交产品惯用的红，但图标和默认头像用真西瓜：绿皮、白瓤、红瓤、黑籽。
    /// 界面上不出现第二套主色——红是它的品牌红，绿只用在西瓜图形上。
    ///
    /// 每个色都给三段：切片是半透明玻璃质感，靠同色系明暗差做厚度，
    /// 单色画出来是一块塑料片。
    enum Watermelon {
        static let rindLight = Color(red: 0.45, green: 0.76, blue: 0.40)
        static let rind = Color(red: 0.22, green: 0.55, blue: 0.27)
        static let pith = Color(red: 0.96, green: 0.98, blue: 0.92)
        static let fleshLight = Color(red: 0.98, green: 0.38, blue: 0.40)
        static let flesh = Color(red: 0.90, green: 0.22, blue: 0.28)
        static let fleshDeep = Color(red: 0.76, green: 0.12, blue: 0.20)
        static let seed = Color(red: 0.16, green: 0.14, blue: 0.13)
    }

    /// 图标与桌面那一层的固定色。
    ///
    /// 矢量图标只有白底、黑底两种硬底，这两个值不跟主题走——
    /// 跟了就会变成「白底跟着主题变粉」，那就不是白底了。
    enum IconSurface {
        static let lightTop = Color(red: 1.0, green: 1.0, blue: 1.0)
        static let lightBottom = Color(red: 0.94, green: 0.94, blue: 0.955)
        static let darkTop = Color(red: 0.19, green: 0.19, blue: 0.21)
        static let darkBottom = Color(red: 0.09, green: 0.09, blue: 0.11)
        /// 图标下面那行名字。日间深、夜间白。
        static let labelDay = Color(red: 0.16, green: 0.15, blue: 0.17)
        /// 假状态栏的字，日间深。
        static let statusDay = Color(red: 0.20, green: 0.19, blue: 0.22)
        /// 桌面页码点，日间深。
        static let pageDotDay = Color(red: 0.30, green: 0.28, blue: 0.32)
        /// 主题页里日间 / 夜间两张小预览卡的底色。
        static let dayPreview = Color(red: 0.98, green: 0.93, blue: 0.94)
        static let nightPreview = Color(red: 0.12, green: 0.12, blue: 0.14)
        static let sunGlyph = Color(red: 0.93, green: 0.55, blue: 0.22)
        static let moonGlyph = Color(red: 0.72, green: 0.76, blue: 0.95)
    }

    /// 模拟照片的配色。
    ///
    /// 私聊里能发的那几张「图」不读图片文件，全按 seed 现画，
    /// 八种场景各有一套固定色，写在这里是因为视图层不碰字面色值。
    enum PhotoSurface {
        // 黄昏：天光往下压，山分远近两层
        static let duskSkyTop = Color(red: 0.99, green: 0.76, blue: 0.50)
        static let duskSkyMid = Color(red: 0.96, green: 0.56, blue: 0.56)
        static let duskSkyLow = Color(red: 0.58, green: 0.40, blue: 0.62)
        static let duskSun = Color(red: 1.0, green: 0.94, blue: 0.80)
        static let duskHillFar = Color(red: 0.44, green: 0.31, blue: 0.50)
        static let duskHillNear = Color(red: 0.21, green: 0.16, blue: 0.29)

        // 雨窗：冷灰蓝，玻璃上有一层雾
        static let rainTop = Color(red: 0.38, green: 0.45, blue: 0.53)
        static let rainBottom = Color(red: 0.22, green: 0.28, blue: 0.35)
        static let rainDrop = Color(red: 0.83, green: 0.89, blue: 0.94)
        static let rainSill = Color(red: 0.16, green: 0.20, blue: 0.26)

        // 夜空：深蓝到近黑，月亮带一圈晕
        static let nightTop = Color(red: 0.09, green: 0.11, blue: 0.22)
        static let nightBottom = Color(red: 0.20, green: 0.24, blue: 0.40)
        static let nightMoon = Color(red: 0.96, green: 0.95, blue: 0.86)

        // 咖啡：木色桌面 + 深褐液面
        static let coffeeTable = Color(red: 0.87, green: 0.78, blue: 0.66)
        static let coffeeTableEdge = Color(red: 0.75, green: 0.63, blue: 0.50)
        static let coffeeCup = Color(red: 0.98, green: 0.97, blue: 0.94)
        static let coffeeLiquid = Color(red: 0.42, green: 0.27, blue: 0.18)
        static let coffeeCrema = Color(red: 0.62, green: 0.45, blue: 0.32)

        // 猫：米色底，一只坐着的剪影
        static let catWall = Color(red: 0.93, green: 0.87, blue: 0.80)
        static let catFloor = Color(red: 0.82, green: 0.73, blue: 0.64)
        static let catBody = Color(red: 0.36, green: 0.30, blue: 0.27)

        // 海：天空比水浅一档，中间一条硬地平线
        static let seaSkyTop = Color(red: 0.72, green: 0.86, blue: 0.91)
        static let seaSkyLow = Color(red: 0.93, green: 0.90, blue: 0.85)
        static let seaWater = Color(red: 0.29, green: 0.55, blue: 0.62)
        static let seaWaterDeep = Color(red: 0.19, green: 0.40, blue: 0.48)

        // 云：淡蓝底，云团偏白
        static let cloudSkyTop = Color(red: 0.62, green: 0.80, blue: 0.92)
        static let cloudSkyLow = Color(red: 0.87, green: 0.93, blue: 0.96)
        static let cloudPuff = Color(red: 1.0, green: 1.0, blue: 1.0)

        // 灯串：夜色里一串暖点
        static let lampNightTop = Color(red: 0.11, green: 0.12, blue: 0.20)
        static let lampNightBottom = Color(red: 0.27, green: 0.22, blue: 0.28)
        static let lampGlow = Color(red: 1.0, green: 0.85, blue: 0.58)
    }

    /// 阴影只有三档。
    /// 浅色分组列表默认不用——给每行都加阴影，浅底上会叠出一圈灰边。
    enum ShadowStyle {
        case none
        case soft
        case lifted

        var color: Color {
            switch self {
            case .none: return .clear
            case .soft: return Color.black.opacity(0.06)
            case .lifted: return Color.black.opacity(0.12)
            }
        }

        var radius: CGFloat {
            switch self {
            case .none: return 0
            case .soft: return 6
            case .lifted: return 16
            }
        }

        var y: CGFloat {
            switch self {
            case .none: return 0
            case .soft: return 2
            case .lifted: return 8
            }
        }
    }

    /// 玻璃的底座色。
    ///
    /// `glassEffect` 的 tint 决定这块玻璃「压在什么东西上」：
    /// 压深色，玻璃就沉下去；垫白色，玻璃就浮起来。
    /// 同一个玻璃档两侧要用不同的底座，才有「谁在说话」的明度差。
    enum Glass {
        /// 角色气泡：黑压进玻璃，比背景沉一档。
        static let bubbleCharacter = Color.black.opacity(0.26)
        /// 我的气泡：白垫进玻璃，比背景亮一档。
        static let bubbleUser = Color.white.opacity(0.14)

        /// 气泡边缘那道极细的亮边，日间 / 夜间各一档。
        static let bubbleRimCharacter = Color.white.opacity(0.12)
        static let bubbleRimUser = Color.white.opacity(0.22)

        /// 主屏 Dock。数值偏低是有意的：整块要透出壁纸，
        /// 太满就成了白塑料板，和系统那种玻璃不是一回事。
        static let dockDay = Color.white.opacity(0.26)
        static let dockNight = Color.white.opacity(0.10)
        /// Dock 顶沿的高光，一道就行。
        static let dockRim = Color.white.opacity(0.5)
    }
}
