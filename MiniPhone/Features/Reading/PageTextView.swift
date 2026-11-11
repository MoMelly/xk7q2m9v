import SwiftUI
import UIKit

/// 一页正文。用 `UITextView` 而不是 SwiftUI 的 `Text`。
///
/// 分页是 TextKit 算出来的，渲染也必须是 TextKit：同一个宽度、同一套字体，
/// 切出来的页才和实际排出来的一模一样。换成 `Text` 就又变成「估算」了，
/// 两套排版引擎差出来的行高会一路累加，到页尾切掉一行字。
struct PageTextView: UIViewRepresentable {
    let text: String
    let font: UIFont
    let lineSpacing: CGFloat
    let ink: UIColor

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isScrollEnabled = false
        view.isSelectable = false
        view.backgroundColor = .clear
        // 文本容器的默认内边距会让实际可排宽度比 `BookPaginator` 量的小十几点，
        // 那点差就是页尾少一行。两边都得清零。
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.lineBreakMode = .byWordWrapping

        view.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: ink,
                .paragraphStyle: style
            ]
        )
    }
}
