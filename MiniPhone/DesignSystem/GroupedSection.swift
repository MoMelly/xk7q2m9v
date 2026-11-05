import SwiftUI

/// 系统设置那种整宽分组。
///
/// 圆角 10、不投影、行内分隔线由行自己画。之前每个分组是一张带阴影的独立
/// 卡片、分组标题飘在卡外，看起来像网页表单，不是 iOS 设置。
struct GroupedSection<Content: View>: View {
    var title: String?
    var footer: String?
    var surface: AppSurface
    let content: Content

    init(
        _ title: String? = nil,
        footer: String? = nil,
        surface: AppSurface = .light,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.surface = surface
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PhoneMetrics.Space.xs) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(surface.secondaryLabel)
                    .padding(.horizontal, PhoneMetrics.Space.m)
            }

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.grouped, style: .continuous)
                    .fill(surface.rowSurface)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.grouped, style: .continuous)
            )

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
