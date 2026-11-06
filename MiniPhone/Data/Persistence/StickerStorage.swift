import Foundation
import SwiftData
import UIKit

/// 表情的落盘与读取。
///
/// 图片走文件、库里只存文件名。原因写在 `StickerItem` 的注释里：
/// 一整套表情塞进 SwiftData，数据库会长到没法用。
enum StickerStorage {
    private static let folderName = "stickers"

    static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    /// 把一张图存成表情，返回文件名。图太大先压到 512 长边——
    /// 表情最大也就显示 120pt，原图几兆纯属浪费。
    static func save(image: UIImage) throws -> String {
        let resized = downscale(image, maxSide: 512)
        guard let data = resized.pngData() else {
            throw StickerError.encodeFailed
        }
        let fileName = "\(UUID().uuidString).png"
        try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        return fileName
    }

    static func load(fileName: String) -> UIImage? {
        guard !fileName.isEmpty else { return nil }
        let url = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// 内置表情的图在 bundle 的 `Stickers/` 目录里，不是 Documents。
    static func builtInImage(key: String) -> UIImage? {
        guard !key.isEmpty,
              let url = Bundle.main.url(forResource: key, withExtension: "png", subdirectory: "Stickers"),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// 删记录时一起调用。文件没了不算错——用户可能在别处清理过。
    static func delete(fileName: String) {
        guard !fileName.isEmpty else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }

    private static func downscale(_ image: UIImage, maxSide: CGFloat) -> UIImage {        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide else { return image }

        let scale = maxSide / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    enum StickerError: LocalizedError {
        case encodeFailed

        var errorDescription: String? {
            "这张图读不出来，换一张试试。"
        }
    }
}

/// 内置那一套表情。
///
/// 图随包放在 `Assets/Stickers`，库里只存资源名。
/// 不塞进 SwiftData 是因为这套是只读的，用户改了也没意义；
/// 存文件名还能让他删了之后从备份恢复。
enum BuiltInStickers {
    struct Definition {
        let key: String
        let name: String
    }

    static let groupName = "呆猫"

    /// 名字就是提示词里那个词。都写成两个字的情绪词，
    /// 模型挑表情时才分得清「嫌弃」和「冷漠」不是一回事。
    static let all: [Definition] = [
        Definition(key: "cat_cry", name: "大哭"),
        Definition(key: "cat_gloom", name: "委屈"),
        Definition(key: "cat_sideeye", name: "嫌弃"),
        Definition(key: "cat_content", name: "心满意足"),
        Definition(key: "cat_shy", name: "害羞"),
        Definition(key: "cat_smirk", name: "坏笑"),
        Definition(key: "cat_innocent", name: "无辜"),
        Definition(key: "cat_puppy", name: "卖萌"),
        Definition(key: "cat_sad", name: "难过"),
        Definition(key: "cat_aloof", name: "冷漠"),
        Definition(key: "cat_adopt", name: "求收养")
    ]

    /// 首次启动注入。已经有一套就不重复插，用户删掉某个也不补回来——
    /// 补回来会让人以为删除没生效。
    @MainActor
    static func ensure(in context: ModelContext) {
        let descriptor = FetchDescriptor<StickerItem>(
            predicate: #Predicate { $0.builtInKey != "" }
        )
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }

        for definition in all {
            context.insert(
                StickerItem(
                    name: definition.name,
                    group: groupName,
                    builtInKey: definition.key
                )
            )
        }
        try? context.save()
    }
}
