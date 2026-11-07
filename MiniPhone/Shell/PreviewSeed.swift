import SwiftUI
import SwiftData

/// 截图流水线用的演示数据。
///
/// 从 `PhoneShellView` 抽出来的：这段只在带 `-previewState` 启动时跑，
/// 跟外壳的状态机没关系，留在 view 里只会让那个文件一直贴着 600 行上限。
/// 依赖全部由外面传进来，不读外壳的私有状态。
@MainActor
struct PreviewSeeder {
    let state: String
    let companions: [Companion]
    let context: ModelContext
    let world: WorldStore

    // MARK: - 入口

    /// 只在带 `-previewState` 启动时写。正常启动读不到这个键，一条都不会插。
    /// 聊天详情和我的主页没有预置内容就是空态，截图看不出布局对不对。
    func run() {
        switch state {
        case "chatDetail", "chatStickers", "chatPhoto", "charDetail", "call":
            guard companions.isEmpty else { return }
            let character = Companion(
                name: "小满",
                persona: "住在隔壁、话不多但记性很好的女生，说话短，不爱用感叹号。",
                greeting: "回来啦？今天楼下那家关得早。"
            )
            character.signature = "慢一点也没关系"
            // 截图要能看出照片头像的实际效果，不然拍出来还是渐变圆。
            character.avatarImageKey = "avatar_a03"
            context.insert(character)

            let lines: [(ChatMessage.Role, String, Int)] = [
                (.assistant, "回来啦？今天楼下那家关得早。", 0),
                (.user, "啊，那我明天早点去。", 0),
                (.assistant, "嗯，我给你留了张便签在门上。", 0),
                // 带图的一条：截图里要能看到气泡里的图，不然不知道发图长什么样。
                (.assistant, "楼下那只又蹲在车底下了。", MockPhotoSubject.cat.seed)
            ]
            for (index, line) in lines.enumerated() {
                let message = StoredMessage(
                    characterUID: character.uid,
                    role: line.0,
                    text: line.1,
                    imageSeed: line.2,
                    createdAt: Date().addingTimeInterval(Double(index) * 60 - 180)
                )
                message.character = character
                context.insert(message)
            }
            try? context.save()

        case "feedProfile":
            guard !world.state.feed.contains(where: { $0.authorName == "我" }) else { return }
            world.publishNote(
                title: "今天把窗台收拾了一下",
                body: "擦完灰才发现那盆薄荷偷偷长高了一截。",
                tag: "日常"
            )
            world.publishNote(
                title: "晚自习后的操场",
                body: "灯只亮了一半，风比白天凉很多。",
                tag: "傍晚"
            )
            world.publishNote(
                title: "给自己留的一小时",
                body: "什么都不做，坐着发呆也算数。",
                tag: "记录"
            )

        case "market":
            world.seedPreviewShop()

        case "phonePeek":
            // 截图要看到内容，不能是「还没生成」那一屏。垫一个角色 + 一台写好的手机。
            let owner = companions.first?.name ?? "沈砚"
            if companions.isEmpty {
                let character = Companion(
                    name: "沈砚",
                    persona: "在杭州做设计，话不多，记性好，习惯把事压在心里不说。",
                    greeting: "回来了？"
                )
                character.signature = "晚点到"
                character.lastMessageAt = Date()
                context.insert(character)
                try? context.save()
            }
            world.seedPreviewPhone(owner: owner)

        case "reading":
            // 书架空着看不出列高和进度条的排布，垫两本进来。
            var descriptor = FetchDescriptor<ReadingBook>()
            descriptor.fetchLimit = 1
            guard (try? context.fetch(descriptor))?.isEmpty ?? true else { return }
            let long = ReadingBook(
                title: "雨天记事",
                body: """
                窗外的雨从昨天夜里就没有停过。

                我把椅子挪到窗边，坐了一整个下午。楼下那条路上没有什么人，偶尔有一把伞过去，伞面压得很低，看不清是谁。

                快到傍晚的时候，雨小了一点。我下楼买了一杯热的，回来的时候杯壁上已经全是水汽。纸杯拿在手里发软。

                天完全黑下来之前，最后一点光落在对面的墙上。那面墙本来是白的，被雨泡了一天，看起来有点像旧纸。
                """
            )
            long.paragraphIndex = 2
            long.lastReadAt = Date()
            context.insert(long)

            let short = ReadingBook(
                title: "他写的三段",
                body: """
                第一段：关于天气。

                第二段：关于你说过的那家店。

                第三段：没写完。
                """
            )
            short.paragraphIndex = 1
            short.lastReadAt = Date().addingTimeInterval(-3600)
            context.insert(short)
            try? context.save()

        case "feedInbox", "feedChat", "feedShare", "feedCard":
            seedInbox()

        default:
            break
        }
    }

