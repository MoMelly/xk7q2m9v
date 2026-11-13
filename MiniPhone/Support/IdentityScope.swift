import Foundation
import SwiftUI

/// 我现在用哪个身份在聊。
///
/// 一个身份就是一个人：换成新身份之后，同一个角色对他一无所知，
/// 聊天记录也是从空的开始；切回来原来的记录原样都在。
///
/// 空串代表「默认身份」。老消息的归属都是空的，所以升级之后
/// 原来的记录仍旧挂在默认身份上，不会突然消失。
@Observable
@MainActor
final class IdentityScope {
    static let shared = IdentityScope()

    /// UserDefaults 键。世界状态文件选路径时也要读它，那边不方便跨
    /// actor 隔离取实例，所以键名单独暴露，避免两边各写一份字面量。
    nonisolated static let storageKey = "shell.activeIdentity"

    /// 不经过实例的读取。`@Query` 的谓词在 init 里拼，那里碰不到
    /// 主线程隔离的实例，就直接读存下来的那个值。
    nonisolated static var storedUID: String {
        UserDefaults.standard.string(forKey: storageKey) ?? ""
    }

    private(set) var uid: String

    var isDefault: Bool { uid.isEmpty }

    private init() {
        uid = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
    }

    /// 切到某个身份。传空串就是回默认身份。
    ///
    /// 只改这一个值：消息、记忆都按它过滤，不再往每条会话上写
    /// 「这个会话用谁」——那样换身份得挨个改，改漏一个就串了。
    func switchTo(_ newUID: String) {
        guard uid != newUID else { return }
        uid = newUID
        UserDefaults.standard.set(newUID, forKey: Self.storageKey)
        Haptics.tap()
        // 会话列表、聊天页、记忆页都是按身份现算的，不订阅这个值就得等
        // 重新进页面才会变；发一条通知让开着的那几个当场刷一遍。
        NotificationCenter.default.post(name: .identityChanged, object: nil)
    }

    /// 清空整台手机时把当前身份一起归零。
    ///
    /// 不发身份变更通知：调用方已经把世界状态清空并指回默认文件，
    /// 再触发一次异步读盘会把刚清掉的东西重新读回来。
    func resetToDefault() {
        uid = ""
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    /// 删掉一个身份之后，如果正站在它上面，回默认身份。
    func fallBackIfNeeded(deletedUID: String) {
        if uid == deletedUID { switchTo("") }
    }
}

extension Companion {
    /// 当前身份在这个会话里的消息。
    ///
    /// 换身份看到的不是「同一段对话换个称呼」，而是另一个人跟他聊的另一段。
    var scopedMessages: [StoredMessage] {
        let scope = IdentityScope.storedUID
        return messages.filter { $0.personaUID == scope }
    }

    /// 当前身份在这段会话里最后说话的时间。列表按它排。
    var scopedLastMessageAt: Date? {
        scopedMessages.map(\.createdAt).max()
    }

    /// 当前身份是从哪天认识他的。
    ///
    /// `Companion.createdAt` 是角色建库的时间，跟谁在聊无关；换身份之后
    /// 用它算「相处 N 天」会把另一个身份攒下来的天数带过来。起算点改成
    /// 这个身份在这段会话里最早的一条消息，没聊过就是今天。
    var knownSince: Date {
        scopedMessages.map(\.createdAt).min() ?? Date()
    }
}

extension Notification.Name {
    /// 身份换了。
    static let identityChanged = Notification.Name("shell.identityChanged")
}
