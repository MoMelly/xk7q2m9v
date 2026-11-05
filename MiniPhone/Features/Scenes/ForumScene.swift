import SwiftUI

/// 论坛。
///
/// 深色 App，和聊天、动态同一套玻璃体系。列表按系统的帖子流来排：
/// 作者与时间在上、标题居中偏粗、正文折行、右下角回复数。
/// 内容是本地模板，不联网。
struct ForumScene: View {
    let world: WorldStore
    var onClose: () -> Void

    private var posts: [ForumPost] {
        world.state.forum.sorted { $0.postedAt > $1.postedAt }
    }

    var body: some View {
        AppScreen(title: "论坛", surface: .dark, onClose: onClose) {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.s) {
                    ForEach(posts) { post in
                        postCard(post)
                    }
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    private func postCard(_ post: ForumPost) -> some View {
        VStack(alignment: .leading, spacing: PhoneMetrics.Space.xs) {
            HStack(spacing: PhoneMetrics.Space.xs) {
                Circle()
                    .fill(Theme.retroGreen.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text(String(post.author.prefix(1)))
                            .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 0) {
                    Text(post.author)
                        .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(TimeFormat.callTime(post.postedAt))
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer(minLength: 0)
            }

            Text(post.title)
                .font(.system(size: PhoneMetrics.FontSize.body, weight: .semibold))
                .foregroundStyle(.white)

            Text(post.body)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: PhoneMetrics.Space.xxs) {
                Image(systemName: "bubble.left")
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                Text("\(post.replyCount) 回复")
                    .font(.system(size: PhoneMetrics.FontSize.caption))
            }
            .foregroundStyle(.white.opacity(0.5))
        }
        .padding(PhoneMetrics.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                .fill(.white.opacity(0.08))
        )
    }
}
