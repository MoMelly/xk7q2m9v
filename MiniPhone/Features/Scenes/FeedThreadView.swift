import SwiftUI
import SwiftData

/// 私信与转帖共用的对话层。
///
/// 两个页面各自包一层，但气泡和输入是同一份：消息都落在
/// `Companion.messages`，按 threadID 取出来，记忆仍是角色那一份。
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
                    ForEach(messages) { message in
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

            inputBar
        }
        // push 进来的页面默认是纯白，白气泡会隐形；显式铺回浅灰页底。
        .background(AppSurface.light.background)
    }

    private func bubble(_ message: StoredMessage) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.role == .user { Spacer(minLength: 48) }

            Text(message.text)
                .font(.system(size: PhoneMetrics.FontSize.body))
                .foregroundStyle(message.role == .user ? .white : AppSurface.light.label)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                        .fill(message.role == .user ? Theme.brand : AppSurface.light.rowSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                        .strokeBorder(
                            message.role == .user ? .clear : AppSurface.light.separator.opacity(0.7),
                            lineWidth: 0.6
                        )
                )

            if message.role != .user { Spacer(minLength: 48) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: PhoneMetrics.Space.xs) {
            TextField("说点什么", text: $draft)
                .font(.system(size: PhoneMetrics.FontSize.body))
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(
                    Capsule().fill(AppSurface.light.rowSurface)
                )
                .overlay(
                    Capsule().strokeBorder(AppSurface.light.separator, lineWidth: 0.5)
                )

            Button(action: send) {
                if service.isReplying(item) {
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
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isReplying(item))
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.xs)
        .background(AppSurface.light.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppSurface.light.separator.opacity(0.5))
                .frame(height: 0.5)
        }
    }

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
