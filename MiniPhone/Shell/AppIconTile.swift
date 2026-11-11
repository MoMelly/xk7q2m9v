import SwiftUI

/// 单个桌面图标。
///
/// 两种画法，由「设置 → 主题 → 图标样式」决定：
///
/// - `glass`：每个 App 自己的渐变底 + 顶部高光 + 细描边，是原来那套；
/// - 矢量版（白底 / 黑底 / 主题色底）：底色只有一层，图形统一走主题色，
///   整套桌面才像一套。矢量版不叠玻璃高光和斜反光——那两层在单色图形上
///   只会把颜色冲淡。
///
/// 外层 `.frame` 之后必须 `.clipShape`，否则子视图会把 ZStack 的测量尺寸撑出去。
struct AppIconTile: View {
    let app: PhoneApp
    var size: CGFloat = PhoneMetrics.iconSize
    var showsLabel: Bool = true
    /// 只在主题页的样式预览里用：让同一个图标同时显示四种画法。
    /// 正常桌面不传，跟着设置走。
    var styleOverride: IconStyle? = nil

    private var theme: ThemeStore { .shared }
    private var style: IconStyle { styleOverride ?? theme.iconStyle }
    private var cornerRadius: CGFloat { size * 0.224 }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        VStack(spacing: size * 0.1) {
            iconBody

            if showsLabel {
                Text(app.name)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    // 文字原来被压在图标那 60pt 的宽度里，四个字以上就开始截。
                    // 格子比图标宽一圈，名字也用上这一圈。
                    .frame(width: size * 1.12)
                    .shadow(color: labelShadow, radius: 2, y: 1)
            }
        }
    }

    /// 图标下的名字。自动档跟日夜走；她换深色壁纸时日间黑字全看不见，
    /// 所以给了手动白/黑档（设置 → 外观与壁纸 → 桌面文字颜色）。
    private var labelColor: Color {
        if let explicit = HomeTextInk.current.explicitColor { return explicit }
        return theme.isNight ? .white : Theme.IconSurface.labelDay
    }

    private var labelShadow: Color {
        if HomeTextInk.current.explicitColor != nil {
            return .black.opacity(0.45)
        }
        return theme.isNight ? .black.opacity(0.55) : .white.opacity(0.75)
    }

    // MARK: - 图标本体

    private var iconBody: some View {
        ZStack {
            backgroundLayer

            if style == .glass { glassGloss }

            glyph
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay { border }
        .shadow(color: shadowColor, radius: size * 0.08, y: size * 0.04)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch style {
        case .glass:
            shape.fill(
                LinearGradient(
                    colors: app.colors,
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

        case .light:
            shape.fill(
                LinearGradient(
                    colors: [Theme.IconSurface.lightTop, Theme.IconSurface.lightBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

        case .dark:
            shape.fill(
                LinearGradient(
                    colors: [Theme.IconSurface.darkTop, Theme.IconSurface.darkBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

        case .tinted:
            shape.fill(
                LinearGradient(
                    colors: [theme.accent, theme.accentDeep],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    /// 玻璃表面只留这一道从顶部打下来的高光。
    private var glassGloss: some View {
        shape.fill(
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.22), location: 0),
                    .init(color: .white.opacity(0.05), location: 0.42),
                    .init(color: .clear, location: 0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private var glyph: some View {
        // 按打开目标判断而不是 id：桌面那份是 `feed`，Dock 那份是 `dock.feed`，
        // 只认 id 会让两处同一个 App 画出两个不一样的图标。
        if app.destination == .scene(.feed) {
            WatermelonMark(
                // 她实测反馈图形顶满图标显得肥大，收到七成出头，
                // 底部留白跟其他 SF Symbol 图标的视觉占比对齐。
                size: size * 0.72,
                monochrome: style.isVector ? glyphColor : nil
            )
            .offset(y: size * 0.02)
            .shadow(color: .black.opacity(style.isVector ? 0 : 0.16), radius: size * 0.03, y: size * 0.015)
        } else {
            Image(systemName: app.symbol)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(glyphColor)
                .shadow(color: .black.opacity(style.isVector ? 0 : 0.2), radius: 1, y: 1)
        }
    }

    /// 图形颜色。白底压深、黑底提亮、主题色底用白——
    /// 三档都保证图形和底色之间有足够反差，不会糊在一起。
    private var glyphColor: Color {
        switch style {
        case .glass: return app.symbolTint
        case .light: return theme.accentDeep
        case .dark: return theme.accentLight
        case .tinted: return .white
        }
    }

    @ViewBuilder
    private var border: some View {
        switch style {
        case .glass:
            shape.strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.42), .white.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.8
            )

        case .light:
            shape.strokeBorder(Color.black.opacity(0.07), lineWidth: 0.6)

        case .dark:
            shape.strokeBorder(Color.white.opacity(0.13), lineWidth: 0.6)

        case .tinted:
            shape.strokeBorder(Color.white.opacity(0.2), lineWidth: 0.6)
        }
    }

    private var shadowColor: Color {
        style.isVector ? .black.opacity(0.12) : .black.opacity(0.2)
    }
}
