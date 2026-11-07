import SwiftUI

/// 系统设置那种整宽分组。
///
/// 圆角 10、不投影、行内分隔线由行自己画。之前每个分组是一张带阴影的独立
/// 卡片、分组标题飘在卡外，看起来像网页表单，不是 iOS 设置。
///
/// `glass = true` 时分组底不走 `rowSurface` 实色，改用液态玻璃，
/// 底下的背景能透上来。给深色渐变页面用的——那里再铺白卡片就是两截。
struct GroupedSection<Content: View>: View {
    var title: String?
    var footer: String?
    var surface: AppSurface
    var glass: Bool
    let content: Content

    init(
        _ title: String? = nil,
        footer: String? = nil,
        surface: AppSurface = .light,
        glass: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.surface = surface
        self.glass = glass
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: PhoneMetrics.Radius.grouped,
            style: .continuous
        )

        return VStack(alignment: .leading, spacing: PhoneMetrics.Space.xs) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(surface.secondaryLabel)
                    .padding(.horizontal, PhoneMetrics.Space.m)
            }

            Group {
                if glass {
                    VStack(spacing: 0) { content }
                        .glassSurface(cornerRadius: PhoneMetrics.Radius.grouped)
                } else {
                    VStack(spacing: 0) { content }
                        .background(shape.fill(surface.rowSurface))
                }
            }
            .clipShape(shape)

            if let footer {
                Text(footer)
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(surface.secondaryLabel)
                    .lineSpacing(3)
                    .padding(.horizontal, PhoneMetrics.Space.m)
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
    }
}
