import Foundation
import UIKit

/// 内置头像的四组。
///
/// 一开始有一组真人照片，后来全撤了：这个 App 里的角色是陪聊的虚构人物，
/// 挂一张真人脸反而别扭，也不该拿陌生人的照片去冒充角色。
/// 现在只留猫狗、卡通、二次元插画和风景，没有一张真人。
enum AvatarGroup: String, CaseIterable, Identifiable {
    case pet
    case mascot
    case anime
    case scenery

    var id: String { rawValue }

    /// 文件名里的组标记：`avatar_c01` 里的 `c`。
    var filePrefix: String {
        switch self {
        case .pet: return "avatar_c"
        case .mascot: return "avatar_k"
        case .anime: return "avatar_a"
        case .scenery: return "avatar_s"
        }
    }

    var title: String {
        switch self {
        case .pet: return "猫狗"
        case .mascot: return "卡通"
        case .anime: return "二次元"
        case .scenery: return "风景"
        }
    }
}

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

    /// 随包的头像清单，按组分开。
    ///
    /// 扫目录而不是写死数组：以后往里加几张照片不用回来改代码，
    /// 也不会出现「加了文件但界面里没有」这种对不上的情况。
    /// 分组靠文件名前缀（`avatar_c01` / `avatar_k01` / `avatar_a01` / `avatar_s01`），
    /// 加图时把文件按前缀放进来就会自动归位。
    static let gallery: [AvatarGroup: [String]] = {
        guard let folder = Bundle.main.url(forResource: "Avatars", withExtension: nil),
              let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else {
            return [:]
        }
        var result: [AvatarGroup: [String]] = [:]
        for group in AvatarGroup.allCases {
            result[group] = names
                .filter { $0.hasPrefix(group.filePrefix) && $0.hasPrefix("avatar_") }
                .sorted()
                .map { ($0 as NSString).deletingPathExtension }
        }
        return result
    }()

    static func keys(in group: AvatarGroup) -> [String] {
        gallery[group] ?? []
    }

    /// 早期版本内置过一组真人照片（`avatar_p` 前缀），后来整组撤掉了。
    /// 老库里还挂着这些键，读不到文件会退化成字母圈，启动时拿这个判断后换掉。
    static func isRetired(key: String) -> Bool {
        key.hasPrefix("avatar_p")
    }

    /// 随手抽一张，给没挑过头像的人当初始值。
    ///
    /// 全空（资源没打进包）时返回空串，上层照旧回落到渐变圆加首字，
    /// 不会因为抽不到图就变成一块空白。
    static func randomKey() -> String {
        let all = AvatarGroup.allCases.flatMap { keys(in: $0) }
        return all.randomElement() ?? ""
    }

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
