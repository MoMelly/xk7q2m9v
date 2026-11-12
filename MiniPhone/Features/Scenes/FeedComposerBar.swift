import SwiftUI

/// 私信与转帖共用的输入条。
///
/// 表情、快捷短语、＋号菜单都收在这一层，两个对话页不用各写一遍。
/// ＋号里的相册/位置/通话是文字模拟，跟主聊天的通话一样不接系统能力。
struct FeedComposerBar: View {
    @Binding var draft: String
    let isSending: Bool
    let onSend: () -> Void

    @State private var showEmoji = false
    @State private var tip: String?

    private let emojis = [
        "😀", "🥰", "😂", "😭", "😴", "🤔", "👍", "👏",
        "🎉", "🍉", "☕️", "🌙", "✨", "❤️", "🐱", "🌿",
        "🌸", "🍰", "🐻", "💤", "🙈", "🫶", "📷", "🎧"
    ]

    private let quickPhrases = ["在吗", "好呀", "哈哈哈", "晚点聊", "收到", "我看看"]

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 8
    )

    var body: some View {
        VStack(spacing: 0) {
            if showEmoji {
                emojiPanel
            }

            if let tip {
                Text(tip)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .padding(.vertical, 5)
            }

            inputRow
        }
        .background(AppSurface.light.background)
        // 这条输入条铺的是浅色底，外壳却是强制深色。
        // 不声明配色的话，输入框里的字和占位符都按深色算，白字压在浅底上等于看不见。
        .environment(\.colorScheme, AppSurface.light.colorScheme)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppSurface.light.separator.opacity(0.5))
                .frame(height: 0.5)
        }
        .onChange(of: tip) { _, value in
            guard value != nil else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                tip = nil
            }
        }
    }

    // MARK: - 输入行

    private var inputRow: some View {
        HStack(spacing: PhoneMetrics.Space.xs) {
            Button {
                showEmoji.toggle()
            } label: {
                Image(systemName: showEmoji ? "keyboard" : "face.smiling")
                    .font(.system(size: 16))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            moreMenu

            TextField("说点什么", text: $draft)
                .font(.system(size: PhoneMetrics.FontSize.body))
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Capsule().fill(AppSurface.light.rowSurface))
                .overlay(Capsule().strokeBorder(AppSurface.light.separator, lineWidth: 0.5))

            Button(action: onSend) {
                if isSending {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 30, height: 30)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.brand))
                }
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.xs)
    }

    private var moreMenu: some View {
        Menu {
            Button("相册") { showTip("相册还没接，先用文字说说是哪张照片吧。") }
            Button("拍照") { showTip("拍照是文字模拟，直接描述一下画面就行。") }
            Button("位置") { showTip("位置还没接，写个地名给我吧。") }
            Button("语音通话") { showTip("通话是文字模拟，去「信息 → 通话」能看记录。") }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppSurface.light.secondaryLabel)
                .frame(width: 30, height: 30)
                .background(Circle().fill(AppSurface.light.rowSurface))
        }
    }

    // MARK: - 表情与快捷短语

    private var emojiPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(quickPhrases, id: \.self) { phrase in
                        Button(phrase) {
                            draft += phrase
                        }
                        .font(.system(size: PhoneMetrics.FontSize.footnote))
                        .foregroundStyle(AppSurface.light.label)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Capsule().fill(AppSurface.light.rowSurface))
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(emoji) {
                        draft += emoji
                    }
                    .font(.system(size: 22))
                    .buttonStyle(.plain)
                    .frame(height: 32)
                }
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
        }
        .padding(.vertical, PhoneMetrics.Space.s)
    }

    private func showTip(_ text: String) {
        tip = text
    }
}