    /// 私信/转帖的演示数据：角色、两类来件、活动索引、开场白消息一次配齐。
    /// 只在带 -previewState 时写，正常启动一行都不碰。
        private func seedInbox() {
        guard world.state.feedInbox.isEmpty else { return }

        let character: Companion
        if let existing = companions.first(where: { $0.name == "小满" }) {
            character = existing
        } else {
            let fresh = Companion(
                name: "小满",
                persona: "住在隔壁、话不多但记性很好的女生，说话短，不爱用感叹号。",
                greeting: ""
            )
            fresh.signature = "慢一点也没关系"
            fresh.avatarImageKey = "avatar_a03"
            context.insert(fresh)
            character = fresh
        }

        let share = FeedInboxItem(
            id: UUID(),
            kind: .postShare,
            companionUID: character.uid.uuidString,
            companionName: character.name,
            noteID: nil,
            noteTitle: "晚自习后的操场",
            noteBody: "灯只亮了一半，风比白天凉很多。你上次说想再去走走。",
            noteTag: "傍晚",
            coverSeed: 264,
            message: "看到这篇就想起你，周末要不要一起去？",
            createdAt: Date().addingTimeInterval(-3_600),
            isRead: true,
            threadID: UUID()
        )
        let direct = FeedInboxItem(
            id: UUID(),
            kind: .directMessage,
            companionUID: character.uid.uuidString,
            companionName: character.name,
            noteID: nil,
            noteTitle: "",
            noteBody: "",
            noteTag: "",
            coverSeed: 0,
            message: "刚路过楼下那家，给你带了杯热的。",
            createdAt: Date().addingTimeInterval(-600),
            isRead: false,
            threadID: UUID()
        )
        world.deliverFeedInbox(share)
        world.deliverFeedInbox(direct)

        for item in [share, direct] {
            if item.kind == .postShare {
                let sharedPost = FeedPostCardPayload(
                    noteID: item.noteID?.uuidString ?? "",
                    title: item.noteTitle,
                    body: item.noteBody,
                    tag: item.noteTag,
                    coverSeed: item.coverSeed
                )
                let cardLine = StoredMessage(
                    characterUID: character.uid,
                    role: .assistant,
                    text: sharedPost.encoded(),
                    channel: .feedShare,
                    threadID: item.threadID,
                    createdAt: item.createdAt.addingTimeInterval(-1)
                )
                cardLine.character = character
                context.insert(cardLine)
            }

            let message = StoredMessage(
                characterUID: character.uid,
                role: .assistant,
                text: item.message,
                channel: item.kind == .postShare ? .feedShare : .feedDM,
                threadID: item.threadID,
                createdAt: item.createdAt
            )
            message.character = character
            context.insert(message)
        }
        // 演示「我分享了一篇帖子」：卡片落在私信 thread 里，不是转帖通道。
        let myPost = FeedPostCardPayload(
            noteID: UUID().uuidString,
            title: "给自己留的一小时",
            body: "什么都不做，坐着发呆也算数。",
            tag: "记录",
            coverSeed: 264
        )
        let cardMessage = StoredMessage(
            characterUID: character.uid,
            role: .user,
            text: myPost.encoded(),
            channel: .feedDM,
            threadID: direct.threadID,
            createdAt: Date().addingTimeInterval(-240)
        )
        cardMessage.character = character
        context.insert(cardMessage)
        try? context.save()
    }
}
