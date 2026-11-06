import SwiftUI

/// 一条聊天气泡。
///
/// 用户侧是实心薄荷绿，角色侧是玻璃——玻璃在深色底上才有层次，
/// 所以角色气泡不填色，只叠一层材质。旁白不套气泡，改成斜体灰字，
/// 因为「动作描写」和「说出来的话」在阅读上是两种东西。
struct MessageBubble: View {
    let text: String
    let isUser: Bool
    /// 群聊里这句话的说话人。必须显式写 `= nil`：memberwise 初始化器
    /// 不会给 Optional 属性补默认值，漏了会导致不传该参数的调用点编译失败。
    var speaker: String? = nil
    var isNarration: Bool = false
    /// 流式中：末尾加一根跳动的竖线，表示还在往外吐字。
    var isStreaming: Bool = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                if let speaker, !speaker.isEmpty, !isUser {
                    Text(speaker)
                        .font(.system(size: 10, weight: .medium))
                        .tracking(0.5)
                        .foregroundStyle(Theme.mint.opacity(0.65))
                        .padding(.leading, 4)
                }

                stickerStack
            }

            if !isUser { Spacer(minLength: 40) }
        }
    }

    // MARK: - 表情

    /// 流式时不解析：半个 `[表情:` 会闪一下再消失，看着像乱码。
    private var parsed: (body: String, names: [String]) {
        isStreaming ? (text, []) : StickerTextParser.parse(text)
    }

    private var stickerStack: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
            if !parsed.body.isEmpty {
                textBubble
            }

            ForEach(Array(parsed.names.enumerated()), id: \.offset) { _, name in
                Group {
                    if let item = StickerLibrary.shared.item(named: name) {
                        StickerView(item: item, size: 112)
                    } else {
                        Text("[\(name)]")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.cream.opacity(0.5))
                    }
                }
            }
        }
    }

    /// 解析后的正文。没表情时 `parsed.body` 就是原文。
    private var textBubble: some View {
        bubble(parsed.body)
    }

    @ViewBuilder
    private func bubble(_ body: String) -> some View {
        if isNarration {
            Text(body)
                .font(.system(size: 13))
                .italic()
                .foregroundStyle(Theme.cream.opacity(0.52))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
        } else if isUser {
            label(body)
                .foregroundStyle(Theme.deepGreen)
                .lineSpacing(4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.mint)
                )
        } else {
            label(body)
                .foregroundStyle(Theme.cream)
                .lineSpacing(4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassSurface(cornerRadius: 18)
        }
    }

    /// 返回 `Text` 而不是 `some View`：流式光标要用 `+` 拼在正文后面，
    /// 而 `+` 只存在于 `Text` 之间。所以行距不能写在这里——`lineSpacing`
    /// 是 `View` 的修饰符，一加就把类型变成 `some View`，`+` 立刻失效。
    /// 行距放在两个调用点上。
    private func label(_ body: String) -> Text {
        let base = Text(body.isEmpty ? "…" : body)
            .font(.system(size: 15))

        guard isStreaming else { return base }
        return base + Text("▍").foregroundColor(Theme.mint.opacity(0.8))
    }
}
