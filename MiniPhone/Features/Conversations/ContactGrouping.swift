import Foundation

/// 微信通讯录那种分组：按名字首字母分节。
///
/// 名字先转无声调全拼再取首字母。中文靠 `CFStringTransform` 的拉丁转写，
/// 英文直接取首字母，数字、符号、emoji 一律归到 `#`。
/// 组内也按全拼排——只按 Unicode 排的话，同一节里的中文顺序看着是乱的。
enum ContactGrouping {
    /// 一节。`id` 就是右侧索引条上的那个字母。
    struct Section: Identifiable {
        let id: String
        let items: [Companion]
    }

    /// 索引条上的固定顺序：A–Z，`#` 永远在最后。
    static let letters: [String] = (65...90).map { String(UnicodeScalar($0)!) } + ["#"]

    static func sections(_ characters: [Companion]) -> [Section] {
        let sorted = characters
            .map { (key: sortKey($0.name), character: $0) }
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }

        var buckets: [String: [Companion]] = [:]
        for item in sorted {
            buckets[initial(of: item.key), default: []].append(item.character)
        }

        return letters.compactMap { letter in
            guard let items = buckets[letter], !items.isEmpty else { return nil }
            return Section(id: letter, items: items)
        }
    }

    /// 首字母。不是 ASCII 字母的一律进 `#`。
    static func initial(of key: String) -> String {
        guard let head = key.uppercased().first, head.isASCII, head.isLetter else { return "#" }
        return String(head)
    }

    /// 排序键：无声调全拼。转不出来的（纯符号名）退回原名。
    ///
    /// 用 `applyingTransform` 而不是 `CFStringTransform`：后者要先把
    /// `NSMutableString` 桥成 `CFMutableString`，在 Swift 里类型对不上。
    static func sortKey(_ name: String) -> String {
        let latin = name
            .applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let latin, !latin.isEmpty else { return name }
        return latin
    }
}
