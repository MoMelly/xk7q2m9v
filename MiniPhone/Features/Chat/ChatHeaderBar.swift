import SwiftUI

/// 聊天页顶栏。
///
/// 从 `ChatView` 抽出来的：那个文件一直贴着 600 行上限，加一个入口就得先
/// 拆一个函数。顶栏是整页里唯一一块「只读状态、只回调」的视图，
/// 拆出来不牵扯业务逻辑，最划算。
///
/// 三处能点：头像双击拍一拍、名字点开详情、右上角两个菜单。
struct ChatHeaderBar: View {
    let character: Companion

    var onBack: () -> Void
    var onPat: () -> Void
    var onOpenDetail: () -> Void
    var onOpenVoices: () -> Void
    /// 发一张图。和表情面板互斥，由外面收拾。
    var onOpenPhotos: () -> Void
    var onCall: (CallKind) -> Void
    var onCallHistory: () -> Void
    /// 一起听。标题随邀请状态变（「一起听」/「结束一起听」）。
    var togetherTitle: String
    var onTogether: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            GlassIconButton(symbol: "chevron.left", action: onBack)

            HStack(spacing: 9) {
                // 双击头像 = 拍一拍。头像只认双击：外层那块单击是「打开详情」，
                // 两个手势叠在同一处会互相抢，单击第一下就把详情推出来了。
                AvatarBubble(character: character, size: 30)
                    .onTapGesture(count: 2) { onPat() }

                VStack(alignment: .leading, spacing: 1) {
                    Text(character.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.cream)
                        .lineLimit(1)

                    TimelineView(.everyMinute) { context in
                        Text(ChatLabels.subtitle(character, at: context.date))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(
                                CharacterClock.isAsleep(character, at: context.date)
                                    ? Theme.cream.opacity(0.4)
                                    : Theme.mint.opacity(0.72)
                            )
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { onOpenDetail() }
            }

            Spacer(minLength: 0)

            // 真机的信息 App 右上角就是这个位置放通话入口。
            // 点开是三项：语音、视频、通话记录——不再单独占一个桌面图标。
            GlassMenuButton(symbol: "phone.fill") {
                ChatCallMenuItems(
                    onPhotos: onOpenPhotos,
                    onCall: onCall,
                    onHistory: onCallHistory,
                    togetherTitle: togetherTitle,
                    onTogether: onTogether,
                    isGroup: character.isGroup
                )
            }

            // 右上角原来直接开详情。加了心声之后这一格装不下两个入口，
            // 改成菜单：真机的「…」本来也是弹菜单，不是跳页。
            GlassMenuButton(symbol: "ellipsis") {
                Button {
                    onOpenDetail()
                } label: {
                    Label("角色详情", systemImage: "person.text.rectangle")
                }

                // 心声挂在每个人名下，群名下没有。群聊里这一项点开恒为空。
                if !character.isGroup {
                    Button {
                        onOpenVoices()
                    } label: {
                        Label("他的心声", systemImage: "quote.bubble")
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}

/// 聊天页顶栏那行小字。
enum ChatLabels {
    /// 「自定义 · 在的」「群聊 · 睡了」
    static func subtitle(_ character: Companion, at date: Date) -> String {
        var parts: [String] = [character.preset.displayName]
        if character.isGroup {
            parts.append("群聊")
        }
        parts.append(CharacterClock.isAsleep(character, at: date) ? "睡了" : "在的")
        return parts.joined(separator: " · ")
    }
}

/// 通话菜单项。
///
/// 顶栏的「电话」和输入栏的「+」放的是同一份东西。各写一遍的话，
/// 早晚一边加了「发图片」另一边没加。
struct ChatCallMenuItems: View {
    var onPhotos: () -> Void
    var onCall: (CallKind) -> Void
    var onHistory: () -> Void
    /// 一起听。两处入口共用一份菜单，所以标题和动作都从外面传进来。
    var togetherTitle: String
    var onTogether: () -> Void
    /// 发红包。只有输入栏那个「+」给，电话菜单里不给——那儿是通话的地方。
    var onPacket: (() -> Void)? = nil
    /// 群聊里没有通话，也没有「一起听」。
    ///
    /// 群不是一个能接电话的东西：拨过去该谁接？一起听也一样——
    /// 一副耳机没法三个人分。这两项留在菜单里，点了就是个说不通的操作。
    var isGroup: Bool = false

    var body: some View {
        Button {
            onPhotos()
        } label: {
            Label("发一张图", systemImage: "photo.on.rectangle")
        }

        if let onPacket {
            Button {
                onPacket()
            } label: {
                Label("发红包", systemImage: "yensign.circle.fill")
            }
        }

        if !isGroup {
            Button {
                onTogether()
            } label: {
                Label(togetherTitle, systemImage: "headphones")
            }
        }

        if !isGroup {
            Divider()

            Button {
                onCall(.voice)
            } label: {
                Label("语音通话", systemImage: "phone.fill")
            }

            Button {
                onCall(.video)
            } label: {
                Label("视频通话", systemImage: "video.fill")
            }
        }

        if !isGroup {
            Divider()

            Button {
                onHistory()
            } label: {
                Label("通话记录", systemImage: "clock.arrow.circlepath")
            }
        }
    }
}
