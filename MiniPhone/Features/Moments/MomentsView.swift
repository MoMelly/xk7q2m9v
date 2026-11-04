import SwiftUI
import SwiftData

/// 「照片」App 里的动态墙。
///
/// 生图要另外花钱，所以这里先只做文字动态：角色发一条状态，配一块由
/// 名字和内容派生的渐变缩略图。没有假图片，但也不是空壳。
struct MomentsView: View {
    let settings: SettingsStore
    var onExit: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\MomentPost.createdAt, order: .reverse)])
    private var posts: [MomentPost]
    @Query(sort: [SortDescriptor(\Companion.sortIndex)])
    private var characters: [Companion]

    @State private var isGenerating = false
    @State private var errorText: String?

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if posts.isEmpty {
                    emptyState
                    Spacer(minLength: 0)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(posts) { post in
                                card(post)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    }
                }

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 12).monospaced())
                        .foregroundStyle(Theme.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            GlassIconButton(symbol: "chevron.left", action: onExit)

            ScreenTitle(
                title: "动态",
                detail: posts.isEmpty ? "还没有人发东西" : "\(posts.count) 条"
            )

            Spacer(minLength: 0)

            GlassIconButton(symbol: "sparkles", isBusy: isGenerating) { generate() }
                .disabled(isGenerating || characters.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private func card(_ post: MomentPost) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                AvatarCircle(
                    initial: String(post.characterName.prefix(1)),
                    tint: tint(for: post),
                    size: 34
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(post.characterName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.cream)

                    Text(CharacterClock.listTimestamp(post.createdAt))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.cream.opacity(0.4))
                }

                Spacer(minLength: 0)
            }

            Text(post.text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.cream.opacity(0.92))
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(tintGradient(for: post))
                .frame(height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(8)
                }
        }
        .padding(14)
        .glassSurface(cornerRadius: 20)
        .contextMenu {
            Button(role: .destructive) {
                context.delete(post)
                try? context.save()
            } label: {
                Label("删除这条", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(characters.isEmpty ? "先建一个角色" : "让谁说点什么")
                .font(Theme.serif(20, weight: .medium))
                .foregroundStyle(Theme.cream)

            Text(characters.isEmpty
                 ? "动态是角色发的，得先有角色。去「信息」里新建一个。"
                 : "点右上角那颗星，它会按自己的人设发一条当前状态。每次都会花一点 API 额度，所以不自动发。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.mint.opacity(0.7))
                .lineSpacing(5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassSurface(cornerRadius: 20)
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    /// 作者如果还能对上号，就用角色自己的头像色，
    /// 保证同一个人在会话列表和动态里是同一个颜色。
    private func tint(for post: MomentPost) -> AvatarTint {
        characters.first { $0.uid == post.characterUID }?.avatarTint ?? .mint
    }

    private func tintGradient(for post: MomentPost) -> LinearGradient {
        let hue = Double(post.tintSeed % 360) / 360.0
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.45, brightness: 0.62),
                Color(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1.0), saturation: 0.55, brightness: 0.30)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - 生成

    private func generate() {
        guard !isGenerating, let character = characters.randomElement() else { return }
        guard settings.isConfigured else {
            errorText = "还没填 API Key。去桌面「设置」里填一个。"
            return
        }

        isGenerating = true
        errorText = nil

        Task {
            let system = PromptBuilder.momentPrompt(character: character)

            let client = OpenAICompatibleClient(config: settings.config)
            do {
                let text = try await client.complete([
                    ChatMessage(role: .system, text: "你只输出一段正文，不加任何解释。"),
                    ChatMessage(role: .user, text: system)
                ])
                let post = MomentPost(
                    characterUID: character.uid,
                    characterName: character.name,
                    text: text.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                context.insert(post)
                try? context.save()
            } catch {
                errorText = error.localizedDescription
            }
            isGenerating = false
        }
    }
}
