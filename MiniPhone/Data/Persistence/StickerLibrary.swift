import Foundation
import Observation
import SwiftData

/// 当前这套手机里所有表情，外加「某个角色能用哪些」。
///
/// 单独一份内存副本而不是每次现查：提示词要在发消息那一刻同步拼出来，
/// 查库是异步的，等它回来消息已经发出去了。
/// 表情页改完会调 `reload`，这里跟着刷新。
@Observable
final class StickerLibrary {
    static let shared = StickerLibrary()

    private(set) var items: [StickerItem] = []

    private init() {}

    @MainActor
    func reload(context: ModelContext) {
        let descriptor = FetchDescriptor<StickerItem>(
            sortBy: [SortDescriptor(\StickerItem.createdAt, order: .forward)]
        )
        items = (try? context.fetch(descriptor)) ?? []
    }

    /// 分组全开、单个也没关的表情。
    func available(for character: Companion) -> [StickerItem] {
        let blockedGroups = character.blockedStickerGroups
        let blockedNames = character.blockedStickerNames
        return items.filter { sticker in
            !blockedGroups.contains(sticker.group) && !blockedNames.contains(sticker.name)
        }
    }

    /// 进提示词的就这一串名字。空串的名字不算——没名字的图模型用不了。
    func names(for character: Companion) -> [String] {
        available(for: character)
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// 按备注名找表情。模型回的是名字，渲染要拿回那张图。
    func item(named name: String) -> StickerItem? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.first { $0.name == clean }
    }

    var groups: [String] {
        var seen: [String] = []
        for item in items where !item.group.isEmpty && !seen.contains(item.group) {
            seen.append(item.group)
        }
        return seen
    }
}

extension Companion {
    /// 被禁用的分组。
    var blockedStickerGroups: Set<String> {
        Self.parseList(blockedStickerGroupsRaw)
    }

    /// 被单独禁用的表情名。
    var blockedStickerNames: Set<String> {
        Self.parseList(blockedStickerNamesRaw)
    }

    private static func parseList(_ raw: String) -> Set<String> {
        Set(
            raw
                .split(whereSeparator: { $0 == "," || $0 == "，" })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
    }
}
