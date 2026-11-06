import SwiftUI
import SwiftData

/// 从笔记详情点「分享到私聊」之后弹出来的收件人列表。
///
/// 只列能聊的角色（isFeedOnly 的路人作者不算）。选完直接把帖子卡片
/// 写进那个人的私信 thread，不在私聊界面里再发起一次分享。
struct FeedSharePicker: View {
    let onPick: (Companion) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var companions: [Companion]

    private var candidates: [Companion] {
        companions.filter { !$0.isFeedOnly }
    }

    var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 28))
                        Text("还没有能聊天的人")
                            .font(.system(size: PhoneMetrics.FontSize.sub))
                        Text("先去「信息」里造一个角色，再来分享。")
                            .font(.system(size: PhoneMetrics.FontSize.caption))
                    }
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(candidates) { character in
                        Button {
                            onPick(character)
                            dismiss()
                        } label: {
                            HStack(spacing: PhoneMetrics.Space.s) {
                                FeedDefaultAvatarView(name: character.name, size: 38)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(character.name)
                                        .font(.system(size: PhoneMetrics.FontSize.body, weight: .medium))
                                        .foregroundStyle(AppSurface.light.label)
                                    Text("发到私聊")
                                        .font(.system(size: PhoneMetrics.FontSize.caption))
                                        .foregroundStyle(AppSurface.light.secondaryLabel)
                                }

                                Spacer(minLength: 0)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppSurface.light.secondaryLabel)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("分享给")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .environment(\.colorScheme, .light)
        }
        .presentationDetents([.medium, .large])
    }
}
