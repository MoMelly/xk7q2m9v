import SwiftUI

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
