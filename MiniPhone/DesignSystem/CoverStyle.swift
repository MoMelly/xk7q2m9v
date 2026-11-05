import SwiftUI

/// 封面的版式。
///
/// 小红书那种「文字图片」不是一种排版，是很多种：大字压角、便签、清单、编号、
/// 竖排、票根……同一屏里混着出现，才像真人一张张做的。
/// 这里给八种，seed 决定用哪一种，同一条笔记每次打开都是同一张。
enum CoverStyle: Int, CaseIterable {
    case poster
    case sticky
    case checklist
    case magazine
    case quote
    case vertical
    case ticket
    case photo

    static func of(_ seed: Int) -> CoverStyle {
        CoverStyle(rawValue: StableSeed.index(seed, count: CoverStyle.allCases.count)) ?? .poster
    }
}

/// 封面配色。浅色底 + 同色系深字 + 一个强调色，强调色用来压高亮块。
///
/// 全部低饱和：真图封面很少用纯红纯绿，饱和度一高就像广告位。
enum CoverPalette {
    struct Pair {
        let top: Color
        let bottom: Color
        let ink: Color
        let accent: Color
    }

    static let pairs: [Pair] = [
        Pair(top: Color(red: 0.99, green: 0.96, blue: 0.91),
             bottom: Color(red: 0.98, green: 0.89, blue: 0.79),
             ink: Color(red: 0.27, green: 0.20, blue: 0.14),
             accent: Color(red: 0.86, green: 0.42, blue: 0.28)),
        Pair(top: Color(red: 0.93, green: 0.96, blue: 0.99),
             bottom: Color(red: 0.83, green: 0.90, blue: 0.97),
             ink: Color(red: 0.12, green: 0.23, blue: 0.35),
             accent: Color(red: 0.24, green: 0.45, blue: 0.78)),
        Pair(top: Color(red: 0.95, green: 0.97, blue: 0.92),
             bottom: Color(red: 0.85, green: 0.93, blue: 0.83),
             ink: Color(red: 0.16, green: 0.26, blue: 0.18),
             accent: Color(red: 0.33, green: 0.54, blue: 0.34)),
        Pair(top: Color(red: 0.98, green: 0.94, blue: 0.96),
             bottom: Color(red: 0.94, green: 0.85, blue: 0.90),
             ink: Color(red: 0.28, green: 0.16, blue: 0.24),
             accent: Color(red: 0.78, green: 0.35, blue: 0.50)),
        Pair(top: Color(red: 1.00, green: 0.98, blue: 0.90),
             bottom: Color(red: 0.98, green: 0.92, blue: 0.74),
             ink: Color(red: 0.30, green: 0.25, blue: 0.11),
             accent: Color(red: 0.86, green: 0.62, blue: 0.18)),
        Pair(top: Color(red: 0.94, green: 0.94, blue: 0.95),
             bottom: Color(red: 0.85, green: 0.87, blue: 0.88),
             ink: Color(red: 0.16, green: 0.20, blue: 0.21),
             accent: Color(red: 0.38, green: 0.46, blue: 0.48)),
        Pair(top: Color(red: 0.96, green: 0.94, blue: 0.99),
             bottom: Color(red: 0.88, green: 0.84, blue: 0.96),
             ink: Color(red: 0.21, green: 0.16, blue: 0.32),
             accent: Color(red: 0.50, green: 0.36, blue: 0.74)),
        Pair(top: Color(red: 0.99, green: 0.94, blue: 0.92),
             bottom: Color(red: 0.97, green: 0.84, blue: 0.80),
             ink: Color(red: 0.32, green: 0.17, blue: 0.14),
             accent: Color(red: 0.88, green: 0.36, blue: 0.32)),
        Pair(top: Color(red: 0.92, green: 0.96, blue: 0.97),
             bottom: Color(red: 0.80, green: 0.89, blue: 0.92),
             ink: Color(red: 0.12, green: 0.24, blue: 0.28),
             accent: Color(red: 0.26, green: 0.52, blue: 0.60)),
        Pair(top: Color(red: 0.99, green: 0.97, blue: 0.94),
             bottom: Color(red: 0.95, green: 0.90, blue: 0.84),
             ink: Color(red: 0.24, green: 0.19, blue: 0.16),
             accent: Color(red: 0.62, green: 0.38, blue: 0.24))
    ]
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
