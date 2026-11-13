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
            lyrics: LyricsLoader.parse(Self.previewLRC).lines
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

    /// 只在带 `-previewState` 启动时写；空态截图看不出布局，所以这几屏要垫数据。
    func run() {
        startFromDefaultIdentity()
        switch state {
        case "home", "homeVector", "homeDark", "homeNight":
            // 主屏三块组件都读世界状态。不垫数据，截出来全是「今天还没排事」。
            seedHomeWorld()

        case "musicBall", "musicLyrics":
            seedNowPlaying()

        case "couple", "coupleIdentity":
            seedCouple()
            if state == "coupleIdentity" { switchToSecondIdentity() }

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

        case "storyGame", "storyEnd", "storyPlay":
            seedStory()

        case "statePanel", "anonBox", "memoryLibrary", "worldEntries", "statePanelIdentity":
            seedWorldState()
            if state == "statePanelIdentity" { switchToSecondIdentity() }

        case "chatGroup", "groupDetail", "groupMemory":
            seedGroupChat()

        case "chatCalls":
            // 这一屏要验「群不在能拨号的名单里」，所以必须真的建一个群，
            // 还把它排在最前：只放几个人的话，滤不滤群截图上完全一样。
            ensureDemoCompanion()
            if !companions.contains(where: { $0.isGroup }) {
                let group = Companion(
                    name: "周末饭局",
                    persona: "",
                    greeting: "",
                    isGroup: true,
                    membersNote: "沈砚",
                    sortIndex: -1
                )
                group.lastMessageAt = Date()
                context.insert(group)
                try? context.save()
            }

        default:
            break
        }
    }

    /// 世界状态四屏（状态面板 / 提问箱 / 记忆库 / 世界书）的预置数据。
    ///
    /// 这四屏读的都是 `WorldState` 和世界书条目。不垫数据的话，
    /// 每一张截出来都是同一个「还没有」，排版对不对根本看不出来。
    private func seedWorldState() {
        let character = ensureDemoCompanion()
        let owner = character?.name ?? "沈砚"

        // 人物记忆：一段摘要、三条事实、一条没解开的心事。
        let memory = PersonMemory(
            name: owner,
            summary: "上周聊过加班的事，说到十一点才散。他不爱主动讲自己的事，但问起来会认真答。",
            facts: [
                PersonFact(
                    id: UUID(),
                    text: "在做一套要交三个月的图标稿",
                    sourceName: owner,
                    createdAt: Date().addingTimeInterval(-86_400 * 6)
                ),
                PersonFact(
                    id: UUID(),
                    text: "不吃香菜，点外卖会特意备注",
                    sourceName: owner,
                    createdAt: Date().addingTimeInterval(-86_400 * 4)
                ),
                PersonFact(
                    id: UUID(),
                    text: "周五晚上一般去江边跑步",
                    sourceName: owner,
                    createdAt: Date().addingTimeInterval(-86_400 * 2)
                )
            ],
            voices: [
                InnerVoiceEntry(
                    id: UUID(),
                    personName: owner,
                    text: "其实那天想说的是，图可以慢慢改。",
                    createdAt: Date().addingTimeInterval(-3_600),
                    source: .chat,
                    isResolved: false,
                    resolvedAt: nil,
                    lastReferencedAt: nil
                )
            ]
        )
        if let index = world.state.people.firstIndex(where: { $0.name == owner }) {
            world.state.people[index] = memory
        } else {
            world.state.people.append(memory)
        }
        world.state.affinity[owner] = 62

        // 状态面板的「此刻」和「在哪」。空着的话那两行永远是「没写过」，
        // 看不出真实数据下这层是什么样。
        world.state.moods[owner] = MoodState(
            mood: .tired,
            reason: "赶了两天的图，眼睛有点干",
            updatedAt: Date(),
            source: .chat
        )
        world.state.locations[owner] = "工作室"

        // 提问箱：两条答过的、一条还没答的。
        if world.state.questions.isEmpty {
            world.state.questions = [
                AnonymousQuestion(
                    id: UUID(),
                    characterName: owner,
                    asker: "匿名 3 号",
                    text: "你觉得自己是个容易开心的人吗？",
                    answer: "算是吧。开心这种事，我一般后知后觉。",
                    askedAt: Date().addingTimeInterval(-86_400 * 2),
                    answeredAt: Date().addingTimeInterval(-86_400 * 2 + 3_600)
                ),
                AnonymousQuestion(
                    id: UUID(),
                    characterName: owner,
                    asker: "匿名 7 号",
                    text: "最近一次觉得「还好有他」是什么时候？",
                    answer: "上次改图到半夜，回来看到灯还亮着。",
                    askedAt: Date().addingTimeInterval(-86_400),
                    answeredAt: Date().addingTimeInterval(-86_400 + 5_400)
                ),
                AnonymousQuestion(
                    id: UUID(),
                    characterName: owner,
                    asker: "匿名 11 号",
                    text: "有没有什么一直想做但没做的事？",
                    answer: "",
                    askedAt: Date().addingTimeInterval(-7_200),
                    answeredAt: nil
                )
            ]
        }
        world.save()

        // 世界书：一条常驻的全局，一条挂在这个角色名下的关键词条目。
        let existing = (try? context.fetch(FetchDescriptor<WorldEntry>())) ?? []
        guard existing.isEmpty else { return }
        context.insert(
            WorldEntry(
                characterUID: nil,
                keywords: "",
                content: "这个世界的手机网络稳定，外送和打车都方便，晚上十一点后街上有保安巡逻。",
                kind: .constant
            )
        )
        if let character {
            context.insert(
                WorldEntry(
                    characterUID: character.uid,
                    keywords: "改图,加班,稿子",
                    content: "他在赶一套图标稿，截稿日在下个月三号。聊到工作时容易烦躁，聊别的会放松下来。",
                    kind: .keyword,
                    priority: 7,
                    position: .front
                )
            )
        }
        try? context.save()
    }

    /// 两局文游。
    ///
    /// `storyGame` 只看存档列表，`storyEnd` 进一局已结束的（看结局那一行），
    /// `storyPlay` 进一局进行中的（看选项和输入条）。两种状态共用同一份存档，
    /// 靠 `isEnded` 区分——不这样的话，验收时只能看到其中一半的界面。
    private func seedStory() {
        guard StoryArchive.loadAll().isEmpty else { return }

        var story = StorySession(
            title: "雨停之前",
            premise: "连着下了一周的雨，你们困在同一栋楼里，第二天就要各走各的。",
            characterUIDs: [],
            characterNames: ["沈砚"],
            playerName: "我"
        )
        story.lines = [
            StoryLine(speaker: nil, text: "雨还在下。楼梯间的灯忽明忽暗，他靠在窗边，没说话。", isNarration: true),
            StoryLine(speaker: "沈砚", text: "你也没走？", isNarration: false),
            StoryLine(speaker: "我", text: "我在等雨小一点。", isNarration: false),
            StoryLine(speaker: "沈砚", text: "那大概要等很久。", isNarration: false),
            StoryLine(speaker: nil, text: "他把窗推开一条缝，风把雨声放大了一档。", isNarration: true)
        ]
        story.summary = "两个人在雨里困了一晚，谁也没先说走。"
        story.choices = ["陪他等一会儿", "问他明天几点走", "什么也没说"]
        story.branchScore = StorySession.score(story.choices ?? [])
        story.isEnded = true
        story.endingLabel = story.dominantBranch?.endingTitle
        // 时间是往前推的：存档列表按 updatedAt 倒序，刚玩完的那局要排第一。
        story.createdAt = Date().addingTimeInterval(-5_400)
        story.updatedAt = Date().addingTimeInterval(-600)
        StoryArchive.save(story)

        // 进行中的那一局。这一份才看得到选项按钮和底部输入条。
        var playing = StorySession(
            title: "未寄出的信",
            premise: "抽屉最底下压着一封没寄出去的信，收信人明天就搬走了。",
            characterUIDs: [],
            characterNames: ["柏川", "阿岚"],
            playerName: "我"
        )
        playing.lines = [
            StoryLine(speaker: nil, text: "傍晚的光斜进来，把书桌切成两半。他把抽屉拉开，又停住了。", isNarration: true),
            StoryLine(speaker: "柏川", text: "你站在门口多久了。", isNarration: false),
            StoryLine(speaker: "我", text: "有一会儿了。那是什么？", isNarration: false),
            StoryLine(speaker: "柏川", text: "没什么。写坏了的。", isNarration: false),
            StoryLine(speaker: "阿岚", text: "写坏了还压在抽屉最底下？", isNarration: false),
            StoryLine(speaker: nil, text: "他没接话，把抽屉推回去一半，停在那里。", isNarration: true)
        ]
        playing.summary = "三个人围着一封没寄出去的信，谁都没把话说完。"
        playing.choices = ["问那封信是写给谁的", "替他把抽屉关上"]
        playing.branchScore = StorySession.score(playing.choices ?? [])
        playing.createdAt = Date().addingTimeInterval(-3_600)
        playing.updatedAt = Date().addingTimeInterval(-120)
        StoryArchive.save(playing)
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
