import SwiftUI

/// 一条聊天气泡。
///
/// 用户侧是实心复古绿，助手侧是玻璃——玻璃在深色底上才有层次，
/// 所以助手气泡不填色，只叠一层材质。
struct MessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 44) }
            bubble
            if !isUser { Spacer(minLength: 44) }
        }
    }

    @ViewBuilder
    private var bubble: some View {
        let label = Text(message.text.isEmpty ? "…" : message.text)
            .font(.system(size: 15))
            .lineSpacing(4)

        if isUser {
            label
                .foregroundStyle(Theme.deepGreen)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.mint)
                )
        } else {
            label
                .foregroundStyle(Theme.cream)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassSurface(cornerRadius: 18)
        }
    }
}
