import Foundation

/// 备份里「SwiftData 之外」的文件型数据。
///
/// 这一块原来只搬了视频壁纸、世界状态和头像照片，剩下的都是散落在
/// Documents 下的独立目录：文游存档、自建表情、自选壁纸、导入的音乐、
/// 其它世界。漏掉任何一样，备份恢复完就是「少了一块」——用户导的歌、
/// 玩到一半的存档不会自己回来。
extension DataBackup {

    /// 文件型数据 → Documents 下的目录。
    private static let fileStores: [(name: String, directory: URL)] = [
        ("stories", StoryArchive.directory),
        ("stickers", StickerStorage.directory),
        ("wallpapers", WallpaperPhoto.directory),
        ("Music", MusicLibrary.importedDirectory),
        ("worlds", WorldRegistry.rootURL)
    ]

    // MARK: - 导出

    /// 把各文件目录整份拷进备份目录。
    ///
    /// `worlds/` 里跳过当前活跃世界那个子目录：它的 SwiftData 库正开着，
    /// 拷一个正在写的 SQLite 会拿到撕开的副本；它的内容走 `data.json`
    /// 和 `world-state.json` 那两条已有的路。
    static func exportFileStores(to folder: URL) {
        for (name, directory) in fileStores {
            guard FileManager.default.fileExists(atPath: directory.path) else { continue }
            let destination = folder.appendingPathComponent(name, isDirectory: true)
            try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            copyContents(
                from: directory,
                to: destination,
                skippingDirectory: name == "worlds" ? WorldRegistry.activeID : nil
            )
        }
    }

    // MARK: - 恢复

    /// 把备份里的文件目录搬回 Documents。返回给用户看的清单。
    ///
    /// `worlds/` 同样跳过当前活跃世界的子目录——恢复时的活跃世界
    /// 由 `data.json` 和 `world-state.json` 负责，再叠一份备份里的旧库
    /// 等于拿旧文件盖新数据。
    @discardableResult
    static func restoreFileStores(from folder: URL) -> [String] {
        var extras: [String] = []
        let labels: [String: String] = [
            "stories": "文游存档",
            "stickers": "自建表情",
            "wallpapers": "自选壁纸",
            "Music": "导入的音乐",
            "worlds": "其它世界"
        ]

        for (name, directory) in fileStores {
            let source = folder.appendingPathComponent(name, isDirectory: true)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }

            // 目标目录可能还没建过（全新安装、用户没导入过音乐）。
            // `copyItem` 不会自己建父目录，缺了整段静默失败。
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let count = copyContents(
                from: source,
                to: directory,
                skippingDirectory: name == "worlds" ? WorldRegistry.activeID : nil
            )
            if count > 0, let label = labels[name] {
                extras.append("\(label) \(count) 项")
            }
        }
        return extras
    }

    /// 递归拷目录内容。返回拷过的文件数（目录不算）。
    ///
    /// 目标里已有的同名文件直接盖掉：恢复的语义就是「回到备份那一刻」。
    @discardableResult
    private static func copyContents(
        from source: URL,
        to destination: URL,
        skippingDirectory skip: String? = nil
    ) -> Int {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: nil
        )) ?? []

        var copied = 0
        for item in items {
            if item.hasDirectoryPath {
                if item.lastPathComponent == skip { continue }
                let target = destination.appendingPathComponent(item.lastPathComponent, isDirectory: true)
                try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                copied += copyContents(from: item, to: target)
            } else {
                let target = destination.appendingPathComponent(item.lastPathComponent)
                // `copyItem` 遇到已存在的目标会抛错。不先删的话恢复就变成
                // 「只补新文件」：备份里的同名文件一个都没落盘，界面还报恢复成功。
                try? FileManager.default.removeItem(at: target)
                do {
                    try FileManager.default.copyItem(at: item, to: target)
                    copied += 1
                } catch {
                    // 只数真的写进去的。按尝试次数计，清单上的「N 项」是虚的。
                    AppLog.storage.error("备份写文件失败: \(item.lastPathComponent, privacy: .public)")
                }
            }
        }
        return copied
    }
}
