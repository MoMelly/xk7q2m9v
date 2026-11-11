import SwiftUI
import SwiftData

/// 笔记详情。
///
/// 结构照西瓜皮：大封面、标题、正文、话题、作者，下面一列评论。
/// 用户自己发的笔记也走这一页，可以在底下补一句。
struct FeedDetailPage: View {
    let note: FeedNote
    let world: WorldStore
    let settings: SettingsStore

    @State private var draft = ""
    @FocusState private var isFocused: Bool
    @Environment(\.modelContext) private var context
    @State private var showSharePicker = false
    /// 分享完把 thread 交回外层，外层负责切到消息 tab 并打开对话。
    var onShared: ((UUID) -> Void)? = nil

    private var current: FeedNote {
        // 评论可能在这一页打开之后被刷新补进来，所以每次从库里取最新的。
        world.state.feed.first { $0.id == note.id } ?? note
    }

    var body: some View {
        AppPage(title: "笔记", surface: .light) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        NoteCover(
                            title: current.title,
                            body: current.body,
                            tag: current.tag,
                            seed: current.coverSeed
                        )
                        .frame(height: 240)
                            .clipShape(
                                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                            )
                            .padding(.horizontal, PhoneMetrics.Space.m)
                            .padding(.top, PhoneMetrics.Space.xs)

                        authorRow
                        bodyText
                        shareButton
                        commentSection
                    }
                    .padding(.bottom, PhoneMetrics.Space.xl)
                }

                composer
            }
        }
        .sheet(isPresented: $showSharePicker) {
            FeedSharePicker { character in
                shareNote(to: character)
            }
        }
    }

    private var authorRow: some View {
        HStack(spacing: PhoneMetrics.Space.xs) {
            FeedAvatar(
                name: current.authorName,
                isCharacter: current.authorUID != nil,
                size: 26
            )

            Text(current.authorName)
                .font(.system(size: PhoneMetrics.FontSize.sub, weight: .medium))
                .foregroundStyle(AppSurface.light.label)

            Spacer(minLength: 0)

            NavigationLink {
                FeedAuthorPage(
                    authorName: current.authorName,
                    authorUID: current.authorUID,
                    world: world,
                    settings: settings
                )
            } label: {
                Text("主页")
                    .font(.system(size: PhoneMetrics.FontSize.caption, weight: .medium))
                    .foregroundStyle(Theme.brand)
            }
            .buttonStyle(.plain)

            Image(systemName: "heart")
                .font(.system(size: 13))
            Text("\(current.likes)")
                .font(.system(size: PhoneMetrics.FontSize.footnote))
        }
        .foregroundStyle(AppSurface.light.secondaryLabel)
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.s)
    }

    private var bodyText: some View {
        VStack(alignment: .leading, spacing: PhoneMetrics.Space.s) {
            Text(current.title)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppSurface.light.label)
                .fixedSize(horizontal: false, vertical: true)

            if !current.body.isEmpty {
                Text(current.body)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(AppSurface.light.label)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !current.tag.isEmpty {
                Text("#\(current.tag)")
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(Theme.link)
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.bottom, PhoneMetrics.Space.l)
    }

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            RowDivider()

            Text(current.comments.isEmpty ? "还没有评论" : "\(current.comments.count) 条评论")
                .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .medium))
                .foregroundStyle(AppSurface.light.secondaryLabel)
                .padding(.horizontal, PhoneMetrics.Space.m)
                .padding(.vertical, PhoneMetrics.Space.s)

            ForEach(current.comments) { comment in
                // 角色说的评论点了能进他的主页——评论区里看到一个人，
                // 下一步一定想知道这人是谁。
                if comment.isCharacter {
                    NavigationLink {
                        FeedAuthorPage(
                            authorName: comment.authorName,
                            authorUID: nil,
                            world: world,
                            settings: settings
                        )
                    } label: {
                        commentRow(comment)
                    }
                    .buttonStyle(.plain)
                } else {
                    commentRow(comment)
                }
            }
        }
    }

    private func commentRow(_ comment: NoteComment) -> some View {
        HStack(alignment: .top, spacing: PhoneMetrics.Space.xs) {
            FeedAvatar(
                name: comment.authorName,
                isCharacter: comment.isCharacter,
                size: 22
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(comment.authorName)
                        .font(.system(size: PhoneMetrics.FontSize.caption, weight: .medium))
                        .foregroundStyle(AppSurface.light.secondaryLabel)

                    if comment.isCharacter {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(AppSurface.light.secondaryLabel.opacity(0.5))
                    }
                }

                Text(comment.text)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(AppSurface.light.label)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.xs)
        .contentShape(Rectangle())
    }

    private var shareButton: some View {
        // 全宽一大条太抢戏，收成右端一枚小胶囊，只是个轻量入口。
        HStack {
            Spacer(minLength: 0)
            Button {
                showSharePicker = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11, weight: .medium))
                    Text("分享到私聊")
                        .font(.system(size: PhoneMetrics.FontSize.caption, weight: .medium))
                }
                .foregroundStyle(Theme.brand)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(Theme.brand.opacity(0.09))
                )
                .overlay {
                    Capsule().strokeBorder(Theme.brand.opacity(0.22), lineWidth: 0.6)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.bottom, PhoneMetrics.Space.s)
    }

    /// 卡片只写进那条私信的消息流，不新开转帖通道、也不写角色活动索引。
    private func shareNote(to companion: Companion) {
        let item = world.openFeedThread(
            companionUID: companion.uid.uuidString,
            companionName: companion.name
        )
        let payload = FeedPostCardPayload(
            noteID: current.id.uuidString,
            title: current.title,
            body: current.body,
            tag: current.tag,
            coverSeed: current.coverSeed
        )
        let message = StoredMessage(
            characterUID: companion.uid,
            role: .user,
            text: payload.encoded(),
            channel: .feedDM,
            threadID: item.threadID
        )
        message.character = companion
        context.insert(message)
        world.updateFeedThreadPreview(
            threadID: item.threadID,
            message: "分享了一篇帖子：《\(current.title)》"
        )
        onShared?(item.threadID)
    }

    private var composer: some View {
        HStack(spacing: PhoneMetrics.Space.xs) {
            TextField("说点什么", text: $draft)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(AppSurface.light.label)
                .focused($isFocused)
                .padding(.horizontal, PhoneMetrics.Space.s)
                .frame(height: 34)
                .background(Capsule().fill(AppSurface.light.rowSurface))
                .overlay(Capsule().strokeBorder(AppSurface.light.separator, lineWidth: 0.5))

            Button("发送", action: send)
                .font(.system(size: PhoneMetrics.FontSize.sub, weight: .semibold))
                .foregroundStyle(draft.isEmpty ? AppSurface.light.secondaryLabel : AppSurface.light.tint)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.xs)
        .background(AppSurface.light.background)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        world.addComment(noteID: note.id, text: text)
        draft = ""
        isFocused = false

        // 我评论完之后要有人接。作者回我，在场的人也会互相接话。
        Task { await FeedCommentService.reply(to: note.id, settings: settings) }
    }
}

