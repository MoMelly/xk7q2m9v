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

    // MARK: - 主屏

    /// 今天的日程 + 当前心情 + 在放的那首。
    ///
    /// 时段写死成 9 / 14 / 19 / 22。早先按「跑 CI 那一刻往后一小时」排，
    /// 流水线在凌晨两点跑，组件上就显出「02:00 在工作室改图」这种不像人写的安排。
    private func seedHomeWorld() {
        let slots = [(9, "在工作室改图", Mood.focused),
                     (14, "去趟打印店取样张", Mood.calm),
                     (19, "超市买菜", Mood.calm),
                     (22, "回来把书看完", Mood.calm)]
        let items = slots.map { hour, title, mood in
            ScheduleItem(
                id: UUID(),
                hour: hour,
                title: title,
                mood: mood,
                note: ""
            )
        }
        world.state.schedule = DaySchedule(
            dateKey: DayScheduleEngine.dateKey(),
            items: items,
            generatedAt: Date()
        )
        // 心情挂在人身上：主屏那块显示的是「最近说过话的那个人」现在怎样。
        // 这一屏没有真会话，落到演示角色头上，顺带把主屏要显示的人定下来。
        let owner = world.primaryName.isEmpty
            ? (ensureDemoCompanion()?.name ?? "沈砚")
            : world.primaryName
        world.primaryName = owner
        world.state.moods[owner] = MoodState(
            mood: .tired,
            reason: "赶了两天的图，眼睛有点干",
            updatedAt: Date(),
            source: .schedule
        )
        world.state.currentTrack = Track(
            id: "preview-track",
            title: "晚风",
            artist: "雨天公交",
            fileName: "bundle:晚风.m4a"
        )
        world.save()
    }

    /// 摆一首在放的歌，连歌词一起。仓库里没有音频，只写状态不动 AVPlayer。
    private func seedNowPlaying() {
        let track = Track(
            id: "preview-track",
            title: "晚风",
            artist: "雨天公交",
            fileName: "bundle:晚风.m4a"
        )
        world.state.currentTrack = track
        world.save()
#if DEBUG
        PlayerService.shared.stagePreview(
            track: track,
            lyrics: LyricsLoader.parse(Self.previewLRC)
        )
        // 截图里要能看到「和谁一起在听」。真机上这一步来自聊天里的邀请，
        // 冷启动点不到按钮，这里直接把状态摆好。
        // 内置小助手不算恋爱对象，让它出现在这行上读起来很怪，先垫一个角色。
        if let partner = ensureDemoCompanion() ?? companions.first {
            PlayerService.shared.invite(uid: partner.uid, name: partner.name)
        }
#endif
    }

    /// 一段真能解析的 LRC：解析器得跟着截图一起验，不能只验画面。
    private static let previewLRC = """
    [00:12.40]雨落在窗台上 没人在意
    [00:18.90]你说今天不回 也没关系
    [00:25.30]我把伞挂在门后
    [00:31.10]像挂着没说出口的话
    [00:38.50]晚风把路灯吹得有点晃
    [00:45.20]我数到第七盏就走
    [00:52.00]如果你也刚好抬头
    [00:58.60]就当是我们见过
    [01:05.30]晚风把公交站吹得有点空
    [01:12.10]我把手插在口袋里
    [01:18.70]假装不冷 假装不等
    """

    /// 连续 41 天，再往前留一段更早的。火花算的是交集，两侧都要填。
    ///
    /// 火花按角色分开存，截图这一屏默认开的是最近说过话的人，
    /// 所以种子必须挂在一个确定存在的角色名下——顺带把演示角色建出来。
    private func seedCouple() {
        let partner = ensureDemoCompanion()?.name ?? "沈砚"
        var couple = CoupleState()
        let calendar = Calendar.current
        let today = Date()

        func mark(_ offset: Int, both: Bool = true) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return }
            let key = DayScheduleEngine.dateKey(day)
            CoupleEngine.markMine(&couple, day: key)
            if both { CoupleEngine.markTheirs(&couple, day: key) }
        }

        for offset in 0..<41 { mark(offset) }
        // 更早的一段，跟上面断着——用来验「最长连续」不是简单把总天数加起来。
        for offset in 45...47 { mark(offset) }

        world.state.couples[partner] = couple
        world.save()
    }

    /// 截图用的固定角色。
    ///
    /// 只活在预览数据里：内置小助手是助手，不是恋爱对象，
    /// 让它出现在「和谁一起在听」那行上读起来很怪。
    @discardableResult
    private func ensureDemoCompanion() -> Companion? {
        if let existing = companions.first(where: { $0.name == "沈砚" }) {
            return existing
        }
        let character = Companion(
            name: "沈砚",
            persona: "在杭州做设计，话不多，记性好，习惯把事压在心里不说。",
            greeting: "回来了？"
        )
        character.signature = "晚点到"
        character.lastMessageAt = Date()
        context.insert(character)
        try? context.save()
        return character
    }

    // MARK: - 入口

    /// 只在带 `-previewState` 启动时写。正常启动读不到这个键，一条都不会插。
    /// 聊天详情和我的主页没有预置内容就是空态，截图看不出布局对不对。
    func run() {
        switch state {
        case "home", "homeVector", "homeDark", "homeNight":
            // 主屏三块组件都读世界状态。不垫数据，截出来全是「今天还没排事」。
            seedHomeWorld()

        case "musicBall", "musicLyrics":
            seedNowPlaying()

        case "couple":
            seedCouple()

        case "chatTogether":
            // 这一屏专门拍「一起听」的状态条，只需要一首在放的歌。
            // 邀请交给 `ChatView.onAppear`——这一屏打开的是哪个角色由外壳挑，
            // 邀请必须落在同一个人身上。歌放在这里，是因为它跟会话无关；
            // 也不能塞进下面那个 case：那一段有 `guard companions.isEmpty`，
            // 小助手已经存在时会整段跳过，垫了也白垫。
#if DEBUG
            PlayerService.shared.stagePreview(
                track: Track(
                    id: "preview-track",
                    title: "晚风",
                    artist: "雨天公交",
                    fileName: "bundle:晚风.m4a"
                ),
                lyrics: []
            )
#endif

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
            // 截图要看到内容，不能是「还没生成」那一屏。
            // 内置的小助手会在启动时自动建好，所以这里不能只看「有没有角色」，
            // 要专门确认这台手机的主人存在。
            let owner = "沈砚"
            ensureDemoCompanion()
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
