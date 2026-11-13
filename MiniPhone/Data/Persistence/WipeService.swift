import Foundation
import SwiftData

/// 清空这台手机上的东西。
///
/// 只清内容，不动外观（主题、图标样式、缩放）：外观是「这台手机长什么样」，
/// 不是「我攒下了什么」。清完回到刚装好的样子——下次启动会重新种
/// 两个角色和一个群，不是一张空列表。
@MainActor
enum WipeService {
    /// 会删掉的本机目录。都在 Documents 下面，只动这几个人自己建的。
    private static let ownedDirectories = [
        "Music",
        "Lyrics",
        "Wallpapers",
        "avatars",
        "worlds",
        "identity-states"
    ]

    private static let ownedFiles = [
        "world-state.json",
        "raw-replies.json",
        "feed-cover.jpg"
    ]

    static func run(context: ModelContext) throws {
        // 消息和角色必须一条一条删，不能用 `context.delete(model:)`。
        //
        // 那个接口走的是 batch delete：直接下一条 SQL 把行抹掉，不经过
        // Core Data 的关系维护。而 `StoredMessage.character` 是必填的 to-one，
        // 角色没了这条关系就得置空才合法，批量删不会置空——整笔操作直接报
        // constraint trigger violation，一条都没删成。逐个删才会走关系规则。
        for message in try context.fetch(FetchDescriptor<StoredMessage>()) {
            context.delete(message)
        }
        for companion in try context.fetch(FetchDescriptor<Companion>()) {
            context.delete(companion)
        }
        // 剩下这几个身上没有必填关系，批量删没问题。
        try context.delete(model: MomentPost.self)
        try context.delete(model: NoteItem.self)
        try context.delete(model: ReadingBook.self)
        try context.delete(model: WorldEntry.self)
        try context.delete(model: StickerItem.self)
        try context.delete(model: UserProfile.self)
        try context.save()

        // 身份状态也要清掉，并且回到默认身份：不清的话会站在一个
        // 已经被删空的人格上。写入口先指回默认文件再落盘，免得
        // 把空状态写进马上要删掉的那个身份目录里。
        IdentityScope.shared.resetToDefault()
        let world = WorldStore.shared
        world.adoptActiveIdentityFile()
        world.state = .empty
        world.primaryName = ""
        world.save()

        let manager = FileManager.default
        if let documents = manager.urls(for: .documentDirectory, in: .userDomainMask).first {
            for name in ownedDirectories {
                let url = documents.appendingPathComponent(name, isDirectory: true)
                if manager.fileExists(atPath: url.path) {
                    try? manager.removeItem(at: url)
                }
            }
            for name in ownedFiles {
                let url = documents.appendingPathComponent(name)
                if manager.fileExists(atPath: url.path) {
                    try? manager.removeItem(at: url)
                }
            }
        }

        HomeLayout.reset()
        FirstRunSeed.resetFlag()

        // 阅读的字号、行距、纸色跟着书一起走：书没了，留着这些没有意义。
        for key in UserDefaults.standard.dictionaryRepresentation().keys
        where key.hasPrefix("reading.") {
            UserDefaults.standard.removeObject(forKey: key)
        }

        PlayerService.shared.stop()
    }
}
