import Observation
import SwiftUI
import UIKit

/// 主题色预设。
///
/// 每个都压过饱和度：满血的红绿蓝落在浅色页面上会晃眼，
/// 也会把图标里那些本身带色的图形盖掉。
enum AccentTheme: String, CaseIterable, Identifiable {
    case berry
    case retro
    case mist
    case lavender
    case clay
    case graphite
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .berry: return "莓果红"
        case .retro: return "复古绿"
        case .mist: return "雾蓝"
        case .lavender: return "薰衣草"
        case .clay: return "陶土"
        case .graphite: return "石墨"
        case .custom: return "自定义"
        }
    }

    /// 自定义那一档没有固定色，取用户自己挑的。
    ///
    /// 莓果红从 #E83A56 换到 #D93A3F：原来那个蓝分量太高，
    /// 大面积铺在浅色页面上会往品红偏，看着像没调准的粉。
    /// 压掉蓝、稍微提一点绿，落回正红，跟西瓜瓤对得上。
    var color: Color? {
        switch self {
        case .berry: return Color(red: 0.851, green: 0.216, blue: 0.231)
        case .retro: return Color(red: 0.29, green: 0.47, blue: 0.39)
        case .mist: return Color(red: 0.35, green: 0.50, blue: 0.66)
        case .lavender: return Color(red: 0.54, green: 0.48, blue: 0.79)
        case .clay: return Color(red: 0.79, green: 0.45, blue: 0.33)
        case .graphite: return Color(red: 0.24, green: 0.26, blue: 0.30)
        case .custom: return nil
        }
    }
}

/// 图标画法。
///
/// `glass` 是原来那套彩色渐变玻璃；另外三种是矢量版：
/// 底色只有白、黑、主题色三选一，图形统一走主题色，
/// 整套桌面看起来才是一套，而不是九个 App 各画各的。
enum IconStyle: String, CaseIterable, Identifiable {
    case glass
    case light
    case dark
    case tinted

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .glass: return "彩色玻璃"
        case .light: return "白底"
        case .dark: return "黑底"
        case .tinted: return "主题色底"
        }
    }

    var caption: String {
        switch self {
        case .glass: return "每个图标自己的配色，原来是这套"
        case .light: return "白色圆角底，图形跟着主题色走"
        case .dark: return "深色圆角底，图形提亮一档"
        case .tinted: return "主题色铺底，图形用白色"
        }
    }

    /// 是不是矢量版。矢量版不叠玻璃高光和斜反光。
    var isVector: Bool { self != .glass }
}

/// 日间 / 夜间。
///
/// 夜间不是换一套配色方案，而是在页面底色上压一层黑、文字转白。
/// 这样聊天页、动态页那些本来就深的地方不会翻两次。
enum AppearanceMode: String, CaseIterable, Identifiable {
    case day
    case night

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .day: return "日间"
        case .night: return "夜间"
        }
    }
}

/// 磨砂的厚薄。
///
/// 同一块底，白垫多一点就闷、少一点就飘。壁纸颜色深浅差很多，
/// 固定一个值总有一套壁纸不合适，所以给三档让用户自己找。
enum GlassDensity: String, CaseIterable, Identifiable {
    case thin
    case normal
    case thick

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .thin: return "通透"
        case .normal: return "标准"
        case .thick: return "厚实"
        }
    }

    var caption: String {
        switch self {
        case .thin: return "白垫得最少，壁纸颜色能整个透上来"
        case .normal: return "默认。能读清字，也看得出底下是什么"
        case .thick: return "白多一层，压花的壁纸上面字更清楚"
        }
    }

    /// 乘在原来的白垫上。1 是不改。
    var factor: Double {
        switch self {
        case .thin: return 0.68
        case .normal: return 1
        case .thick: return 1.45
        }
    }
}

