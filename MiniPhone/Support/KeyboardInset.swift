import SwiftUI
import UIKit

/// 键盘现在把屏幕遮掉多少。
///
/// 只提供高度，不参与排版。键盘避让交给系统做：它按安全区把内容区压窄，
/// 标题留在顶上、输入条跟着浮到键盘上沿。
///
/// 不要在这里改回「自己声明不理键盘、再手动抬输入条」：
/// SwiftUI 遇到不理键盘的布局时没法压窄，只能把整块内容往上翻译，
/// 把聚焦的输入框顶进可视区——标题会跟着一起被推出屏幕。
@Observable
@MainActor
final class KeyboardInset {
    static let shared = KeyboardInset()

    /// 键盘顶边到屏幕底边的距离，含底部安全区。收起时是 0。
    private(set) var height: CGFloat = 0

    var isUp: Bool { height > 0 }

    private var observers: [NSObjectProtocol] = []

    private init() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            UIResponder.keyboardWillChangeFrameNotification,
            UIResponder.keyboardWillHideNotification
        ]

        for name in names {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { note in
                let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
                let hidden = note.name == UIResponder.keyboardWillHideNotification
                Task { @MainActor in
                    KeyboardInset.shared.update(frame: frame, hidden: hidden)
                }
            }
            observers.append(observer)
        }
    }

    private func update(frame: CGRect?, hidden: Bool) {
        guard !hidden, let frame, frame.minY < UIScreen.main.bounds.height else {
            height = 0
            return
        }
        height = max(0, UIScreen.main.bounds.height - frame.minY)
    }
}
