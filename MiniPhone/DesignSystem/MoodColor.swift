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
        case .excited: return Color(red: 0.90, green: 0.55, blue: 0.20)
        }
    }
}
