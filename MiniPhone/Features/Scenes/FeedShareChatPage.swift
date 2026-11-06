import SwiftUI

/// 一条转帖的对话页。
///
/// 顶部固定那篇帖子的卡片，模型也能看到它的标题正文和话题，
/// 所以这一页的对话始终围着帖子走，不会被当成普通闲聊。
struct FeedShareChatPage: View {
    let item: FeedInboxItem
    let character: Companion
    let settings: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            postCard
            FeedThreadView(item: item, character: character, settings: settings)
        }
        .navigationTitle("转给我的帖子")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var postCard: some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            NoteCover(
                title: item.noteTitle,
                body: item.noteBody,
                tag: item.noteTag,
                seed: item.coverSeed
            )
            .frame(width: 54, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.block, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.noteTitle)
                    .font(.system(size: PhoneMetrics.FontSize.sub, weight: .semibold))
                    .foregroundStyle(AppSurface.light.label)
                    .lineLimit(2)
                Text("#\(item.noteTag)")
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(Theme.brand)
                Text("\(item.companionName) 转给你")
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
            }

            Spacer(minLength: 0)
        }
        .padding(PhoneMetrics.Space.s)
        .background(AppSurface.light.rowSurface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppSurface.light.separator.opacity(0.5))
                .frame(height: 0.5)
        }
    }
}
