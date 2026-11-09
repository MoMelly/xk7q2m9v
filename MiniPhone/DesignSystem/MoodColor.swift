import SwiftUI

/// 心情对应的颜色。日程色条、状态点、健康页都用这一份，
/// 避免每个页面各调一档深浅，换配色时要全局搜。
enum MoodColor {
    static func of(_ mood: Mood) -> Color {
        switch mood {
        case .calm: return Color(red: 0.35, green: 0.55, blue: 0.45)
        case .glad: return Color(red: 0.20, green: 0.62, blue: 0.42)
        case .focused: return Color(red: 0.20, green: 0.48, blue: 0.85)
        case .tired: return Color(red: 0.45, green: 0.48, blue: 0.58)
        case .annoyed: return Color(red: 0.85, green: 0.35, blue: 0.30)
        case .low: return Color(red: 0.48, green: 0.42, blue: 0.62)
        case .excited:             return Color(red: 0.90, green: 0.55, blue: 0.20)
        }
    }

    /// 角色看板那种整屏底的渐变：上浅下深，同一心情取两档。
    ///
    /// 和 `of(_:)` 分开：那个是 1pt 宽色条的实色，这里是铺满一屏的底，
    /// 直接拿实色铺会让整屏亮得盖住头像。
    static func backdrop(_ mood: Mood?) -> [Color] {
        switch mood {
        case .glad, .excited:
            return [Theme.mint, Theme.retroGreen.opacity(0.9)]
        case .low, .tired:
            return [Color(red: 0.32, green: 0.36, blue: 0.48),
                    Color(red: 0.16, green: 0.18, blue: 0.26)]
        case .annoyed:
            return [Color(red: 0.62, green: 0.42, blue: 0.42),
                    Color(red: 0.30, green: 0.20, blue: 0.24)]
        case .focused:
            return [Color(red: 0.30, green: 0.46, blue: 0.52), Theme.deepGreen]
        default:
            return [Theme.retroGreen, Theme.deepGreen]
        }
    }
}
