import SwiftUI

/// 气泡长按后的那份菜单。
///
/// 两侧都能复制、引用、编辑、删除；撤回只给自己发出去的那条——
/// 撤回别人的话没有语义。已撤回的消息只剩删除这一项。
struct ChatMessageMenu: ViewModifier {
    let message: StoredMessage
    let canRecall: Bool
    var onCopy: () -> Void
    var onQuote: () -> Void
    var onEdit: () -> Void
    var onRecall: () -> Void
    var onDelete: () -> Void

    func body(content: Content) -> some View {
        content.contextMenu {
            if message.isRecalled {
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
            } else {
                Button(action: onCopy) {
                    Label("复制", systemImage: "doc.on.doc")
                }

                Button(action: onQuote) {
                    Label("引用", systemImage: "quote.opening")
                }

                Button(action: onEdit) {
                    Label("编辑", systemImage: "pencil")
                }

                if canRecall {
                    Button(role: .destructive, action: onRecall) {
                        Label("撤回", systemImage: "arrow.uturn.backward")
                    }
                }

                Divider()

                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }
}

extension View {
    /// 给一条气泡挂上长按菜单。动作由调用方实现，这里只管菜单长什么样。
    func chatMessageMenu(
        for message: StoredMessage,
        canRecall: Bool,
        onCopy: @escaping () -> Void,
        onQuote: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onRecall: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(
            ChatMessageMenu(
                message: message,
                canRecall: canRecall,
                onCopy: onCopy,
                onQuote: onQuote,
                onEdit: onEdit,
                onRecall: onRecall,
                onDelete: onDelete
            )
        )
    }
}

/// 还没有一句话时的引导卡。
struct ChatEmptyState: View {
    let isConfigured: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("还没说话")
                .font(Theme.serif(19, weight: .medium))
                .foregroundStyle(Theme.cream)

            Text(isConfigured
                 ? "直接打字就行。它会按自己的人设和作息回你。"
                 : "先去设置填一个 API Key，不然它没法回话。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.mint.opacity(0.7))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassSurface(cornerRadius: 18)
        .padding(.top, 8)
    }
}

/// 两条消息隔得久了才插一行时间。满屏时间戳比不插更糟。
struct ChatTimeSeparator: View {
    let date: Date

    var body: some View {
        Text(CharacterClock.separatorText(date))
            .font(.system(size: 10, weight: .medium))
            .tracking(0.6)
            .foregroundStyle(Theme.cream.opacity(0.36))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 2)
    }
}

/// 出错的提示卡。抽出来是因为 ChatView 已经贴着行数上限，
/// 这块和长按菜单同属「对话里的附属界面」。
struct ChatErrorCard: View {
    let text: String
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("出错了")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.warning)

                Spacer(minLength: 0)

                Button("知道了", action: onDismiss)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.mint.opacity(0.8))
                    .buttonStyle(.plain)
            }

            Text(text)
                .font(.system(size: 12).monospaced())
                .foregroundStyle(Theme.cream.opacity(0.9))
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.25))
        )
    }
}

/// 输入栏上方那条提示：正在引用谁，或者正在改哪一句。
///
/// 和输入栏同一套玻璃，贴在它上面不显得是另一层界面。
struct ChatContextBar: View {
    let symbol: String
    let title: String
    var detail: String = ""
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: PhoneMetrics.Space.xs) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.mint.opacity(0.85))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.cream.opacity(0.8))
                    .lineLimit(1)

                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.cream.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.cream.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassSurface(cornerRadius: 14)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}
