import SwiftUI

/// 分组里的一行。左侧彩色圆角图标、中间标题与副文、右侧值或 chevron。
///
/// 图标 29 × 29、圆角 7，是系统设置里那一排彩色小方块的近似尺寸；
/// 行高 44 / 58 也按系统来，之前整页都用 11pt 上下内边距，行会显得发胖。
struct GroupedRow: View {
    var symbol: String?
    var symbolTint: Color = Theme.tint
    var title: String
    var subtitle: String?
    var value: String?
    var showsChevron: Bool = false
    var surface: AppSurface = .light

    init(
        symbol: String? = nil,
        symbolTint: Color = Theme.tint,
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        showsChevron: Bool = false,
        surface: AppSurface = .light
    ) {
        self.symbol = symbol
        self.symbolTint = symbolTint
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.showsChevron = showsChevron
        self.surface = surface
    }

    var body: some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            if let symbol {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(symbolTint)
                    .frame(width: 29, height: 29)
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(surface.label)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: PhoneMetrics.FontSize.footnote))
                        .foregroundStyle(surface.secondaryLabel)
                }
            }

            Spacer(minLength: PhoneMetrics.Space.xs)

            if let value {
                Text(value)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(surface.secondaryLabel)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(surface.secondaryLabel.opacity(0.7))
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .frame(minHeight: subtitle == nil ? PhoneMetrics.Row.single : PhoneMetrics.Row.detailed)
        .contentShape(Rectangle())
    }
}

/// 行内分隔线。左端从文字起始位置缩进，和系统设置一致。
struct RowDivider: View {
    var surface: AppSurface = .light

    var body: some View {
        Rectangle()
            .fill(surface.separator.opacity(0.55))
            .frame(height: 0.5)
            .padding(.leading, PhoneMetrics.Space.m)
    }
}
