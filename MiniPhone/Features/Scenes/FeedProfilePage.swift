import SwiftUI
import UIKit

/// 西瓜皮里的「我」。
///
/// 真机的个人页从上往下是：封面、头像压边、名字与简介、三个数字、下面全是自己的笔记。
/// 这一页只放我发的东西——角色发的不在这里，那是他们的主页。
struct FeedProfilePage: View {
    let world: WorldStore
    let settings: SettingsStore
    var onCompose: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]

    @State private var backdropVariant = 0
    @State private var cover: UIImage?
    @State private var showEditor = false

    /// 名字、简介、头像都读「我」那份身份，不另存。
    private var profile: UserProfile? {
        profiles.first(where: { $0.isDefault }) ?? profiles.first
    }

    private var myNotes: [FeedNote] {
        world.state.feed
            .filter { $0.authorName == "我" }
            .sorted { $0.postedAt > $1.postedAt }
    }

    private var totalLikes: Int {
        myNotes.reduce(0) { $0 + $1.likes }
    }

    var body: some View {
        GeometryReader { proxy in
            // 背景图占内容区上半；ScrollView 顶到安全区外，
            // 配合 AppScreen 的透明导航栏，整块屏幕上半都是这张图。
            // 0.20 她实测偏矮（11-07：「再拉下来一丢丢」），提到约四分之一屏。
            let bannerHeight = max(170, proxy.size.height * 0.245)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    banner(height: bannerHeight)
                    identity
                    stats
                    grid
                }
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
            .ignoresSafeArea(edges: .top)
            .onAppear { cover = FeedProfileStore.loadCover() }
            .sheet(isPresented: $showEditor) {
                if let profile {
                    FeedIdentityEditor(profile: profile) {
                        cover = FeedProfileStore.loadCover()
                    }
                }
            }
        }
    }

    // MARK: - 头部

    private func banner(height: CGFloat) -> some View {
        ZStack(alignment: .bottomTrailing) {
            // 自己设的封面优先；没设才用内置渐变。
            if let cover {
                Image(uiImage: cover)
                    .resizable()
                    .scaledToFill()
                    .frame(width: nil, height: height)
                    .clipped()
            } else {
                ProfileBackdrop(variant: backdropVariant, height: height)
            }

            HStack(spacing: PhoneMetrics.Space.xs) {
                Text("我的主页")
                    .font(.system(size: PhoneMetrics.FontSize.caption, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.18)))

                Button {
                    showEditor = true
                } label: {
                    Label("编辑资料", systemImage: "pencil")
                        .font(.system(size: PhoneMetrics.FontSize.caption, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.black.opacity(0.18)))
                }
                .buttonStyle(.plain)
            }
            .padding(PhoneMetrics.Space.m)
        }
        .frame(height: height)
        .clipped()
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: PhoneMetrics.Space.xs) {
            HStack(alignment: .bottom, spacing: PhoneMetrics.Space.s) {
                avatarView
                    .offset(y: -33)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(AppSurface.light.label)
                        .lineLimit(1)

                    Text("西瓜号：xgpi_0001")
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                }
                .padding(.bottom, PhoneMetrics.Space.xs)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, PhoneMetrics.Space.m)

            Text(bioText)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                // 没写简介时用次色，一眼能分出「这是提示」还是「我写的话」。
                .foregroundStyle(
                    trimmedBio.isEmpty
                        ? AppSurface.light.secondaryLabel
                        : AppSurface.light.label
                )
                .padding(.horizontal, PhoneMetrics.Space.m)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var displayName: String {
        let name = (profile?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "我" : name
    }

    private var trimmedBio: String {
        (profile?.bio ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var bioText: String {
        trimmedBio.isEmpty ? "点上面「编辑资料」，写一句介绍。" : trimmedBio
    }

    private var avatarView: some View {
        ZStack {
            Circle().fill(Theme.Watermelon.pith)

            if let fileName = profile?.avatarFileName, !fileName.isEmpty,
               let image = AvatarPhoto.load(fileName: fileName) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let key = profile?.avatarImageKey, !key.isEmpty,
                      let image = UIImage(named: key) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                WatermelonMark(size: 38)
            }
        }
        .frame(width: 66, height: 66)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(AppSurface.light.rowSurface, lineWidth: 3))
    }

    private var stats: some View {
        HStack(spacing: PhoneMetrics.Space.l) {
            statItem(value: myNotes.count, label: "笔记")
            statItem(value: totalLikes, label: "获赞")
            statItem(value: 0, label: "关注")
            Spacer(minLength: 0)

            Button(action: onCompose) {
                Text("发笔记")
                    .font(.system(size: PhoneMetrics.FontSize.caption, weight: .medium))
                    .foregroundStyle(AppSurface.light.label)
                    .padding(.horizontal, PhoneMetrics.Space.s)
                    .frame(height: 28)
                    .background(
                        Capsule().strokeBorder(AppSurface.light.separator, lineWidth: 0.8)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.top, PhoneMetrics.Space.s)
    }

    private func statItem(value: Int, label: String) -> some View {
        HStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: PhoneMetrics.FontSize.sub, weight: .semibold))
                .foregroundStyle(AppSurface.light.label)
            Text(label)
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .foregroundStyle(AppSurface.light.secondaryLabel)
        }
    }

    // MARK: - 我的笔记

    @ViewBuilder
    private var grid: some View {
        RowDivider()
            .padding(.top, PhoneMetrics.Space.s)

        HStack(spacing: PhoneMetrics.Space.l) {
            Text("笔记")
                .font(.system(size: PhoneMetrics.FontSize.sub, weight: .semibold))
                .foregroundStyle(AppSurface.light.label)
            Text("收藏")
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(AppSurface.light.secondaryLabel)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.s)

        if myNotes.isEmpty {
            emptyState
        } else {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 2),
                    count: 3
                ),
                spacing: 2
            ) {
                ForEach(myNotes) { note in
                    NavigationLink {
                        FeedDetailPage(note: note, world: world, settings: settings)
                    } label: {
                        // Color.clear 撑出一个 4:5 的格子，封面填进去。
                        // 直接给 NoteCover 加 aspectRatio，它自己也是可伸缩视图，量不出高度。
                        Color.clear
                            .aspectRatio(0.80, contentMode: .fit)
                            .overlay {
                                NoteCover(
                                    title: note.title,
                                    body: note.body,
                                    tag: note.tag,
                                    seed: note.coverSeed
                                )
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

    private var emptyState: some View {
        VStack(spacing: PhoneMetrics.Space.xs) {
            WatermelonMark(size: 54)
                .opacity(0.55)

            Text("还没发过笔记")
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(AppSurface.light.label)

            Text("点下面中间那个红色按钮。")
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .foregroundStyle(AppSurface.light.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PhoneMetrics.Space.xl)
    }
}
