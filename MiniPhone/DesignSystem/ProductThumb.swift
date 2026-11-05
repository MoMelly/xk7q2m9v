import SwiftUI

/// 商品缩略图。
///
/// 同理：不接生图接口，用标题首字 + 渐变底拼一块。形状是方的，
/// 放在双列卡里刚好；首字比一张模糊的示意图更能让人认出是什么。
struct ProductThumb: View {
    let title: String
    let seed: Int

    private var pair: CoverPalette.Pair {
        CoverPalette.pairs[StableSeed.index(seed, count: CoverPalette.pairs.count)]
    }

    private var initial: String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "物" : String(clean.prefix(1))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [pair.top, pair.bottom],
                startPoint: .top,
                endPoint: .bottom
            )

            // 一道斜向柔光，纯色块看起来才不会像占位图。
            LinearGradient(
                colors: [.white.opacity(0.55), .white.opacity(0)],
                startPoint: .topLeading,
                endPoint: .center
            )

            Circle()
                .fill(pair.accent.opacity(0.12))
                .frame(width: 90, height: 90)
                .blur(radius: 14)
                .offset(x: 34, y: 40)

            Text(initial)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(pair.ink.opacity(0.72))
        }
        .clipped()
    }
}
