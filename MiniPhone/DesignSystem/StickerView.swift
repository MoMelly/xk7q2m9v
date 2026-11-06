import SwiftData
import SwiftUI

/// 一个表情的画法。
///
/// 内置的走绘制，上传的走文件。文件读不到时给一块浅灰占位——
/// 直接留空会让人以为表情丢了，其实是记录还在、图被人清理了。
struct StickerView: View {
    let item: StickerItem
    var size: CGFloat = 96

    var body: some View {
        Group {
            if item.isBuiltIn {
                if let image = StickerStorage.builtInImage(key: item.builtInKey) {
                    stickerImage(image)
                } else {
                    placeholder
                }
            } else if let image = StickerStorage.load(fileName: item.fileName) {
                stickerImage(image)
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.16, style: .continuous))
    }

    private func stickerImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
            .fill(Theme.separator.opacity(0.28))
            .overlay {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: size * 0.3))
                    .foregroundStyle(Theme.secondaryLabel)
            }
    }
}
