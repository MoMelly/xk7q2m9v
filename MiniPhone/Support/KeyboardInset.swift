import SwiftUI
import UIKit

/// 键盘现在把屏幕从底下遮掉了多少。
///
/// 手机壳是一整块铺满屏幕的假手机。系统默认的键盘避让会按安全区把整块内容
/// 往上顶：聊天页的标题被推出屏幕，底部的输入条却没有跟着浮上来。所以
/// 聊天页那一层自己声明「不理键盘」，位置改成这里算：
/// 输入条抬到键盘上沿，标题留在原地。
///
/// 另外留了一个只给截图用的假高度。模拟器冷启动拍不到真键盘，
/// `-previewState chatKeyboard` 用它把同一套布局拍下来核对；正常启动读不到。
@Observable
@MainActor
final class KeyboardInset {
    static let shared = KeyboardInset()

    /// 键盘顶边到屏幕底边的距离，含底部安全区。收起时是 0。
    private(set) var height: CGFloat = 0

    /// 截图用：没有真键盘时按这个高度排版。
    var debugHeight: CGFloat = 0

    /// 内容要往上抬多少。
    ///
    /// 键盘报的高度连 Home 指示条那一段一起算，而内容本来就摆在安全区上沿，
    /// 直接按整高抬会多抬一条。抬升量 = 键盘高 − 底部安全区。
    var lift: CGFloat {
        let raw = max(height, debugHeight)
        guard raw > 0 else { return 0 }
        return max(0, raw - Self.bottomSafeArea)
    }

    var isUp: Bool { lift > 0 }

    private var observers: [NSObjectProtocol] = []

    /// 底部安全区。取窗口的，不取 UIScreen：真机上键盘不会算进窗口的安全区，
    /// 但 SwiftUI 的根视图会（那是它自己的避让机制）。
    static var bottomSafeArea: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
        return window?.safeAreaInsets.bottom ?? 0
    }

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

extension View {
    /// 表单、列表这类可以滚的页面用：给底部留出键盘那么高的一段，
    /// 光标落在下面的输入框时还滚得上来。
    ///
    /// 底部挂着输入条的页面不用它——那种页面要在这块内容里留一条等高的
    /// 空档（见 `ChatView` 的输入条），不能让整块内容比容器高。
    func keyboardScrollRoom() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: KeyboardInset.shared.lift)
        }
    }

    /// 临时诊断用：只在 `chatKeyboard` 那张截图里打一行实测值，并描一圈红框。
    @ViewBuilder
    func keyboardDebugBadge() -> some View {
        if UserDefaults.standard.string(forKey: "previewState") == "chatKeyboard" {
            self.border(Color.red, width: 3)
                .overlay(alignment: .topLeading) {
                    Text("kb=\(Int(KeyboardInset.shared.height)) lift=\(Int(KeyboardInset.shared.lift)) safeBottom=\(Int(KeyboardInset.bottomSafeArea))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.yellow)
                        .padding(3)
                        .background(Color.black.opacity(0.75))
                }
        } else {
            self
        }
    }
}
