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
        "worlds"
    ]

    private static let ownedFiles = [
        "world-state.json",
        "raw-replies.json"
    ]

    static func run(context: ModelContext) throws {
        // 先删消息再删角色：两者之间是关系属性，反过来会留下悬空的引用。
        try context.delete(model: StoredMessage.self)
        try context.delete(model: Companion.self)
        try context.delete(model: MomentPost.self)
        try context.delete(model: NoteItem.self)
        try context.delete(model: ReadingBook.self)
        try context.delete(model: WorldEntry.self)
        try context.delete(model: StickerItem.self)
        try context.delete(model: UserProfile.self)
        try context.save()

        let world = WorldStore.shared
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
