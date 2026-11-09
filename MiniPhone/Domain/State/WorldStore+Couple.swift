import Foundation

extension WorldStore {
    /// 和某个角色的火花。
    ///
    /// 每个角色一份：跟 A 说的话不该算进跟 B 的火花里。
    func coupleState(for partner: String) -> CoupleState {
        state.couples[partner] ?? CoupleState()
    }

    /// 记下今天某一侧开过口。
    ///
    /// 发消息和收到回复各调一次：只有两侧都在同一天开过口，火花才续一天。
    /// 一个人连着说十天、另一个人十天没回，那不叫火花。
    /// `partner` 必须带上：火花是按人算的。
    func markCoupleDay(fromMe: Bool, partner: String) {
        guard !partner.isEmpty else { return }
        var next = state.couples[partner] ?? CoupleState()

        // 老存档里那唯一一份火花没有归属，发给第一个开口的人。只发一次。
        if state.couples[partner] == nil, let legacy = state.legacyCouple {
            next = legacy
            state.legacyCouple = nil
        }

        if fromMe {
            CoupleEngine.markMine(&next)
        } else {
            CoupleEngine.markTheirs(&next)
        }
        guard next != state.couples[partner] else { return }
        state.couples[partner] = next
        save()
    }
}
