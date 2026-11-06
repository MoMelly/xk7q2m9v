import Foundation
import UIKit

/// 头像照片的读取与落盘。
///
/// 两个来源：随包的内置照片（`Assets/Avatars`）和用户从相册传的
/// （`Documents/avatars`）。跟表情一样，库里只存名字，图不塞进 SwiftData。
///
/// 读图带缓存：会话列表一屏十几个头像，每次从磁盘读 JPEG 会拖慢滚动，
/// 尤其是列表重绘时一帧要碰十几次。
enum AvatarPhoto {
    private static let folderName = "avatars"

    private static let cache = NSCache<NSString, UIImage>()

    static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    /// 随包的头像清单。
    ///
    /// 扫目录而不是写死数组：以后往里加几张照片不用回来改代码，
    /// 也不会出现「加了文件但界面里没有」这种对不上的情况。
    static let builtInKeys: [String] = {
        guard let folder = Bundle.main.url(forResource: "Avatars", withExtension: nil),
              let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else {
            return []
        }
        return names
            .filter { $0.hasPrefix("avatar_") }
            .sorted()
            .map { ($0 as NSString).deletingPathExtension }
    }()

    static func builtIn(key: String) -> UIImage? {
        guard !key.isEmpty else { return nil }
        if let hit = cache.object(forKey: key as NSString) { return hit }

        guard let url = Bundle.main.url(
            forResource: key,
            withExtension: "jpg",
            subdirectory: "Avatars"
        ), let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        cache.setObject(image, forKey: key as NSString)
        return image
    }

    /// 存一张上传的头像，返回文件名。
    ///
    /// 压到 512 长边：头像最大显示也就 112pt，原图几兆没有任何收益，
    /// 反而让 iCloud 备份变慢。
    static func save(image: UIImage) throws -> String {
        let resized = downscale(image, maxSide: 512)
        guard let square = cropSquare(resized),
              let data = square.jpegData(compressionQuality: 0.86) else {
            throw AvatarError.encodeFailed
        }
        let fileName = "\(UUID().uuidString).jpg"
        try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        return fileName
    }

    static func load(fileName: String) -> UIImage? {
        guard !fileName.isEmpty else { return nil }
        if let hit = cache.object(forKey: fileName as NSString) { return hit }
        let url = directory.appendingPathComponent(fileName)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: fileName as NSString)
        return image
    }

    static func delete(fileName: String) {
        guard !fileName.isEmpty else { return }
        cache.removeObject(forKey: fileName as NSString)
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }

    // MARK: - 图像处理

    private static func downscale(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide else { return image }

        let scale = maxSide / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// 居中裁成正方形。头像框是圆的，留长方图进去两边会被切掉，
    /// 先裁好至少保证看到的是同一块。
    private static func cropSquare(_ image: UIImage) -> UIImage? {
        let width = image.size.width
        let height = image.size.height
        let side = min(width, height)
        guard side > 0 else { return nil }

        let origin = CGPoint(x: (width - side) / 2, y: (height - side) / 2)
        guard let cgImage = image.cgImage?.cropping(
            to: CGRect(
                x: origin.x * image.scale,
                y: origin.y * image.scale,
                width: side * image.scale,
                height: side * image.scale
            )
        ) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    enum AvatarError: LocalizedError {
        case encodeFailed

        var errorDescription: String? {
            "这张图读不出来，换一张试试。"
        }
    }
}
