import Foundation

extension WorldStore {
    /// 记下今天某一侧开过口。
    ///
    /// 发消息和收到回复各调一次：只有两侧都在同一天开过口，火花才续一天。
    /// 一个人连着说十天、另一个人十天没回，那不叫火花。
    func markCoupleDay(fromMe: Bool) {
        var next = state.couple
        if fromMe {
            CoupleEngine.markMine(&next)
        } else {
            CoupleEngine.markTheirs(&next)
        }
        guard next != state.couple else { return }
        state.couple = next
        save()
    }
}
