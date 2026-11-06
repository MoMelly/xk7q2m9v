import Foundation
import UIKit

/// 一张壁纸的选择结果。
///
/// 两种来源：内置主题（代码画的渐变或随包的图）和自己从相册选的照片。
/// 用「照片文件名非空」判断走哪条，不再单存一个来源枚举——
/// 两个字段互相矛盾的情况（来源写着照片但文件名是空的）就地消失。
struct WallpaperSelection: Equatable {
    var theme: WallpaperTheme = .midnight
    /// 存在 `Documents/wallpapers` 下的文件名。空表示用内置主题。
    var photoFileName: String = ""

    var photo: UIImage? {
        WallpaperPhoto.load(fileName: photoFileName)
    }

    var usesPhoto: Bool { photo != nil }
}

/// 自定义壁纸的落盘。
///
/// 跟头像、表情同一套路子：文件放 Documents，UserDefaults 里只记文件名。
/// 壁纸比头像大得多，压到 1600 长边就够——再高在手机上肉眼看不出，
/// 只是让备份慢、内存占得多。
enum WallpaperPhoto {
    private static let folderName = "wallpapers"
    private static let maxSide: CGFloat = 1600

    private static let cache = NSCache<NSString, UIImage>()

    static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    static func save(image: UIImage) throws -> String {
        let resized = downscale(image, maxSide: maxSide)
        guard let data = resized.jpegData(compressionQuality: 0.86) else {
            throw WallpaperError.encodeFailed
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

    enum WallpaperError: LocalizedError {
        case encodeFailed

        var errorDescription: String? {
            "这张图读不出来，换一张试试。"
        }
    }
}
