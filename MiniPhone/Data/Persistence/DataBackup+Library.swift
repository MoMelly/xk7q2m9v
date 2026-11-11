import Foundation
import SwiftData

/// 备份里原先漏掉的两张「资料库」表：表情库、书架。
///
/// 表情图片和世界文件已经在 `DataBackup+Files` 里整目录搬了，但 `StickerItem`
/// 和 `ReadingBook` 是 SwiftData 里的记录，一直没进 `data.json`。结果是恢复完
/// 文件躺在磁盘上、列表却是空的：自建表情的名字、分组、备注全断，导入的 txt
/// 连正文带阅读进度一起消失。书是纯文本存库的，文件里没有副本，只能靠 JSON。
extension DataBackup {

    /// 一条表情记录。图片本身不进 JSON：只留内置键或文件名。
    struct Sticker: Codable {
        var uid: UUID
        var name: String
        var group: String
        /// 内置表情的绘制键，非空时直接从包里取图，不碰 Documents。
        var builtInKey: String
        /// 上传图片在 `Documents/stickers/` 下的文件名。
        var fileName: String
        var createdAt: Date
    }

    /// 一本导入的 txt。正文只有库里这一份。
    struct Book: Codable {
        var uid: UUID
        var title: String
        var body: String
        /// 读到第几段。按段落序号存，换字号不会跑位。
        var paragraphIndex: Int
        var paragraphCount: Int
        var addedAt: Date
        var lastReadAt: Date?
    }

    // MARK: - 导出

    /// 「我的」里的身份。映射字段多，和表情、书一起放在这里，
    /// 免得 `export` 那个字面量继续膨胀。
    static func exportUsers(context: ModelContext) -> [Payload.User] {
        let items = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        return items
            .sorted { $0.createdAt < $1.createdAt }
            .map {
                Payload.User(
                    uid: $0.uid,
                    name: $0.name,
                    signature: $0.signature,
                    bio: $0.bio,
                    tagsRaw: $0.tagsRaw,
                    statusText: $0.statusText,
                    statusStickerName: $0.statusStickerName,
                    avatarTintRaw: $0.avatarTintRaw,
                    avatarSymbol: $0.avatarSymbol,
                    avatarImageKey: $0.avatarImageKey,
                    avatarFileName: $0.avatarFileName,
                    isDefault: $0.isDefault,
                    createdAt: $0.createdAt,
                    patSuffix: $0.patSuffix.isEmpty ? nil : $0.patSuffix
                )
            }
    }

    static func exportStickers(context: ModelContext) -> [Sticker] {
        let items = (try? context.fetch(FetchDescriptor<StickerItem>())) ?? []
        return items
            .sorted { $0.createdAt < $1.createdAt }
            .map {
                Sticker(
                    uid: $0.uid,
                    name: $0.name,
                    group: $0.group,
                    builtInKey: $0.builtInKey,
                    fileName: $0.fileName,
                    createdAt: $0.createdAt
                )
            }
    }

    static func exportBooks(context: ModelContext) -> [Book] {
        let items = (try? context.fetch(FetchDescriptor<ReadingBook>())) ?? []
        return items
            .sorted { $0.addedAt < $1.addedAt }
            .map {
                Book(
                    uid: $0.uid,
                    title: $0.title,
                    body: $0.body,
                    paragraphIndex: $0.paragraphIndex,
                    paragraphCount: $0.paragraphCount,
                    addedAt: $0.addedAt,
                    lastReadAt: $0.lastReadAt
                )
            }
    }

    // MARK: - 恢复

    /// 清掉现有记录。整段替换，跟「我的身份」一个口径：
    /// 备份存的是导出那一刻的完整清单，留着旧记录会变成两套混在一起。
    ///
    /// 两个开关分开：旧备份里没有这两段，缺哪段就不能清哪段，
    /// 否则「恢复一份老备份」会把手上的表情顺手清空。
    static func clearLibrary(
        context: ModelContext,
        stickers: Bool,
        books: Bool
    ) {
        if stickers {
            for item in (try? context.fetch(FetchDescriptor<StickerItem>())) ?? [] {
                context.delete(item)
            }
        }
        if books {
            for item in (try? context.fetch(FetchDescriptor<ReadingBook>())) ?? [] {
                context.delete(item)
            }
        }
    }

    static func restoreStickers(_ items: [Sticker], context: ModelContext) {
        for item in items {
            let sticker = StickerItem(
                name: item.name,
                group: item.group,
                builtInKey: item.builtInKey,
                fileName: item.fileName
            )
            // 保留原 uid：目前没有外部引用它，但同一份备份恢复两次应该得到
            // 同一批记录，排查「是不是又恢复了一遍」时才不会每次都是新 id。
            sticker.uid = item.uid
            sticker.createdAt = item.createdAt
            context.insert(sticker)
        }
    }

    static func restoreBooks(_ items: [Book], context: ModelContext) {
        for item in items {
            let book = ReadingBook(title: item.title, body: item.body)
            book.uid = item.uid
            book.addedAt = item.addedAt
            // 段落总数按当前正文重算：老备份里的数字可能来自切法不同的旧版本，
            // 直接信它会让进度条画到 120%。
            book.paragraphCount = max(1, book.paragraphs.count)
            book.paragraphIndex = min(item.paragraphIndex, book.paragraphCount)
            book.lastReadAt = item.lastReadAt
            context.insert(book)
        }
    }
}
