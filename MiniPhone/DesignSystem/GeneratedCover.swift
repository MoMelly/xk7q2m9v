import SwiftUI

/// 程序生成的封面。
///
/// 西瓜皮那种「文字封面」不需要图片素材：底色从一组浅色里按 seed 取，
/// 版式固定一种，标题直接排上去。seed 由标题算出，所以同一条笔记
/// 每次打开都是同一个颜色，不会刷一次换一张脸。
struct NoteCover: View {
    let title: String
    let tag: String
    let seed: Int

    private var palette: CoverPalette.Pair {
        CoverPalette.pairs[StableSeed.index(seed, count: CoverPalette.pairs.count)]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [palette.top, palette.bottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 0) {
                if !tag.isEmpty {
                    Text(tag)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(palette.ink.opacity(0.55))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(palette.ink.opacity(0.07))
                        )
                }

                Spacer(minLength: 8)

                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(palette.ink)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
                    .frame(height: 10)

                // 底部一道细线，让标题落得住，不像字飘在色块上。
                Rectangle()
                    .fill(palette.ink.opacity(0.14))
                    .frame(height: 0.5)
            }
            .padding(13)
        }
    }
}

/// 商品缩略图。
///
/// 同理：不接生图接口，用标题首字 + 渐变底拼一块。形状是方的，
/// 放在双列卡里刚好；首字比一张模糊的示意图更能让人认出是什么。
struct ProductThumb: View {
    let title: String
    let seed: Int

    private var palette: CoverPalette.Pair {
        CoverPalette.pairs[StableSeed.index(seed, count: CoverPalette.pairs.count)]
    }

    private var initial: String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "物" : String(clean.prefix(1))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.top, palette.bottom],
                startPoint: .top,
                endPoint: .bottom
            )

            // 一道斜向柔光，纯色块看起来才不会像占位图。
            LinearGradient(
                colors: [.white.opacity(0.55), .white.opacity(0)],
                startPoint: .topLeading,
                endPoint: .center
            )

            Text(initial)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(palette.ink.opacity(0.72))
        }
    }
}

enum CoverPalette {
    /// 浅色底 + 同色系深字。全部是低饱和度的，深色字压得住。
    struct Pair {
        let top: Color
        let bottom: Color
        let ink: Color
    }

    static let pairs: [Pair] = [
        Pair(top: Color(red: 0.99, green: 0.96, blue: 0.91),
             bottom: Color(red: 0.98, green: 0.90, blue: 0.81),
             ink: Color(red: 0.27, green: 0.21, blue: 0.15)),
        Pair(top: Color(red: 0.93, green: 0.96, blue: 0.99),
             bottom: Color(red: 0.84, green: 0.90, blue: 0.97),
             ink: Color(red: 0.13, green: 0.25, blue: 0.36)),
        Pair(top: Color(red: 0.94, green: 0.97, blue: 0.93),
             bottom: Color(red: 0.86, green: 0.93, blue: 0.84),
             ink: Color(red: 0.17, green: 0.27, blue: 0.19)),
        Pair(top: Color(red: 0.97, green: 0.94, blue: 0.96),
             bottom: Color(red: 0.94, green: 0.86, blue: 0.91),
             ink: Color(red: 0.29, green: 0.17, blue: 0.25)),
        Pair(top: Color(red: 1.00, green: 0.98, blue: 0.90),
             bottom: Color(red: 0.98, green: 0.93, blue: 0.77),
             ink: Color(red: 0.30, green: 0.26, blue: 0.13)),
        Pair(top: Color(red: 0.93, green: 0.94, blue: 0.94),
             bottom: Color(red: 0.86, green: 0.89, blue: 0.89),
             ink: Color(red: 0.17, green: 0.21, blue: 0.21)),
        Pair(top: Color(red: 0.96, green: 0.94, blue: 0.99),
             bottom: Color(red: 0.89, green: 0.85, blue: 0.96),
             ink: Color(red: 0.22, green: 0.17, blue: 0.33)),
        Pair(top: Color(red: 0.99, green: 0.94, blue: 0.92),
             bottom: Color(red: 0.98, green: 0.85, blue: 0.82),
             ink: Color(red: 0.33, green: 0.18, blue: 0.15))
    ]
}
