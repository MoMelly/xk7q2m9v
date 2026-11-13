import SwiftUI
import UIKit

/// 键盘现在把屏幕遮掉多少。
///
/// 只负责量高度，位置由外壳钉（见 `PhoneShellView.appLayerBox`）：
/// 键盘一弹起，App 层的高度取 `pinnedHeight`、顶边按实测值挪回状态栏下沿，
/// 框正好是「状态栏下沿 → 键盘上沿」，输入条落在键盘上沿、标题留在原位。
///
/// 为什么不交给系统的键盘避让：这层壳是一整块铺满屏幕的假手机，系统算出来的
/// 数不对——截图量到键盘高 335，它只给 215 的底部安全区，顶部安全区还会掉成 0，
/// 外壳的框因此变成 -28..659：标题被顶出屏幕，输入条压在键盘后面。
@Observable
@MainActor
final class KeyboardInset {
    static let shared = KeyboardInset()

    /// 键盘顶边到屏幕底边的距离，含底部安全区。收起时是 0。
    private(set) var height: CGFloat = 0

    var isUp: Bool { height > 0 }

    /// 键盘弹起时，App 层应当占的高度：状态栏下沿到键盘上沿。
    static var pinnedHeight: CGFloat {
        max(200, UIScreen.main.bounds.height - topSafeArea - KeyboardInset.shared.height)
    }

    /// 顶部安全区，取窗口的。
    static var topSafeArea: CGFloat {
        window?.safeAreaInsets.top ?? 0
    }

    private static var window: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow)
    }

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
