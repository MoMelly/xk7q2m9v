import SwiftUI

/// 西瓜皮里的「我」。
///
/// 真机的个人页从上往下是：封面、头像压边、名字与简介、三个数字、下面全是自己的笔记。
/// 这一页只放我发的东西——角色发的不在这里，那是他们的主页。
struct FeedProfilePage: View {
    let world: WorldStore
    var onCompose: () -> Void

    private var myNotes: [FeedNote] {
        world.state.feed
            .filter { $0.authorName == "我" }
            .sorted { $0.postedAt > $1.postedAt }
    }

    private var totalLikes: Int {
        myNotes.reduce(0) { $0 + $1.likes }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                banner
                identity
                stats
                grid
            }
            .padding(.bottom, PhoneMetrics.Space.xl)
        }
    }

    // MARK: - 头部

    private var banner: some View {
        ZStack(alignment: .trailing) {
            LinearGradient(
                colors: [Theme.brand.opacity(0.22), Theme.brand.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 右边一块淡淡的水印，跟下面头像呼应
            WatermelonMark(size: 76)
                .opacity(0.35)
                .padding(.trailing, PhoneMetrics.Space.m)
                .offset(y: -12)
        }
        .frame(height: 96)
        .clipped()
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: PhoneMetrics.Space.xs) {
            HStack(alignment: .bottom, spacing: PhoneMetrics.Space.s) {
                ZStack {
                    Circle()
                        .fill(Theme.Watermelon.pith)
                    WatermelonMark(size: 38)
                }
                .frame(width: 66, height: 66)
                .overlay(
                    Circle().strokeBorder(AppSurface.light.rowSurface, lineWidth: 3)
                )
                .offset(y: -18)

                VStack(alignment: .leading, spacing: 2) {
                    Text("我")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(AppSurface.light.label)

                    Text("西瓜号：xgpi_0001")
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                }
                .padding(.bottom, PhoneMetrics.Space.xs)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, PhoneMetrics.Space.m)

            Text("这个号只发我自己的东西。")
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(AppSurface.light.label)
                .padding(.horizontal, PhoneMetrics.Space.m)
        }
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
                        FeedDetailPage(note: note, world: world)
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
