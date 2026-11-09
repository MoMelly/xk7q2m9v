import SwiftUI

/// 备用 App 图标的配色。
///
/// 这里的色值不是主题色，是**图标本身**：和 `scripts/make_alt_icons.py`
/// 画进 PNG 的那几组值一一对应。改这里必须同时改脚本重新出图，
/// 否则设置页里看到的预览和桌面上的图标会对不上。
///
/// 所以它单独成文件、单独留在颜色字面量白名单里——
/// 主题是「App 里面的颜色」，这一层是「桌面那一格的颜色」，两件事。
enum AppIconPalette {
    struct Palette: Identifiable {
        /// 系统图标名。nil 表示跟着默认图标走。
        var id: String?
        var name: String
        var detail: String
        var top: Color
        var bottom: Color
        var glyph: Color
    }

    /// 图标外框圆角。40pt 预览取自 iOS 自绘图标的比例（1024 里 230）。
    static let corner: CGFloat = 9
    /// 内里那块小屏幕的圆角。
    static let screenCorner: CGFloat = 4

    static let all: [Palette] = [
        Palette(
            id: nil,
            name: "默认",
            detail: "跟随系统的浅色外观",
            top: Color(red: 0.97, green: 0.96, blue: 0.92),
            bottom: Color(red: 0.62, green: 0.82, blue: 0.71),
            glyph: Color(red: 0.10, green: 0.22, blue: 0.18)
        ),
        Palette(
            id: "AppIconCream",
            name: "奶白",
            detail: "米白底，绿描边",
            top: Color(red: 0.98, green: 0.97, blue: 0.93),
            bottom: Color(red: 0.92, green: 0.93, blue: 0.88),
            glyph: Color(red: 0.29, green: 0.47, blue: 0.39)
        ),
        Palette(
            id: "AppIconNight",
            name: "夜里",
            detail: "近黑底，薄荷描边",
            top: Color(red: 0.10, green: 0.11, blue: 0.13),
            bottom: Color(red: 0.06, green: 0.07, blue: 0.08),
            glyph: Color(red: 0.62, green: 0.82, blue: 0.71)
        ),
        Palette(
            id: "AppIconForest",
            name: "深绿",
            detail: "墨绿底，米白描边",
            top: Color(red: 0.16, green: 0.32, blue: 0.26),
            bottom: Color(red: 0.07, green: 0.14, blue: 0.12),
            glyph: Color(red: 0.97, green: 0.96, blue: 0.92)
        )
    ]

    /// 系统图标名翻成中文。设置首页也用它。
    static func displayName(for iconName: String?) -> String {
        all.first { $0.id == iconName }?.name ?? "自定义"
    }
}
