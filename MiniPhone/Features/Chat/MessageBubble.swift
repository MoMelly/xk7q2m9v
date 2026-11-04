import SwiftUI

/// 一条聊天气泡。
///
/// 用户侧是实心薄荷绿，角色侧是玻璃——玻璃在深色底上才有层次，
/// 所以角色气泡不填色，只叠一层材质。旁白不套气泡，改成斜体灰字，
/// 因为「动作描写」和「说出来的话」在阅读上是两种东西。
struct MessageBubble: View {
    let text: String
    let isUser: Bool
    var speaker: String?
    var isNarration: Bool = false
    /// 流式中：末尾加一根跳动的竖线，表示还在往外吐字。
    var isStreaming: Bool = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
                if let speaker, !speaker.isEmpty, !isUser {
                    Text(speaker)
                        .font(.system(size: 10, weight: .medium))
                        .tracking(0.5)
                        .foregroundStyle(Theme.mint.opacity(0.65))
                        .padding(.leading, 4)
                }

                content
            }

            if !isUser { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isNarration {
            Text(text)
                .font(.system(size: 13))
                .italic()
                .foregroundStyle(Theme.cream.opacity(0.52))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        } else if isUser {
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

    private var label: Text {
        let base = Text(text.isEmpty ? "…" : text)
            .font(.system(size: 15))
            .lineSpacing(4)

        guard isStreaming else { return base }
        return base + Text("▍").foregroundColor(Theme.mint.opacity(0.8))
    }
}
