import Foundation
import AVFoundation

/// 歌单来源有两处：随包发布的 `Assets/Music/`，以及自己导入的音频。
///
/// 随包的走 folder reference，重装不会丢；导入的存在 Documents，
/// 不进备份（按拍板结论：歌单随软件发，视频壁纸才随备份）。
enum MusicLibrary {
    private static let bundlePrefix = "bundle:"
    private static let documentPrefix = "doc:"

    private static let extensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aiff", "caf"]

    static var importedDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Music", isDirectory: true)
    }

    static func allTracks() -> [Track] {
        var result: [Track] = []

        if let bundled = Bundle.main.url(forResource: "Music", withExtension: nil) {
            result.append(contentsOf: tracks(in: bundled, prefix: bundlePrefix))
        } else if let root = Bundle.main.resourceURL {
            // folder reference 没生效时，XcodeGen 会把音频平铺在 bundle 根目录。
            result.append(contentsOf: tracks(in: root, prefix: bundlePrefix))
        }
        result.append(contentsOf: tracks(in: importedDirectory, prefix: documentPrefix))
        return result
    }

    static func url(for track: Track) -> URL? {
        if track.fileName.hasPrefix(bundlePrefix) {
            let name = String(track.fileName.dropFirst(bundlePrefix.count))
            if let bundled = Bundle.main.url(forResource: "Music", withExtension: nil) {
                return bundled.appendingPathComponent(name)
            }
            return Bundle.main.resourceURL?.appendingPathComponent(name)
        }
        if track.fileName.hasPrefix(documentPrefix) {
            let name = String(track.fileName.dropFirst(documentPrefix.count))
            return importedDirectory.appendingPathComponent(name)
        }
        return nil
    }

    /// 批量导入。同名文件直接覆盖，重复点导入不会产生重复曲目。
    static func importFiles(_ urls: [URL]) throws -> Int {
        try FileManager.default.createDirectory(at: importedDirectory, withIntermediateDirectories: true)
        var count = 0
        for source in urls {
            let accessing = source.startAccessingSecurityScopedResource()
            defer { if accessing { source.stopAccessingSecurityScopedResource() } }

            guard extensions.contains(source.pathExtension.lowercased()) else { continue }
            let target = importedDirectory.appendingPathComponent(source.lastPathComponent)
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
            try FileManager.default.copyItem(at: source, to: target)
            count += 1
        }
        return count
    }

    /// 只有自己导进来的能删。随包的音频在 App 包里，删了下次启动又会冒出来。
    static func isDeletable(_ track: Track) -> Bool {
        track.fileName.hasPrefix(documentPrefix)
    }

    /// 删掉一条导入的音频，连带它那份歌词。
    static func delete(_ track: Track) throws {
        guard isDeletable(track), let url = url(for: track) else { return }
        try FileManager.default.removeItem(at: url)

        // 同名 .lrc 一起清掉，不然重新导入同一首会挂上一份旧歌词。
        let lrc = url.deletingPathExtension().appendingPathExtension("lrc")
        if FileManager.default.fileExists(atPath: lrc.path) {
            try? FileManager.default.removeItem(at: lrc)
        }
        LyricStore.delete(for: track)
    }

    private static func tracks(in directory: URL, prefix: String) -> [Track] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        return files
            .filter { extensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            .map { url in
                let raw = url.deletingPathExtension().lastPathComponent
                let parts = raw.split(separator: "-", maxSplits: 1).map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
                let artist = parts.count > 1 ? parts[0] : "未知"
                let title = parts.count > 1 ? parts[1] : parts[0]
                let identifier = prefix + url.lastPathComponent
                return Track(
                    id: identifier,
                    title: title,
                    artist: artist,
                    fileName: identifier
                )
            }
    }
}
