import SwiftUI

/// 程序生成的封面。
///
/// 西瓜皮那种「文字图」不需要图片素材：底色从一组浅色里按 seed 取，
/// 版式从八种里按 seed 挑一种，标题、正文摘要、话题按各自的规则排上去。
/// seed 由标题算出，所以同一条笔记每次打开都是同一张，不会刷一次换一张脸。
///
/// 八种版式的正文排版在 `NoteCoverStyles.swift`。
struct NoteCover: View {
    let title: String
    let body: String
    let tag: String
    let seed: Int

    init(title: String, body: String = "", tag: String, seed: Int) {
        self.title = title
        self.body = body
        self.tag = tag
        self.seed = seed
    }

    var pair: CoverPalette.Pair {
        CoverPalette.pairs[StableSeed.index(seed, count: CoverPalette.pairs.count)]
    }

    /// 清单版式要拿正文拆出几行短句。正文只有一句时拆不出来，
    /// 硬排会变成「标题 + 一行正文」的假清单，不如退回海报。
    var style: CoverStyle {
        let picked = CoverStyle.of(seed)
        if picked == .checklist, CoverText.sentences(body, limit: 3).count < 2 {
            return .poster
        }
        return picked
    }

    var body: some View {
        ZStack {
            backdrop
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: - 底色与纹理

    @ViewBuilder
    var backdrop: some View {
        switch style {
        case .poster:
            base
            Circle()
                .fill(pair.accent.opacity(0.16))
                .frame(width: 150, height: 150)
                .blur(radius: 18)
                .offset(x: 60, y: 70)
            CoverGrid(color: pair.ink.opacity(0.07))
        case .sticky:
            base
            CoverStripes(color: pair.ink.opacity(0.05))
        case .checklist:
            base
            CoverRules(color: pair.ink.opacity(0.08))
        case .magazine:
            base
            Rectangle()
                .fill(pair.accent.opacity(0.85))
                .frame(width: 3)
                .frame(maxHeight: .infinity, alignment: .leading)
        case .quote:
            base
            Circle()
                .stroke(pair.accent.opacity(0.18), lineWidth: 1)
                .frame(width: 190, height: 190)
                .offset(x: -40, y: 30)
        case .vertical:
            HStack(spacing: 0) {
                pair.accent.opacity(0.10)
                Color.clear
            }
            Rectangle()
                .fill(pair.ink.opacity(0.12))
                .frame(width: 0.5)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 30)
        case .ticket:
            base
            Circle()
                .fill(pair.ink.opacity(0.05))
                .frame(width: 120, height: 120)
                .offset(x: 50, y: -40)
        case .photo:
            photoBackdrop
        }
    }

    var base: some View {
        LinearGradient(
            colors: [pair.top, pair.bottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 照片质感：几团模糊色斑 + 底部压暗。
    ///
    /// 尺寸按容器算，双列卡和详情页大图共用一套，不会在详情页里缩成一个小圆。
    var photoBackdrop: some View {
        GeometryReader { proxy in
            let side = max(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(
                    colors: [pair.accent.opacity(0.92), pair.ink.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(.white.opacity(0.40))
                    .frame(width: side * 0.62, height: side * 0.62)
                    .blur(radius: side * 0.13)
                    .offset(x: -side * 0.22, y: -side * 0.24)

                Circle()
                    .fill(pair.top.opacity(0.75))
                    .frame(width: side * 0.5, height: side * 0.5)
                    .blur(radius: side * 0.15)
                    .offset(x: side * 0.26, y: -side * 0.06)

                Circle()
                    .fill(.black.opacity(0.25))
                    .frame(width: side * 0.7, height: side * 0.7)
                    .blur(radius: side * 0.16)
                    .offset(x: side * 0.06, y: side * 0.34)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.45)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
        }
    }

    @ViewBuilder
    var content: some View {
        switch style {
        case .poster: poster
        case .sticky: sticky
        case .checklist: checklist
        case .magazine: magazine
        case .quote: quote
        case .vertical: vertical
        case .ticket: ticket
        case .photo: photo
        }
    }
}
