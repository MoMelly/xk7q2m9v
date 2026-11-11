import SwiftUI

/// 每首歌自己的颜色。
///
/// 原来所有歌的封面、播放条、唱片、悬浮球用的是同一组粉红渐变——列表扫下去
/// 二十行一个样，分不出哪首是哪首。这里按歌算一个稳定的色号：
/// 同一首歌每次进来颜色一样，不会刷新一次换一身。
enum TrackArt {
    /// 两两配对，保证一组是「亮 → 暗」的斜向渐变，不会出现两块同明度的色。
    private static let pairs: [(Color, Color)] = [
        (Theme.IconTint.pink, Theme.IconTint.orange),
        (Theme.IconTint.teal, Theme.IconTint.indigo),
        (Theme.IconTint.yellow, Theme.IconTint.orange),
        (Theme.IconTint.purple, Theme.IconTint.pink),
        (Theme.IconTint.green, Theme.IconTint.teal),
        (Theme.IconTint.rose, Theme.IconTint.purple),
        (Theme.IconTint.indigo, Theme.IconTint.teal),
        (Theme.IconTint.orange, Theme.IconTint.rose)
    ]

    /// 文件名做种。用它而不是 `UUID`：UUID 每次重建播放器都会变，
    /// 同一首歌换个界面就换色。
    private static func seed(_ key: String) -> Int {
        var hash = 5381
        for byte in key.utf8 {
            hash = (hash &* 33 &+ Int(byte)) & 0x7FFF_FFFF
        }
        return hash
    }

    static func colors(for key: String) -> [Color] {
        let pair = pairs[seed(key) % pairs.count]
        return [pair.0, pair.1]
    }

    /// 单色。唱片芯、进度点缀用它，和封面同色系。
    static func tint(for key: String) -> Color {
        colors(for: key).first ?? Theme.IconTint.rose
    }

    static func gradient(for key: String) -> LinearGradient {
        LinearGradient(
            colors: colors(for: key),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