/// 主题的唯一读写入口。
///
/// 跟 `SettingsStore` 一样走 UserDefaults，`@Observable` 让改了立刻生效；
/// 不挂在 `SettingsStore` 里是为了让「外观」这一摊有自己的key空间，
/// 以后加图标形状、字体也不用再动接口那一套参数。
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    private enum DefaultsKey {
        static let accent = "theme.accent"
        static let customAccent = "theme.customAccent"
        static let iconStyle = "theme.iconStyle"
        static let appearance = "theme.appearance"
        static let glassDensity = "theme.glassDensity"
    }

    var accentRaw: String = AccentTheme.berry.rawValue
    /// 自定义主题色的十六进制，形如 `#E93A56`。
    var customAccentHex: String = "#E93A56"
    var iconStyleRaw: String = IconStyle.glass.rawValue
    var appearanceRaw: String = AppearanceMode.day.rawValue
    var glassDensityRaw: String = GlassDensity.normal.rawValue

    init() {
        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: DefaultsKey.accent) {
            accentRaw = stored
        }
        if let stored = defaults.string(forKey: DefaultsKey.customAccent) {
            customAccentHex = stored
        }
        if let stored = defaults.string(forKey: DefaultsKey.iconStyle) {
            iconStyleRaw = stored
        }
        if let stored = defaults.string(forKey: DefaultsKey.appearance) {
            appearanceRaw = stored
        }
        if let stored = defaults.string(forKey: DefaultsKey.glassDensity) {
            glassDensityRaw = stored
        }
    }

    // MARK: - 派生值

    var accentTheme: AccentTheme {
        AccentTheme(rawValue: accentRaw) ?? .berry
    }

    var accent: Color {
        accentTheme.color ?? Color(hex: customAccentHex) ?? Color(red: 0.851, green: 0.216, blue: 0.231)
    }

    /// 比主题色压暗一档。价格、强调文字用它，同一个色相才有主次。
    var accentDeep: Color {
        Self.shift(accent, saturation: 1.08, brightness: 0.84)
    }

    /// 比主题色提亮一档。黑底图标上的图形用它，压太暗会糊进底色。
    var accentLight: Color {
        Self.shift(accent, saturation: 0.86, brightness: 1.28)
    }

    var iconStyle: IconStyle {
        IconStyle(rawValue: iconStyleRaw) ?? .glass
    }

    var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .day
    }

    var isNight: Bool { appearance == .night }

    var glassDensity: GlassDensity {
        GlassDensity(rawValue: glassDensityRaw) ?? .normal
    }

    /// 磨砂白垫要乘的系数。`FrostedSurface` 唯一取它的地方。
    var glassFactor: Double { glassDensity.factor }

    // MARK: - 写入

    func select(_ theme: AccentTheme) {
        accentRaw = theme.rawValue
        persist()
    }

    func select(custom color: Color) {
        accentRaw = AccentTheme.custom.rawValue
        customAccentHex = color.hexString
        persist()
    }

    func select(_ style: IconStyle) {
        iconStyleRaw = style.rawValue
        persist()
    }

    func select(_ mode: AppearanceMode) {
        appearanceRaw = mode.rawValue
        persist()
    }

    func select(_ density: GlassDensity) {
        glassDensityRaw = density.rawValue
        persist()
    }

    func persist() {
        let defaults = UserDefaults.standard
        defaults.set(accentRaw, forKey: DefaultsKey.accent)
        defaults.set(customAccentHex, forKey: DefaultsKey.customAccent)
        defaults.set(iconStyleRaw, forKey: DefaultsKey.iconStyle)
        defaults.set(appearanceRaw, forKey: DefaultsKey.appearance)
        defaults.set(glassDensityRaw, forKey: DefaultsKey.glassDensity)
    }

    // MARK: - 色彩计算

    private static func shift(_ color: Color, saturation: CGFloat, brightness: CGFloat) -> Color {
        var hue: CGFloat = 0
        var sat: CGFloat = 0
        var bri: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(color).getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha) else {
            return color
        }
        return Color(
            hue: Double(hue),
            saturation: Double(min(1, sat * saturation)),
            brightness: Double(min(1, bri * brightness)),
            opacity: Double(alpha)
        )
    }
}

extension Color {
    /// 支持 `#RRGGBB` 与 `#RGB` 两种写法，写错返回 nil 让上层退回默认色。
    init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        if text.count == 3 {
            text = text.map { "\($0)\($0)" }.joined()
        }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "#%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255))
        )
    }
}
