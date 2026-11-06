import SwiftUI

/// 商品用的矢量图标。
///
/// SF Symbols 是系统自带的矢量图标库：不下载素材、不占包体、任意尺寸都清楚。
/// 标题命中关键词就画对应物件；没命中按稳定 seed 从通用池里取一个，
/// 同一件商品重启之后仍是同一个图标，不会每次打开都换脸。
enum ProductGlyph {
    private static let rules: [(keywords: [String], symbol: String)] = [
        (["杯", "玻璃", "水具"], "cup.and.saucer.fill"),
        (["台灯", "灯", "灯具"], "lamp.table.fill"),
        (["桌布", "棉麻", "毯", "布"], "square.grid.2x2.fill"),
        (["便签", "笔记", "本子", "纸"], "book.closed.fill"),
        (["铅笔", "钢笔", "笔"], "pencil"),
        (["薄荷", "绿植", "植物", "叶"], "leaf.fill"),
        (["花", "干花"], "camera.macro"),
        (["云", "天空"], "cloud.fill"),
        (["香薰", "蜡烛"], "flame.fill"),
        (["杯垫", "托盘", "盘"], "circle.grid.2x2.fill"),
        (["钥匙", "挂件"], "key.fill"),
        (["枕头", "靠垫", "床"], "bed.double.fill"),
        (["耳机", "音乐"], "headphones"),
        (["时钟", "闹钟"], "clock.fill"),
        (["相机", "照片"], "camera.fill"),
        (["包", "袋", "收纳"], "bag.fill"),
        (["伞"], "umbrella.fill"),
        (["星", "夜灯"], "star.fill"),
        (["水滴", "加湿"], "drop.fill"),
        (["猫", "小狗"], "pawprint.fill")
    ]

    /// 没命中关键词时的通用池。都是 iOS 17 起就有的基础符号，不会出现空白图。
    private static let fallback: [String] = [
        "circle.grid.2x2.fill",
        "sparkles",
        "star.fill",
        "heart.fill",
        "leaf.fill",
        "cloud.fill",
        "sun.max.fill",
        "moon.stars.fill",
        "drop.fill",
        "flame.fill",
        "bolt.fill",
        "snowflake",
        "camera.macro",
        "pawprint.fill",
        "face.smiling.fill",
        "square.fill"
    ]

    static func symbol(title: String, seed: Int) -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        for rule in rules where rule.keywords.contains(where: { clean.contains($0) }) {
            return rule.symbol
        }
        let index = StableSeed.index(StableSeed.of(clean) ^ seed, count: fallback.count)
        return fallback[index]
    }
}
