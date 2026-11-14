import SwiftUI

/// 输入框周边的几段：一起听的状态条，和别处递进来的草稿。
///
/// 拆出来是因为 `ChatView` 已经贴着 600 行的上限；这两段都不画主界面，
/// 只是给输入栏配状态，放在这里比塞回主文件更好找。
extension ChatView {
    /// 一起听的状态挂在播放器上：歌是这台手机放的，跟会话无关。
    var isTogether: Bool {
        player.isTogether(with: character.uid)
    }

    /// 邀请/结束都不走网络。它只是把「这会儿跟谁一起听」记下来，
    /// 下一轮生成时若还在一起听，提示词才会带这首歌。
    func toggleTogether() {
        Haptics.tap()
        if isTogether {
            player.endTogether()
        } else {
            player.invite(uid: character.uid, name: character.name)
        }
    }

    /// 别的页面递进来的一句话（日历上的「跟他提一句」）。
    ///
    /// 只落进输入框，不替她发：提一句是她自己的话，发不发由她按。
    func applyStagedDraftIfNeeded() {
        guard let staged = WorldStore.shared.takeChatDraft(for: character.name) else { return }
        draft = staged
        isComposerActive = true
    }
}
