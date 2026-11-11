import SwiftUI
import UIKit

/// 西瓜皮「我的主页」里 `UserProfile` 没存的那一项：封面图。
///
/// 名字、简介、头像都放在 `UserProfile` 里——那是「我」本人在整个 App 的身份，
/// 聊天、主屏、西瓜皮读的是同一份。要是这里另存一套，改了名字之后
/// 「我的身份」和「我的主页」就会是两个名字。
enum FeedProfileStore {
    private static let coverFileName = "feed-cover.jpg"

    private static var coverURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(coverFileName)
    }

    static func loadCover() -> UIImage? {
        guard let coverURL, let data = try? Data(contentsOf: coverURL) else { return nil }
        return UIImage(data: data)
    }

    static func saveCover(_ image: UIImage) {
        guard let coverURL else { return }
        // 封面只占屏幕上半，存原图没意义，还拖慢滚动。
        let maxWidth: CGFloat = 1242
        let scale = min(1, maxWidth / max(image.size.width, 1))
        let target = CGSize(
            width: max(image.size.width * scale, 1),
            height: max(image.size.height * scale, 1)
        )
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        if let data = resized.jpegData(compressionQuality: 0.86) {
            try? data.write(to: coverURL, options: .atomic)
        }
    }

    static func clearCover() {
        guard let coverURL else { return }
        try? FileManager.default.removeItem(at: coverURL)
    }
}
