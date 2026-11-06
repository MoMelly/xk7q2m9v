import SwiftUI

/// 商品缩略图。
///
/// 不用标题首字当占位：矢量图标从 `ProductGlyph` 取，命中商品名就画对应物件，
/// 没命中按 seed 随机。图标按容器尺寸缩放，商品大卡和购物车 56pt 小图都能用。
struct ProductThumb: View {
    let title: String
    let seed: Int

    private var pair: CoverPalette.Pair {
        CoverPalette.pair(for: seed)
    }

    private var glyph: String {
        ProductGlyph.symbol(title: title, seed: seed)
    }

    var body: some View {
        GeometryReader { proxy in
            let unit = min(proxy.size.width, proxy.size.height)

            ZStack {
                LinearGradient(
                    colors: [pair.top, pair.bottom],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // 一道从左上落下来的柔光，纯色块才不会像占位图。
                LinearGradient(
                    colors: [.white.opacity(0.34), .white.opacity(0)],
                    startPoint: .topLeading,
                    endPoint: .center
                )

                // 图标底下垫一块半透明白圆，浅底上轮廓更清楚。
                Circle()
                    .fill(.white.opacity(0.38))
                    .frame(width: unit * 0.66, height: unit * 0.66)

                Image(systemName: glyph)
                    .font(.system(size: unit * 0.36, weight: .light))
                    .foregroundStyle(pair.ink.opacity(0.78))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipped()
    }
}
