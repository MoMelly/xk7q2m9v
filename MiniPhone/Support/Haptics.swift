import UIKit

/// 触感反馈的唯一入口。
///
/// 之前全靠系统默认：长按出菜单有一下，点菜单项就没有了。真机上点「撤回」
/// 和点一片空白的手感一样，会让人怀疑到底点没点到。
///
/// 只做三档，不提供参数：档位多了没人记得住哪一档用在哪，
/// 最后就是随手写一个，同一类动作在两处手感不同。
enum Haptics {
    /// 轻点。菜单项、图标、开关这类「点了就生效」的动作。
    static func tap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// 选中。分段控件换档、列表里换曲目。
    static func select() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    /// 出错或危险动作（删除、清空）。
    static func warn() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
