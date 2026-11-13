import SwiftUI
import UIKit

/// 键盘现在把屏幕遮掉多少。
///
/// 只负责量高度，排版由外壳做：`PhoneShellView` 把 App 那一层按 `lift` 收短、
/// 顶部对齐，收出来的这一条正好等于键盘，输入条就落在键盘上沿。
///
/// 为什么不交给系统默认避让：手机壳是一整块铺满屏幕的假手机，系统那套按
/// 安全区压窄内容的做法在这里不生效（截图核对过，键盘起来以后内容没有被压窄，
/// 输入条直接被盖在键盘后面）。自己收高度是确定的。
@Observable
@MainActor
final class KeyboardInset {
    static let shared = KeyboardInset()

    /// 键盘顶边到屏幕底边的距离，含底部安全区。收起时是 0。
    private(set) var height: CGFloat = 0

    /// App 层要收短多少。
    ///
    /// 键盘报的高度连 Home 指示条那一段一起算，而 App 层本来就摆在安全区上沿，
    /// 按整高收会多收一条。收短量 = 键盘高 − 底部安全区。
    var lift: CGFloat {
        guard height > 0 else { return 0 }
        return max(0, height - Self.bottomSafeArea)
    }

    var isUp: Bool { height > 0 }

    private var observers: [NSObjectProtocol] = []

    /// 底部安全区取窗口的：真机上键盘不会算进窗口的安全区。
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
    /// 键盘截图那一档的读数：内容框顶边、高度、键盘高度、屏幕高、安全区。
    ///
    /// 键盘避让出问题时，光看画面分不清是「整块被翻译上去了」还是「高度算错了」，
    /// 这几个数一照就能定位。画在框的正中间——框被顶出去的时候，只有中间一定还
    /// 在屏幕里。只在 `-previewState chatKeyboard` 下显示。
    func keyboardProbe() -> some View {
        overlay {
            if UserDefaults.standard.string(forKey: "previewState") == "chatKeyboard" {
                GeometryReader { proxy in
                    let frame = proxy.frame(in: .global)
                    let screen = UIScreen.main.bounds.height
                    Text("""
                    y\(Int(frame.minY)) h\(Int(frame.height))
                    kb\(Int(KeyboardInset.shared.height)) lift\(Int(KeyboardInset.shared.lift))
                    screen\(Int(screen)) sTop\(Int(proxy.safeAreaInsets.top)) sBot\(Int(proxy.safeAreaInsets.bottom))
                    """)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red)
                    .padding(6)
                    .background(.black.opacity(0.75))
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
                .allowsHitTesting(false)
            }
        }
    }
}
