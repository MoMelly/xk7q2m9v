import SwiftUI

/// 一条私信的对话页。只有对话，没有转发、没有帖子卡片——
/// 那属于另一条通道，不在私聊界面里再发起什么。
struct FeedChatPage: View {
    let item: FeedInboxItem
    let character: Companion
    let settings: SettingsStore

    var body: some View {
        FeedThreadView(item: item, character: character, settings: settings)
            .navigationTitle(character.name)
            .navigationBarTitleDisplayMode(.inline)
    }
}