/// 发一条自己的笔记。
struct NoteComposer: View {
    let world: WorldStore
    var onClose: () -> Void

    @State private var title = ""
    @State private var composeBody = ""
    @State private var tag = ""

    private var canPost: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: PhoneMetrics.Space.m) {
                TextField("标题", text: $title, axis: .vertical)
                    .font(.system(size: 19, weight: .semibold))
                    .lineLimit(1...2)

                TextField("正文，随便写点", text: $composeBody, axis: .vertical)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .lineLimit(4...10)

                HStack(spacing: 4) {
                    Text("#")
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                    TextField("话题", text: $tag)
                        .font(.system(size: PhoneMetrics.FontSize.sub))
                }
                .padding(.horizontal, PhoneMetrics.Space.s)
                .frame(height: 34)
                .background(Capsule().fill(AppSurface.light.rowSurface))

                Spacer(minLength: 0)

                Text("发出去之后，角色过一阵可能会来评论。")
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
            }
            .padding(PhoneMetrics.Space.m)
            .background(AppSurface.light.background.ignoresSafeArea())
            .navigationTitle("发笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发布") {
                        world.publishNote(title: title, body: composeBody, tag: tag)
                        onClose()
                    }
                    .disabled(!canPost)
                }
            }
        }
        .environment(\.colorScheme, .light)
    }
}
