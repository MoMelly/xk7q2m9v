import SwiftUI
import UIKit

/// 一页正文。用 `UITextView` 而不是 SwiftUI 的 `Text`。
///
/// 分页是 TextKit 算出来的，渲染也必须是 TextKit：同一个宽度、同一套字体，
/// 切出来的页才和实际排出来的一模一样。换成 `Text` 就又变成「估算」了，
/// 两套排版引擎差出来的行高会一路累加，到页尾切掉一行字。
///
/// 长按也挂在这个视图上：位置要换算成字符偏移，只有 `UITextView` 能做。
/// 系统自带的选中与复制菜单关掉——这一页只需要「给这句写批注」。
struct PageTextView: UIViewRepresentable {
    let text: String
    let font: UIFont
    let lineSpacing: CGFloat
    let ink: UIColor
    /// 这一页里已经写过批注的句子。
    var marked: [String] = []
    /// 长按选中一句。
    var onMark: (String) -> Void = { _ in }
    /// 点一下带批注的句子，回看那条批注。
    var onOpenNote: (String) -> Void = { _ in }

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

        let press = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        press.minimumPressDuration = 0.35
        view.addGestureRecognizer(press)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.require(toFail: press)
        view.addGestureRecognizer(tap)

        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.marked = marked
        context.coordinator.onMark = onMark
        context.coordinator.onOpenNote = onOpenNote

        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.lineBreakMode = .byWordWrapping

        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: ink,
                .paragraphStyle: style
            ]
        )
        giveMarks(attributed)
        view.attributedText = attributed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// 给已批注的句子加一条底纹和下划线。底色用正文色淡化，
    /// 三种纸色（米黄/纸白/夜间）下都不会跳出画外。
    private func giveMarks(_ attributed: NSMutableAttributedString) {
        guard !marked.isEmpty else { return }
        let full = text as NSString
        for sentence in marked {
            let found = full.range(of: sentence)
            guard found.location != NSNotFound else { continue }
            attributed.addAttributes(
                [
                    .backgroundColor: ink.withAlphaComponent(0.12),
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: ink.withAlphaComponent(0.4)
                ],
                range: found
            )
        }
    }

    final class Coordinator: NSObject {
        weak var view: UITextView?
        var marked: [String] = []
        var onMark: (String) -> Void = { _ in }
        var onOpenNote: (String) -> Void = { _ in }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let view else { return }
            guard let offset = Self.offset(of: gesture.location(in: view), in: view),
                  let sentence = SentenceCutter.sentence(in: view.text, at: offset)
            else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onMark(sentence)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view,
                  let offset = Self.offset(of: gesture.location(in: view), in: view),
                  let sentence = SentenceCutter.sentence(in: view.text, at: offset),
                  marked.contains(sentence)
            else { return }
            onOpenNote(sentence)
        }

        /// 点 → 字符偏移。`closestPosition` 会吸附到最近的字，比按键位估算准。
        static func offset(of point: CGPoint, in view: UITextView) -> Int? {
            guard let position = view.closestPosition(to: point) else { return nil }
            let offset = view.offset(from: view.beginningOfDocument, to: position)
            return offset >= 0 ? offset : nil
        }
    }
}

/// 按标点切句。
///
/// 不按字数截断：一句可以很长，但长按落在哪，就应该整句被选中。
/// 换行也算句末——段落本来就在那里断。
enum SentenceCutter {
    private static let stops = CharacterSet(charactersIn: "。！？…；!?;\n\r")

    static func sentence(in text: String, at offset: Int) -> String? {
        let ns = text as NSString
        guard ns.length > 0 else { return nil }
        let anchor = min(max(offset, 0), ns.length - 1)

        // 往前找上一个句末，它之后就是这句的开头。
        var start = 0
        var cursor = anchor
        while cursor > 0 {
            let piece = ns.rangeOfComposedCharacterSequence(at: cursor - 1)
            if endsSentence(ns.substring(with: piece)) {
                start = piece.location + piece.length
                break
            }
            cursor = piece.location
        }

        // 往后找第一个句末，含它自己。
        var end = ns.length
        var tail = anchor
        while tail < ns.length {
            let piece = ns.rangeOfComposedCharacterSequence(at: tail)
            if endsSentence(ns.substring(with: piece)) {
                end = piece.location + piece.length
                break
            }
            tail = piece.location + piece.length
        }

        guard end > start else { return nil }
        let raw = ns.substring(with: NSRange(location: start, length: end - start))
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // 只剩一个标点或空格的不算一句。
        return trimmed.count >= 2 ? trimmed : nil
    }

    private static func endsSentence(_ piece: String) -> Bool {
        piece.unicodeScalars.contains { stops.contains($0) }
    }
}
