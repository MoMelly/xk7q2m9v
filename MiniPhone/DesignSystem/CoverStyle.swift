import SwiftUI

/// 封面的版式。
///
/// 小红书那种「文字图片」不是一种排版，是很多种：大字压角、便签、清单、编号、
/// 竖排、票根……同一屏里混着出现，才像真人一张张做的。
/// 这里给十二种，seed 决定用哪一种，同一条笔记每次打开都是同一张。
/// 新加的版式一律排在后面，rawValue 即版式编号。版式总数变化时取模基数跟着变，
/// 已有笔记会重新排一次版；封面是现场生成的、不落图片文件，所以只是换张脸，不丢数据。
enum CoverStyle: Int, CaseIterable {
    case poster
    case sticky
    case checklist
    case magazine
    case quote
    case vertical
    case ticket
    case photo
    case bubble
    case marker
    case split
    case receipt

    static func of(_ seed: Int) -> CoverStyle {
        CoverStyle(rawValue: StableSeed.index(seed, count: CoverStyle.allCases.count)) ?? .poster
    }
}

/// 封面配色。
///
/// 底色按 seed 现算一个低饱和浅色，而不是从固定色卡里挑：色卡里的第十组
/// 永远配第十种版式，看几屏就能看出规律。色相、饱和度、明度各自带一点浮动，
/// 文字色和强调色由同一个色相压出来，保证浅底深字始终读得清。
enum CoverPalette {
    struct Pair {
        let top: Color
        let bottom: Color
        let ink: Color
        let accent: Color
    }

    /// 颜色种子走一次字符串哈希，和版式用的 seed 取模完全分开。
    /// 同一版式因此能落在任意浅色上，同一种浅色也能配任意版式。
    static func pair(for seed: Int) -> Pair {
        let colorSeed = StableSeed.of("cover-color:\(seed)")
        let hue = Double(StableSeed.index(colorSeed, count: 360)) / 360.0
        let saturation = 0.10 + Double(StableSeed.index(colorSeed / 7, count: 9)) / 100.0
        let brightness = 0.95 + Double(StableSeed.index(colorSeed / 13, count: 4)) / 100.0
        let accentHue = hue + 0.08 > 1 ? hue - 0.92 : hue + 0.08

        return Pair(
            top: Color(hue: hue, saturation: saturation, brightness: brightness),
            bottom: Color(
                hue: hue,
                saturation: min(saturation + 0.06, 0.28),
                brightness: brightness - 0.06
            ),
            ink: Color(hue: hue, saturation: min(saturation + 0.22, 0.42), brightness: 0.20),
            accent: Color(hue: accentHue, saturation: 0.52, brightness: 0.52)
        )
    }
}

/// 封面上的文字处理：切句、挑 emoji、挑数字。
///
/// 全部由 seed 决定，纯函数，不碰随机数——同一个 seed 必须每次切得一模一样。
enum CoverText {
    /// 贴在文字图上的小图标。不用 SF Symbol：emoji 才有「用户自己贴上去的」味道。
    static let emojis = ["🍉", "🌿", "☁️", "📚", "🧋", "✨", "🌙", "🫧", "🍜", "🐈", "🪴", "🎧"]

    static func emoji(_ seed: Int, offset: Int = 0) -> String {
        emojis[StableSeed.index(seed + offset * 7, count: emojis.count)]
    }

    /// 按句号问号切句。清单版式要拿它拆出几行短句。
    static func sentences(_ text: String, limit: Int = 4) -> [String] {
        let stops: Set<Character> = ["。", "！", "？", "!", "?", "；", ";", "\n"]
        var result: [String] = []
        var current = ""

        for char in text {
            if stops.contains(char) {
                let line = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !line.isEmpty { result.append(line) }
                current = ""
            } else {
                current.append(char)
            }
        }

        let rest = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rest.isEmpty { result.append(rest) }
        return Array(result.prefix(limit))
    }

    /// 杂志版式的大编号。1–9，两位排出来太挤。
    static func number(_ seed: Int) -> String {
        String(StableSeed.index(seed, count: 9) + 1)
    }
}

// MARK: - 背景纹理

/// 细网格。压在海报版式底下，纯色块才不会像占位图。
struct CoverGrid: View {
    var color: Color
    var spacing: CGFloat = 15

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                var x: CGFloat = spacing
                while x < proxy.size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                    x += spacing
                }
                var y: CGFloat = spacing
                while y < proxy.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    y += spacing
                }
            }
            .stroke(color, lineWidth: 0.5)
        }
    }
}

/// 斜条纹。便签版式用，像笔记本内页的底纹。
struct CoverStripes: View {
    var color: Color
    var spacing: CGFloat = 11

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                var x: CGFloat = -proxy.size.height
                while x < proxy.size.width {
                    path.move(to: CGPoint(x: x, y: proxy.size.height))
                    path.addLine(to: CGPoint(x: x + proxy.size.height, y: 0))
                    x += spacing
                }
            }
            .stroke(color, lineWidth: 1)
        }
    }
}

/// 横线。清单版式的横格纸。
struct CoverRules: View {
    var color: Color
    var spacing: CGFloat = 22

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                var y: CGFloat = spacing
                while y < proxy.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    y += spacing
                }
            }
            .stroke(color, lineWidth: 0.5)
        }
    }
}

/// 虚线。票根版式的撕口。
struct CoverDashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
