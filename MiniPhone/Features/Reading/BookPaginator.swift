import Foundation
import UIKit

/// 一本书的第几章。`start`/`end` 是段落下标，左闭右开。
struct BookChapter: Identifiable, Hashable {
    let id: Int
    let title: String
    let start: Int
    let end: Int
}

/// 一页要画的内容。
struct BookPage: Hashable {
    /// 这一页从全书第几段开始。存进度、显示用。
    let start: Int
    /// 整页正文，段落之间是换行。
    ///
    /// 上一版是 `[String]`（一页一串段落），渲染时交给 SwiftUI 的 `Text`
    /// 一个个堆起来。测量用 `boundingRect` 算、渲染交给 SwiftUI 排，
    /// 两套排版引擎差出来的行高会一路累加，到页尾就切掉一行字。
    /// 现在测量和渲染都是 TextKit 同一个 `NSLayoutManager`，尺寸一致，切不出来。
    let text: String
}

/// 章节切分与分页。
///
/// 分页交给 TextKit：给它一个和正文区一样宽的容器，它会按真实排版
/// 算出这一页能装到第几个字。市面上的阅读器都是这么切的。
enum BookPaginator {
    /// 章节标题：第X章/节/回/卷、序章、楔子、尾声、后记、Chapter 3。
    ///
    /// 只认短行。正文里偶尔出现的「第一章」这种引用不能当标题，
    /// 否则一本书会被切成几十个假章节。
    private static let heading = try! NSRegularExpression(
        pattern: "^\\s*(第[0-9零一二三四五六七八九十百千两]{1,8}[章节回卷部篇集]|序章|楔子|引子|尾声|终章|后记|Chapter\\s+\\d+)([\\s:：、.．·-].*)?$",
        options: [.caseInsensitive]
    )

    private static let maxHeadingLength = 30

    static func chapters(in paragraphs: [String]) -> [BookChapter] {
        var marks: [(index: Int, title: String)] = []

        for (index, text) in paragraphs.enumerated() {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= maxHeadingLength else { continue }
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            if heading.firstMatch(in: trimmed, options: [], range: range) != nil {
                marks.append((index, trimmed))
            }
        }

        guard !marks.isEmpty else {
            return [BookChapter(id: 0, title: "正文", start: 0, end: paragraphs.count)]
        }

        var result: [BookChapter] = []
        for (position, mark) in marks.enumerated() {
            let end = position + 1 < marks.count ? marks[position + 1].index : paragraphs.count
            guard end > mark.index else { continue }
            result.append(
                BookChapter(id: position, title: mark.title, start: mark.index, end: end)
            )
        }
        return result
    }

    /// 把一章按可用高度切页。
    ///
    /// `size` 是正文区大小（已经去掉页边距），`font` 和 `lineSpacing`
    /// 必须和渲染时一致，否则切点会偏。
    static func pages(
        paragraphs: [String],
        range: Range<Int>,
        size: CGSize,
        font: UIFont,
        lineSpacing: CGFloat
    ) -> [BookPage] {
        guard range.lowerBound < range.upperBound else {
            return [BookPage(start: range.lowerBound, text: "")]
        }

        let joined = joined(paragraphs, range: range)

        guard size.width > 1, size.height > 1 else {
            return [BookPage(start: range.lowerBound, text: joined.text)]
        }

        let slices = paginate(
            text: joined.text,
            size: size,
            font: font,
            lineSpacing: lineSpacing
        )

        return slices.map { slice in
            let start = joined.starts.last(where: { $0.location <= slice.location })?.index
                ?? range.lowerBound
            return BookPage(start: start, text: slice.text)
        }
    }

    /// 找到某一段落在第几页。翻回上次位置、以及章节跳转都用它。
    static func pageIndex(containing paragraph: Int, in pages: [BookPage]) -> Int {
        guard !pages.isEmpty else { return 0 }
        if let index = pages.lastIndex(where: { $0.start <= paragraph }) {
            return min(index, pages.count - 1)
        }
        return 0
    }

    // MARK: - 拼段

    private struct Joined {
        let text: String
        /// 每段在整章文本里的起点。分页结果是字符位置，翻回段落下标要用它。
        let starts: [(location: Int, index: Int)]
    }

    private static func joined(_ paragraphs: [String], range: Range<Int>) -> Joined {
        var text = ""
        var starts: [(location: Int, index: Int)] = []

        for index in range {
            if !text.isEmpty { text += "\n" }
            starts.append((location: (text as NSString).length, index: index))
            text += paragraphs[index]
        }
        return Joined(text: text, starts: starts)
    }

    // MARK: - TextKit 分页

    private struct Slice {
        let location: Int
        let text: String
    }

    /// 交给 TextKit 切。
    ///
    /// 循环里每次加一个新容器，读它装下了多少字；装下的部分记成一页，
    /// 从下一个字继续。容器尺寸和渲染时一样，所以切口就是真实的页边界。
    private static func paginate(
        text: String,
        size: CGSize,
        font: UIFont,
        lineSpacing: CGFloat
    ) -> [Slice] {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.lineBreakMode = .byWordWrapping

        let storage = NSTextStorage(
            string: text,
            attributes: [
                .font: font,
                .paragraphStyle: style
            ]
        )
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)

        let full = text as NSString
        let length = full.length
        var location = 0
        var slices: [Slice] = []

        while location < length {
            let container = NSTextContainer(size: size)
            container.lineFragmentPadding = 0
            container.maximumNumberOfLines = 0
            container.lineBreakMode = .byWordWrapping
            layout.addTextContainer(container)

            let glyphRange = layout.glyphRange(for: container)
            let charRange = layout.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

            // 装不下一个字（容器还没量出来）时兜底一个字，
            // 否则 location 不前进，这里会原地转圈。
            let take = min(max(charRange.length, 1), length - location)
            var chunk = full.substring(with: NSRange(location: location, length: take))

            // 页首的换行是上一页留下的段落分隔，留着每页会顶上空一截。
            // 只从显示文本里去掉，`take` 不动——多减会让下一段开头丢字。
            while chunk.hasPrefix("\n") {
                chunk.removeFirst()
            }

            slices.append(Slice(location: location, text: chunk))
            location += take
        }

        return slices.isEmpty ? [Slice(location: 0, text: text)] : slices
    }
}
