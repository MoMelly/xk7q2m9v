import SwiftUI
import SwiftData

/// 从笔记详情点「分享到私聊」之后弹出来的收件人面板。
///
/// 小红书式的半屏弹层：头像九宫格直接铺开，不搞导航列表。
/// 只列能聊的角色（isFeedOnly 的路人作者不算）。选完直接把帖子卡片
/// 写进那个人的私信 thread，不在私聊界面里再发起一次分享。
struct FeedSharePicker: View {
    let onPick: (Companion) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var companions: [Companion]

    private var candidates: [Companion] {
        // 分享是「一个人找你说话」的通道，群没有自己的私信 thread。
        companions.filter { !$0.isFeedOnly && !$0.isGroup }
    }

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 14),
        count: 4
    )

    var body: some View {
        VStack(spacing: 0) {
            // 顶部那条小横杠是弹层的手势暗示，点不出东西但看着在。
            Capsule()
                .fill(AppSurface.light.secondaryLabel.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 12)

            Text("分享给")
                .font(.system(size: PhoneMetrics.FontSize.sub, weight: .medium))
                .foregroundStyle(AppSurface.light.label)
                .frame(maxWidth: .infinity)
                .padding(.bottom, PhoneMetrics.Space.s)

            if candidates.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(candidates) { character in
                            Button {
                                onPick(character)
                                dismiss()
                            } label: {
                                VStack(spacing: 6) {
                                    AvatarBubble(character: character, size: 52)

                                    Text(character.name)
                                        .font(.system(size: PhoneMetrics.FontSize.caption))
                                        .foregroundStyle(AppSurface.light.label)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, PhoneMetrics.Space.l)
                    .padding(.top, 6)
                    .padding(.bottom, PhoneMetrics.Space.m)
                }
            }

            Button {
                dismiss()
            } label: {
                Text("取消")
                    .font(.system(size: PhoneMetrics.FontSize.body, weight: .medium))
                    .foregroundStyle(AppSurface.light.label)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(AppSurface.light.background)
                    .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, PhoneMetrics.Space.m)
            .padding(.bottom, PhoneMetrics.Space.m)
        }
        .background(AppSurface.light.rowSurface)
        .presentationDetents([.height(320)])
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 26))
            Text("还没有能聊天的人")
                .font(.system(size: PhoneMetrics.FontSize.sub))
            Text("先去「信息」里造一个角色，再来分享。")
                .font(.system(size: PhoneMetrics.FontSize.caption))
        }
        .foregroundStyle(AppSurface.light.secondaryLabel)
        .frame(maxWidth: .infinity)
        .padding(.vertical, PhoneMetrics.Space.xl)
    }
}
