import SwiftUI

/// 桌面这一下到底算「点开」还是「长按抖起来」。
///
/// 原来图标那一层长按 0.28 秒、板子兜底 0.3 秒，比一次普通点按长不了多少；
/// 真机上稍慢一点的点击就被判成长按，桌面当场抖起来。进了编辑态之后，
/// 图标上的轻点又被 `guard !editing` 拦掉，点空白退出的手势在图标这一层不响应，
/// 于是既打不开也退不出——看着就是「一点图标就进编辑态，怎么都点不进去」。
///
/// 阈值集中在这里，探针（`HomeTapProbe`）跑的也是同一套判定。
enum HomeTapPolicy {
    /// 和系统长按一致的手感。短于这个数一律算轻点。
    static let longPressDuration: Double = 0.5
    /// 长按之后还要真的挪这么远才开始拖。
    ///
    /// 原来是 0：手指按住不动、稍微一抖就进入拖拽，轻点也被手势接管。
    static let dragStartDistance: CGFloat = 8
    /// 刚进编辑态的这段时间内不认轻点：那一下是长按松手，不是新的一次点。
    static let tapGuard: TimeInterval = 0.45

    static func isLongPress(heldFor duration: TimeInterval) -> Bool {
        duration >= longPressDuration
    }

    /// 松手时该不该打开 App。
    ///
    /// 编辑态下也照样打开，顺手把编辑态收掉；不要求先点一次空白退出。
    static func shouldOpen(
        heldFor duration: TimeInterval,
        sinceEditing: TimeInterval,
        moved: CGFloat
    ) -> Bool {
        guard !isLongPress(heldFor: duration) else { return false }
        guard moved < dragStartDistance else { return false }
        return sinceEditing > tapGuard
    }
}
