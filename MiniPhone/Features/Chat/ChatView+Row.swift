import SwiftUI

/// 消息行的组装：头像、气泡间距、时间戳的判断。
///
/// 从 `ChatView` 里拆出来的：那个文件本体已经贴着 600 行上限，
/// 再加两段排版逻辑就过不去了。这里只有纯展示判断，不碰对话状态。
extension ChatView {

    /// 一条气泡加上它的头像。
    ///
    /// 头像只挂在角色那一侧：自己说的话不用再标是谁说的。
    /// 旁白、拍一拍、撤回后的状态行都不挂——那几种不是「谁在说话」。
    func row(for message: StoredMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if showsAvatar(for: message) {
                AvatarBubble(character: character, size: 30)
                    .padding(.top, 2)
            }

            bubble(for: message)
        }
    }

    func showsAvatar(for message: StoredMessage) -> Bool {
        guard settings.showChatAvatar else { return false }
        guard message.role != .user else { return false }
        return !message.isNarration && !message.isPat && !message.isRecalled
    }

    /// 同一人连着说留 6，换个人说话再压 12 上去（合计 18）。
    ///
    /// 原来整列统一 12：自己连着发三段和对方回一句，视觉上是同一个密度，
    /// 一屏下来全糊成一片，读不出谁在接话。微信那种节奏靠的就是这个落差。
    func gapBefore(_ index: Int) -> CGFloat {
        guard index > 0 else { return 0 }
        return messages[index - 1].role == messages[index].role ? 0 : 12
    }

    /// 两条消息间隔超过 30 分钟才插时间，否则满屏都是时间戳。
    func shouldShowTime(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let previous = messages[index - 1].createdAt
        let current = messages[index].createdAt
        return current.timeIntervalSince(previous) > 60 * 30
    }

    /// 我的身份：默认身份优先，没设就取第一个，再没有退回「我」。
    /// 置顶栏和拍一拍共用，免得一处取 first、另一处取 isDefault。
    var myDisplayName: String {
        profiles.first(where: { $0.isDefault })?.name
            ?? profiles.first?.name
            ?? "我"
    }
}
