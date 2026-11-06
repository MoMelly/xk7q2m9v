import SwiftUI
import SwiftData

/// 私信与转帖共用的对话层。
///
/// 两个页面各自包一层，但气泡和输入是同一份：消息都落在
/// `Companion.messages`，按 threadID 取出来，记忆仍是角色那一份。
/// 帖子小卡片也走这条消息流，只是渲染时认前缀换成卡片视图。
struct FeedThreadView: View {
    let item: FeedInboxItem
    let character: Companion
    let settings: SettingsStore

    @Environment(\.modelContext) private var context
    @Query private var messages: [StoredMessage]
    @State private var draft = ""
    @State private var errorText: String?

    private var service: FeedChatService { .shared }

    init(item: FeedInboxItem, character: Companion, settings: SettingsStore) {
        self.item = item
        self.character = character
        self.settings = settings
        let thread = item.threadID.uuidString
        _messages = Query(
            filter: #Predicate<StoredMessage> { $0.threadRaw == thread },
            sort: [SortDescriptor(\StoredMessage.createdAt, order: .forward)]
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                        if shouldShowTime(at: index) {
                            timeLabel(message.createdAt)
                        }
                        bubble(message)
                    }
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .padding(.vertical, PhoneMetrics.Space.s)
            }

            if let errorText {
                Text(errorText)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(Theme.brand)
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .padding(.bottom, 4)
            }

            FeedComposerBar(
                draft: $draft,
                isSending: service.isReplying(item),
                onSend: send
            )
        }
        // push 进来的页面默认是纯白，白气泡会隐形；显式铺回浅灰页底。
        .background(AppSurface.light.background)
    }

    // MARK: - 消息

    private func shouldShowTime(at index: Int) -> Bool {
        guard index > 0 else { return true }
        return messages[index].createdAt.timeIntervalSince(messages[index - 1].createdAt) > 300
    }

    private func timeLabel(_ date: Date) -> some View {
        Text(TimeFormat.monthDayTime(date))
            .font(.system(size: PhoneMetrics.FontSize.caption))
            .foregroundStyle(AppSurface.light.secondaryLabel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
    }

    @ViewBuilder
    private func bubble(_ message: StoredMessage) -> some View {
        let isUser = message.role == .user

        HStack(alignment: .bottom, spacing: 6) {
            if isUser {
                Spacer(minLength: 32)
            } else {
                FeedDefaultAvatarView(name: character.name, size: 28)
            }

            if let card = FeedPostCardPayload.decode(message.text) {
                FeedPostCardView(payload: card)
            } else {
                textBubble(message.text, isUser: isUser)
            }

            if isUser {
                myAvatar
            } else {
                Spacer(minLength: 32)
            }
        }
    }

    private func textBubble(_ text: String, isUser: Bool) -> some View {
        Text(text)
            .font(.system(size: PhoneMetrics.FontSize.body))
            .foregroundStyle(isUser ? .white : AppSurface.light.label)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                    .fill(isUser ? Theme.brand : AppSurface.light.rowSurface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                    .strokeBorder(
                        isUser ? .clear : AppSurface.light.separator.opacity(0.7),
                        lineWidth: 0.6
                    )
            }
            .overlay(alignment: isUser ? .bottomTrailing : .bottomLeading) {
                BubbleTail(isUser: isUser)
                    .fill(isUser ? Theme.brand : AppSurface.light.rowSurface)
                    .frame(width: 8, height: 10)
                    .offset(x: isUser ? 5 : -5, y: 1)
            }
    }

    private var myAvatar: some View {
        ZStack {
            Circle().fill(Theme.retroGreen.opacity(0.9))
            Text("我")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 28, height: 28)
    }

    // MARK: - 发送

    private func send() {
        let text = draft
        draft = ""
        errorText = nil
        let channel: MessageChannel = item.kind == .postShare ? .feedShare : .feedDM
        Task { @MainActor in
            let userMessage = StoredMessage(
                characterUID: character.uid,
                role: .user,
                text: text,
                channel: channel,
                threadID: item.threadID
            )
            userMessage.character = character
            context.insert(userMessage)
            try? context.save()

            let userName = UserProfileBook.resolve(uid: character.personaUID, in: context)?.name
            switch await service.generateReply(
                to: item,
                character: character,
                settings: settings,
                userName: userName
            ) {
            case .success(let reply):
                let assistant = StoredMessage(
                    characterUID: character.uid,
                    role: .assistant,
                    text: reply,
                    channel: channel,
                    threadID: item.threadID
                )
                assistant.character = character
                context.insert(assistant)
                try? context.save()
            case .failure(let message):
                errorText = message
            }
        }
    }
}

/// 气泡靠头像那一侧的小尖角。左右各一个方向，不用旋转整块视图。
private struct BubbleTail: Shape {
    var isUser: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if isUser {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }
        path.closeSubpath()
        return path
    }
}
