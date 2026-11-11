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
///
/// `start` 记的是这一页第一段在全书里的下标，用来存进度；
/// `texts` 是真正要渲染的段落——超长段落会被切开，所以两者不一定一一对应。
struct BookPage: Hashable {
    let start: Int
    let texts: [String]
}

/// 章节切分与分页。
///
/// 之前阅读就是一整条 `ScrollView`，没有页的概念：想看下一屏就往下滚，
/// 想跳章只能自己找，进度记的是「滚到第几段」。
/// 这里按真实可用高度切页，切不动的地方按字符继续切。
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

        // 一个标题都没有：整本当一章，目录里只有一条。
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
    /// `size` 是正文区大小（已经去掉左右内边距），`font` 必须和渲染时一致，
    /// 否则每页最后会漏一截或者多出一行。
    static func pages(
        paragraphs: [String],
        range: Range<Int>,
        size: CGSize,
        font: UIFont,
        lineSpacing: CGFloat
    ) -> [BookPage] {
        guard range.lowerBound < range.upperBound else {
            return [BookPage(start: range.lowerBound, texts: [])]
        }
        guard size.width > 1, size.height > 1 else {
            return [BookPage(start: range.lowerBound, texts: Array(paragraphs[range]))]
        }

        let gap: CGFloat = 14
        var pages: [BookPage] = []
        var current: [String] = []
        var currentStart = range.lowerBound
        var used: CGFloat = 0

        func flush() {
            guard !current.isEmpty else { return }
            pages.append(BookPage(start: currentStart, texts: current))
            current = []
            used = 0
        }

        for index in range {
            let text = paragraphs[index]
            let textHeight = height(of: text, width: size.width, font: font, lineSpacing: lineSpacing)
            let needed = textHeight + (current.isEmpty ? 0 : gap)

            if used + needed <= size.height {
                if current.isEmpty { currentStart = index }
                current.append(text)
                used += needed
                continue
            }

            // 这一段放不下：先收掉已经满的这页，再从这一段重新开始。
            if !current.isEmpty {
                flush()
            }

            if textHeight <= size.height {
                currentStart = index
                current.append(text)
                used = textHeight
            } else {
                // 单段就比一页还高。按字符切，切到刚好填满为准。
                for chunk in split(text, width: size.width, limit: size.height, font: font, lineSpacing: lineSpacing) {
                    pages.append(BookPage(start: index, texts: [chunk]))
                }
            }
        }

        flush()
        return pages.isEmpty ? [BookPage(start: range.lowerBound, texts: [])] : pages
    }

    /// 找到某一段落在第几页。翻回上次位置、以及章节跳转都用它。
    static func pageIndex(containing paragraph: Int, in pages: [BookPage]) -> Int {
        guard !pages.isEmpty else { return 0 }
        if let index = pages.lastIndex(where: { $0.start <= paragraph }) {
            return min(index, pages.count - 1)
        }
        return 0
    }

    // MARK: - 测量

    static func height(of text: String, width: CGFloat, font: UIFont, lineSpacing: CGFloat) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.lineBreakMode = .byWordWrapping
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: style],
            context: nil
        )
        return ceil(rect.height)
    }

    /// 一段文字超过一页时，二分出这一页最多能装多少字，剩下的继续切。
    private static func split(
        _ text: String,
        width: CGFloat,
        limit: CGFloat,
        font: UIFont,
        lineSpacing: CGFloat
    ) -> [String] {
        let characters = Array(text)
        guard !characters.isEmpty else { return [text] }

        var chunks: [String] = []
        var offset = 0

        while offset < characters.count {
            var low = 1
            var high = min(characters.count - offset, 3000)
            var best = 0

            while low <= high {
                let mid = (low + high) / 2
                let candidate = String(characters[offset..<(offset + mid)])
                if height(of: candidate, width: width, font: font, lineSpacing: lineSpacing) <= limit {
                    best = mid
                    low = mid + 1
                } else {
                    high = mid - 1
                }
            }

            if best == 0 { best = 1 }
            chunks.append(String(characters[offset..<(offset + best)]))
            offset += best
        }

        return chunks
    }
}
