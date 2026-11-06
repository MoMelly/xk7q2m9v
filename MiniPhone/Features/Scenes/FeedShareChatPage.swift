import SwiftUI

/// 一条转帖的对话页。
///
/// 帖子以小卡片落在气泡流里，不再挂在页面顶端当一条列表行：
/// 和「我分享给别人」看到的是同一种卡片，但这里仍是独立的转帖通道，
/// 私聊页不放转发入口，转帖页也不塞私信的功能。
struct FeedShareChatPage: View {
    let item: FeedInboxItem
    let character: Companion
    let settings: SettingsStore

    var body: some View {
        FeedThreadView(item: item, character: character, settings: settings)
            .navigationTitle("转给我的帖子")
            .navigationBarTitleDisplayMode(.inline)
            .background(AppSurface.light.background)
    }
}
