import Foundation
import UIKit

/// 西瓜皮配图的落盘。
///
/// 和表情一样走文件、库里只存文件名：一张 1024 的 JPEG 一百多 KB，
/// 塞进 `WorldState`（整份 JSON 每次改动都要重写）会让保存越来越慢。
///
/// 这里是**缓存**，不是资料：清掉了顶多下次重新生成，不会丢用户的任何东西。
/// 所以 `FeedImageStorage.clear()` 可以放心给一个按钮。
enum FeedImageStorage {
    private static let folderName = "feedImages"

    /// 内存缓存。列表滚动时会反复问同一批文件名，
    /// 每次读盘解一张 1024 的图，瀑布流会明显掉帧。
    private static let cache = NSCache<NSString, UIImage>()

    static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    static func save(_ image: UIImage) throws -> String {
        let resized = downscale(image, maxSide: 1_024)
        guard let data = resized.jpegData(compressionQuality: 0.86) else {
            throw FeedImageError.encodeFailed
        }
        let fileName = "\(UUID().uuidString).jpg"
        try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        cache.setObject(resized, forKey: fileName as NSString)
        return fileName
    }

    static func image(_ fileName: String?) -> UIImage? {
        guard let fileName, !fileName.isEmpty else { return nil }
        if let hit = cache.object(forKey: fileName as NSString) { return hit }
        let url = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
            return nil
        }
        cache.setObject(image, forKey: fileName as NSString)
        return image
    }

    static func delete(_ fileName: String?) {
        guard let fileName, !fileName.isEmpty else { return }
        cache.removeObject(forKey: fileName as NSString)
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }

    /// 清整个池子。已经被帖子引用的文件名会变成死链，
    /// 于是退回文字封面——这也是「清缓存」该有的结果。
    static func clear() {
        cache.removeAllObjects()
        let items = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for item in items {
            try? FileManager.default.removeItem(at: item)
        }
    }

    /// 池子占多大。设置页用来告诉用户这些图值多少空间。
    static func totalBytes() -> Int {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        return items.reduce(0) { sum, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return sum + size
        }
    }

    private static func downscale(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide else { return image }
        let scale = maxSide / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: target).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    enum FeedImageError: LocalizedError {
        case encodeFailed

        var errorDescription: String? {
            "这张图存不下来，再试一次。"
        }
    }
}
