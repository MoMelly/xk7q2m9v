import SwiftUI

/// 桌面/锁屏上文字与状态栏的颜色档。
///
/// 她换深色壁纸时日间模式的黑字全看不见，又不想为这个切深色模式——
/// 所以给一个手动档：自动（跟日夜）、白、黑。选完写 UserDefaults，
/// 读取方（图标名、状态栏）直接读档位，不走 SettingsStore 实例：
/// 这些视图拿不到 settings 引用，而壁纸颜色本来就是静态读 ThemeStore 的路数。
enum HomeTextInk: String, CaseIterable, Identifiable {
    case auto
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "自动"
        case .light: return "白色"
        case .dark: return "黑色"
        }
    }

    static let defaultsKey = "shell.homeTextInk"

    static var current: HomeTextInk {
        HomeTextInk(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .auto
    }

    /// 显式白/黑；自动档返回 nil，让调用方沿用各自的日夜逻辑。
    var explicitColor: Color? {
        switch self {
        case .auto: return nil
        case .light: return .white
        case .dark: return .black
        }
    }
}
