import SwiftUI

/// 一条笔记的封面：有真图就用真图，没有就排文字封面。
///
/// 四种地方在用（瀑布流、详情页、个人主页九宫格、作者页九宫格），
/// 尺寸各不相同，但「有没有图、怎么裁」的判断是同一件事，所以收成一个视图。
///
/// 真图一律 `scaledToFill` + 居中裁：生出来的是 1024 方图，格子是 4:5 或更窄，
/// 拉伸会把人拉扁，留白会露出底色。裁掉两边的代价比这两样都小。
struct FeedCover: View {
    let note: FeedNote
    /// 显式高度。格子那种由父视图撑高的地方传 nil，跟着走。
    var height: CGFloat? = nil

    var body: some View {
        if let image = FeedImageStorage.image(note.imageFile) {
            Color.clear
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(height: height)
                .clipped()
        } else {
            NoteCover(title: note.title, body: note.body, tag: note.tag, seed: note.coverSeed)
                .frame(height: height)
        }
    }
}
