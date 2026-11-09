import SwiftUI
import SwiftData

/// 笔记作者的主页。
///
/// 角色作者直接复用已有的 Companion；路人作者在这里现建一个 isFeedOnly 的，
/// 同样进这套消息与记忆，只是不出现在「信息」的会话列表里。
struct FeedAuthorPage: View {
    let authorName: String
    let authorUID: String?
    let world: WorldStore
    let settings: SettingsStore

    @Environment(\.modelContext) private var context
    @Query private var companions: [Companion]
    @State private var openedItem: FeedInboxItem?
    /// 刚建的路人作者：@Query 刷新可能比页面跳转慢一步，这里留一份引用兜底。
    @State private var localCompanion: Companion?

    private var notes: [FeedNote] {
        world.state.feed
            .filter { $0.authorName == authorName }
            .sorted { $0.postedAt > $1.postedAt }
    }

    private var character: Companion? {
        guard let authorUID else { return nil }
        return companions.first { $0.uid.uuidString == authorUID }
    }

    private var signatureText: String {
        let signature = character?.signature ?? ""
        return signature.isEmpty ? "西瓜皮上的作者" : signature
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                profile
                dividerAndNotes
            }
            .padding(.bottom, PhoneMetrics.Space.xl)
        }
        .navigationTitle(authorName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $openedItem) { item in
            let target = companions.first(where: { $0.uid.uuidString == item.companionUID })
                ?? localCompanion
            if let target {
                FeedChatPage(item: item, character: target, settings: settings)
            } else {
                Text("这个人的资料不在了")
                    .foregroundStyle(AppSurface.light.secondaryLabel)
            }
        }
    }

    private var profile: some View {
        VStack(alignment: .leading, spacing: PhoneMetrics.Space.s) {
            HStack(spacing: PhoneMetrics.Space.s) {
                FeedAvatar(name: authorName, isCharacter: true, size: 62)
                VStack(alignment: .leading, spacing: 4) {
                    Text(authorName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppSurface.light.label)
                    Text(signatureText)
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            Button {
                openedItem = world.openFeedThread(
                    companionUID: resolveUID(),
                    companionName: authorName
                )
            } label: {
                Text("发私信")
                    .font(.system(size: PhoneMetrics.FontSize.sub, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(Capsule().fill(Theme.brand))
            }
            .buttonStyle(.plain)
        }
        .padding(PhoneMetrics.Space.m)
    }

    private var dividerAndNotes: some View {
        VStack(alignment: .leading, spacing: 0) {
            RowDivider()
            Text("\(notes.count) 篇笔记")
                .font(.system(size: PhoneMetrics.FontSize.sub, weight: .semibold))
                .foregroundStyle(AppSurface.light.label)
                .padding(PhoneMetrics.Space.m)

            if notes.isEmpty {
                Text("还没发过笔记")
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, PhoneMetrics.Space.xl)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3),
                    spacing: 2
                ) {
                    ForEach(notes) { note in
                        NavigationLink {
                            FeedDetailPage(note: note, world: world, settings: settings)
                        } label: {
                            Color.clear
                                .aspectRatio(0.80, contentMode: .fit)
                                .overlay {
                                    FeedCover(note: note)
                                }
                                .clipShape(
                                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.cover, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, PhoneMetrics.Space.xxs)
            }
        }
    }

    /// 路人作者没有 Companion，点「发私信」时才建一个，不污染桌面会话列表。
    private func resolveUID() -> String {
        if let authorUID,
           let found = companions.first(where: { $0.uid.uuidString == authorUID }) {
            return found.uid.uuidString
        }
        let proxy = Companion(
            name: authorName,
            persona: "西瓜皮上认识的作者，说话随意些。",
            greeting: ""
        )
        proxy.isFeedOnly = true
        context.insert(proxy)
        try? context.save()
        localCompanion = proxy
        return proxy.uid.uuidString
    }
}
