import SwiftUI

/// 西瓜皮里的头像。
///
/// 有 `authorUID` 的是角色，红底首字；没有的是路人和匿名评论，
/// 用默认的那块西瓜——这是这个 App 唯一允许出现的默认头像。
/// 外面留一圈浅色底，切片才不会像直接贴在列表上。
struct FeedAvatar: View {
    var name: String
    var isCharacter: Bool
    var size: CGFloat = 22

    var body: some View {
        if isCharacter {
            Circle()
                .fill(Theme.brand)
                .frame(width: size, height: size)
                .overlay {
                    Text(String(name.prefix(1)))
                        .font(.system(size: size * 0.46, weight: .bold))
                        .foregroundStyle(.white)
                }
        } else {
            ZStack {
                Circle()
                    .fill(Theme.Watermelon.pith)
                WatermelonMark(size: size * 0.80)
            }
            .frame(width: size, height: size)
        }
    }
}

/// 一张笔记卡。
///
/// 封面就是那张文字图，标题只出现在封面上，下面这行只留作者和赞，
/// 同一句话写两遍会显得这一屏很挤。
struct FeedCard: View {
    let note: FeedNote
    let width: CGFloat

    /// 封面比例跟着版式走：竖排的窄长、票根的扁，双列才不会像贴了两排同样大小的砖。
    static func aspectRatio(for seed: Int) -> CGFloat {
        switch CoverStyle.of(seed) {
        case .photo: return 0.78
        case .poster: return 0.86
        case .sticky: return 1.00
        case .checklist: return 1.15
        case .magazine: return 1.00
        case .quote: return 0.90
        case .vertical: return 0.74
        case .ticket: return 1.22
        case .bubble: return 0.94
        case .marker: return 1.06
        case .split: return 0.88
        case .receipt: return 0.76
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NoteCover(title: note.title, body: note.body, tag: note.tag, seed: note.coverSeed)
                .frame(width: width, height: width / Self.aspectRatio(for: note.coverSeed))
                .clipShape(
                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.grouped, style: .continuous)
                )

            HStack(spacing: 4) {
                FeedAvatar(
                    name: note.authorName,
                    isCharacter: note.authorUID != nil,
                    size: 20
                )

                Text(note.authorName)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "heart")
                    .font(.system(size: 10))
                Text("\(note.likes)")
                    .font(.system(size: PhoneMetrics.FontSize.caption))
            }
            .foregroundStyle(AppSurface.light.secondaryLabel)
            .padding(.top, 5)
        }
        .padding(.bottom, PhoneMetrics.Space.xxs)
    }
}

/// 双列瀑布流的分列。
///
/// 真做瀑布流要量每一张的实际高度，那得等布局完成再回调，列表一滚动就会抖。
/// 按封面比例 + 作者行估算已经够平，两列底的落差通常不超过半张卡。
enum FeedWaterfall {
    static func split(_ notes: [FeedNote], into count: Int, width: CGFloat) -> [[FeedNote]] {
        var columns = Array(repeating: [FeedNote](), count: count)
        var heights = Array(repeating: CGFloat.zero, count: count)

        for note in notes {
            let target = heights.enumerated().min { $0.element < $1.element }?.offset ?? 0
            columns[target].append(note)
            heights[target] += estimatedHeight(of: note, width: width)
        }
        return columns
    }

    static func estimatedHeight(of note: FeedNote, width: CGFloat) -> CGFloat {
        let ratio = FeedCard.aspectRatio(for: note.coverSeed)
        return width / ratio + 22 + PhoneMetrics.Space.xs
    }
}
