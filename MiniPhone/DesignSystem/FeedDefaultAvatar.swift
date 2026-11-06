import SwiftUI

/// 西瓜皮里路人作者的默认头像。
///
/// 原来所有路人都用同一块西瓜，列表里像一整排同一个人。
/// 这里用系统矢量符号配稳定哈希：同一个作者在任何页面都是同一张脸，
/// 换人换脸，而且不用往包里塞网图。
enum FeedDefaultAvatar {
    static let symbols: [String] = [
        "face.smiling.fill",
        "sun.max.fill",
        "moon.stars.fill",
        "cloud.fill",
        "leaf.fill",
        "heart.fill",
        "star.fill",
        "sparkles",
        "drop.fill",
        "flame.fill",
        "snowflake",
        "camera.macro",
        "pawprint.fill",
        "bolt.fill",
        "circle.grid.2x2.fill",
        "fish.fill"
    ]

    static func symbol(for name: String) -> String {
        symbols[StableSeed.index(StableSeed.of(name), count: symbols.count)]
    }
}

struct FeedDefaultAvatarView: View {
    let name: String
    var size: CGFloat = 22

    private var pair: CoverPalette.Pair {
        CoverPalette.pair(for: StableSeed.of(name))
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [pair.top, pair.bottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Image(systemName: FeedDefaultAvatar.symbol(for: name))
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(pair.ink.opacity(0.78))
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(.white.opacity(0.45), lineWidth: 0.5)
        }
    }
}
