import SwiftUI

/// 私聊气泡流里的帖子小卡片。
///
/// 尺寸固定，不跟着气泡文字伸缩：小红书分享卡就是这样一张方方正正的预览，
/// 缩略图 + 标题 + 话题 + 两行正文，点进去还是那篇笔记。
struct FeedPostCardView: View {
    let payload: FeedPostCardPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: PhoneMetrics.Space.s) {
                FeedNoteThumb(title: payload.title, width: 44, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(payload.title)
                        .font(.system(size: PhoneMetrics.FontSize.sub, weight: .semibold))
                        .foregroundStyle(AppSurface.light.label)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if !payload.tag.isEmpty {
                        Text("#\(payload.tag)")
                            .font(.system(size: PhoneMetrics.FontSize.caption))
                            .foregroundStyle(Theme.brand)
                    }

                    Text("西瓜皮笔记")
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                }

                Spacer(minLength: 0)
            }
            .padding(PhoneMetrics.Space.s)

            if !payload.body.isEmpty {
                Rectangle()
                    .fill(AppSurface.light.separator.opacity(0.6))
                    .frame(height: 0.5)

                Text(payload.body)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(PhoneMetrics.Space.s)
            }
        }
        .frame(width: 236, alignment: .leading)
        .background(AppSurface.light.rowSurface)
        .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                .strokeBorder(AppSurface.light.separator.opacity(0.8), lineWidth: 0.6)
        }
    }
}
