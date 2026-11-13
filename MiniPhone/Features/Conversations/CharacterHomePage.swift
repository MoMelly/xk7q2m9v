import SwiftUI
import SwiftData

/// 角色主页。
///
/// 结构上按朋友圈来：一张封面、头像压在下沿、签名和标签在名字下面，
/// 下面是这个人自己发过的东西。QQ 那边借的是「签名 + 标签 + 状态」这一排——
/// 光有朋友圈会像一张资料卡，加上这排才像个人主页。
struct CharacterHomePage: View {
    let character: Companion
    let world: WorldStore

    @Query private var posts: [MomentPost]

    init(character: Companion, world: WorldStore) {
        self.character = character
        self.world = world
        let uid = character.uid
        _posts = Query(
            filter: #Predicate<MomentPost> { $0.characterUID == uid },
            sort: [SortDescriptor(\MomentPost.createdAt, order: .reverse)]
        )
    }

    private var person: PersonMemory? {
        world.state.person(named: character.name)
    }

    /// 相处天数从「这个身份」的第一条消息算起。
    ///
    /// `character.messages` 是所有身份混在一起的；换身份之后不能把别人
    /// 攒下的天数带过来，没聊过就是第 1 天。
    private var knownDays: Int {
        let start = character.knownSince
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: start),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0
        return max(days, 0) + 1
    }

    var body: some View {
        AppPage(title: character.name) {
            ScrollView {
                VStack(spacing: 0) {
                    coverHeader
                    profileBar
                    wall
                }
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    // MARK: - 封面

    private var coverHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: character.avatarTint.colors.map { $0.opacity(0.85) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 148)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(.white.opacity(0.07))
                    .offset(x: 16, y: -10)
            }

            AvatarBubble(character: character, size: 64)
                .overlay {
                    Circle().strokeBorder(Theme.rowSurface, lineWidth: 3)
                }
                .padding(.leading, PhoneMetrics.Space.m)
                .offset(y: 26)
        }
    }

    // MARK: - 身份

    private var profileBar: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: PhoneMetrics.Space.xs) {
                Text(character.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.label)

                Text(character.preset.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.secondaryLabel)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.separator.opacity(0.22)))

                Spacer(minLength: 0)
            }

            if !character.signature.isEmpty {
                Text(character.signature)
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(Theme.label.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !character.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(character.tags.prefix(5), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.tint)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Theme.tint.opacity(0.12)))
                    }
                    Spacer(minLength: 0)
                }
            }

            HStack(spacing: PhoneMetrics.Space.m) {
                stat("相处", "\(knownDays) 天")
                stat("说过", "\(character.totalReplies) 次")
                if let person, !person.facts.isEmpty {
                    stat("记得", "\(person.facts.count) 件事")
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 3)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.top, 36)
        .padding(.bottom, PhoneMetrics.Space.m)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(value)
                .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .semibold))
                .foregroundStyle(Theme.label)
            Text(label)
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .foregroundStyle(Theme.secondaryLabel)
        }
    }

    // MARK: - 动态

    private var wall: some View {
        VStack(spacing: 0) {
            RowDivider()

            if posts.isEmpty {
                VStack(spacing: PhoneMetrics.Space.xs) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(Theme.secondaryLabel.opacity(0.7))
                    Text("还没发过动态")
                        .font(.system(size: PhoneMetrics.FontSize.footnote))
                        .foregroundStyle(Theme.secondaryLabel)
                    Text("聊到值得发的时刻，它会自己发一条")
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(Theme.secondaryLabel.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 56)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(posts) { post in
                        postRow(post)
                        RowDivider()
                    }
                }
            }
        }
    }

    private func postRow(_ post: MomentPost) -> some View {
        HStack(alignment: .top, spacing: PhoneMetrics.Space.s) {
            AvatarBubble(character: character, size: 36)

            VStack(alignment: .leading, spacing: 5) {
                Text(character.name)
                    .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .semibold))
                    .foregroundStyle(Theme.tint)

                Text(post.text)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(Theme.label)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: PhoneMetrics.Space.m) {
                    Text(TimeFormat.callTime(post.createdAt))
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(Theme.secondaryLabel)

                    Label("赞", systemImage: "heart")
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(Theme.secondaryLabel)

                    Label("评论", systemImage: "bubble.left")
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(Theme.secondaryLabel)
                }
                .padding(.top, 1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.m)
    }
}
