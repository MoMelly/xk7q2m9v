import SwiftUI

/// 置顶条。
///
/// 消息置顶之后在对话上方留一条摘要，点一下滚回那条消息。
/// 最多显示两条：再多就把对话顶下去了，这里不是列表页。
struct ChatPinnedBar: View {
    let messages: [StoredMessage]
    let myName: String

    var onTap: (StoredMessage) -> Void
    var onUnpin: (StoredMessage) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(messages, id: \.uid) { message in
                row(message)
            }
        }
        .background(Theme.cream.opacity(0.06))
    }

    private func row(_ message: StoredMessage) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "pin.fill")
                .font(.system(size: 8))
                .foregroundStyle(Theme.mint.opacity(0.9))

            Text(preview(message))
                .font(.system(size: 11))
                .foregroundStyle(Theme.cream.opacity(0.78))
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                Haptics.tap()
                onUnpin(message)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.cream.opacity(0.38))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { onTap(message) }
    }

    /// 群聊把说话人带出来，单聊只写「我 / 他」，两句就够认了。
    private func preview(_ message: StoredMessage) -> String {
        let who = message.role == .user ? myName : (message.speaker ?? "")
        let body = message.text.isEmpty ? "[图片]" : message.text
        return who.isEmpty ? body : "\(who)：\(body)"
    }
}
