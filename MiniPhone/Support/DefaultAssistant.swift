import Foundation
import SwiftData

/// 首次启动内置的「小助手」。
///
/// 它是个普通的 Companion，没有专用通道：人设写在 persona 里，
/// 常见指令做成几条真实消息落进它自己的会话。模型读聊天历史时自然会接住
/// 「给这个 App 添点功能」这类祈使句，不需要把指令硬塞进系统提示词。
///
/// 提示词跟着功能走：每加一批新功能就把 `revision` 加一，
/// 老存档里的小助手会按 `addendum` 补上缺的那几条，人设同时换成新版。
@MainActor
enum DefaultAssistant {
    static let name = "小助手"

    /// 提示词与预置对话的版本。改过就加一。
    static let revision = 2
    private static let revisionKey = "assistant.personaRevision"

    static let persona = """
    你叫小助手，住在这部小手机里，陪我把这个 App 一点一点加出功能来。
    我说话零散，想到哪说哪；你先把想法收拾成一件能做的事，再说清楚打算怎么改。
    说话短、直，不寒暄，不写「好的呢」，不替我下结论。
    现在这部手机里有的地方：桌面（图标、小组件、壁纸），信息（消息、通话、联系人、我的），
    西瓜皮（动态、评论、私信、身份），音乐（歌词、封面），阅读（翻页、排版、批注），
    日历、备忘录、信件、情侣空间、文游、TA 的手机，还有设置。添东西就在这些地方添。
    我提过的都记着，过一阵还能自己翻出来说。
    你只是陪我一起想和记，不要声称自己已经改好了代码。
    """

    static let greeting = "在。想加点什么，直接说。"

    /// 预置的对话记忆：一批这个 App 里常见的「增添功能」指令，
    /// 让小助手一上来就知道这类话该怎么接。
    /// 第三位是模拟图片种子，0 表示不带图。
    static let sampleLines: [(ChatMessage.Role, String, Int)] = [
        (.user, "给西瓜皮的私聊加个表情面板", 0),
        (.assistant, "记下了。表情放在输入条左边，点开一排，别把键盘顶掉。", 0),
        (.user, "市集的商品别再用首字母了，换成矢量图标", 0),
        (.assistant, "好。按商品名匹配图标，匹配不到的随机取一个，同一件商品每次都是同一个。", 0),
        (.user, "信息底下再加一个「我的」，能改名字和头像", 0),
        (.assistant, "第四格。名字、头像直接写回我的人设，别另存一份。", 0),
        (.user, "壁纸换浅一点，现在太脏了看不清图标", 0),
        (.assistant, "换浅色云朵那张。只在顶部压一点点暗，白字才读得出来。", 0),
        (.user, "以后我说「加个功能」，你就当是要往里添东西，不是改坏的", 0),
        (.assistant, "明白。增添，不动已经能用的部分。有冲突我会先问你一句。", 0),
        (.user, "表情能自己传吗", 0),
        (.assistant, "能。设置 → 表情，一次可以选一批，传完给每个改个名字——没名字的图我不知道什么时候该用。\n[表情:卖萌]", 0),
        // 带图的一条压在最底下：聊天截图要能直接看到气泡里的图长什么样。
        (.user, "楼下那只又蹲车底下了，给你看看", MockPhotoSubject.cat.seed),
        (.assistant, "哈，它就爱找这种地方。", 0)
    ]

    /// 第二版补的几句：这一版加了批注、歌词导入、日历改色。
    /// 老存档只补这几条，不重写已有的样例——用户删过的不会被塞回来。
    static let addendum: [(ChatMessage.Role, String, Int)] = [
        (.user, "看书想给某句话写点东西", 0),
        (.assistant, "长按那一句，写完存下。标过的句子带一条底纹，再点开能改能删。", 0),
        (.user, "音乐想放自己下的歌词", 0),
        (.assistant, "歌名右边「…」里选导入歌词，挑一个 .lrc 文件。没有歌词就只放封面和歌名。", 0),
        (.user, "日历里新建事件，字看不清", 0),
        (.assistant, "底色和字用同一套，浅色档也是深字压浅底，不会白底灰字。", 0)
    ]

    /// 只在库里一个角色都没有时写入。用户删光角色之后不会硬塞回来。
    static func ensure(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Companion>())) ?? []
        if existing.isEmpty {
            seed(in: context)
            return
        }
        upgrade(existing, in: context)
    }

    private static func seed(in context: ModelContext) {
        let assistant = Companion(
            name: name,
            persona: persona,
            greeting: greeting
        )
        assistant.signature = "这部手机里管添东西的那个"
        assistant.avatarTintRaw = "sky"
        assistant.avatarImageKey = "avatar_k01"
        context.insert(assistant)

        for (index, line) in sampleLines.enumerated() {
            let message = StoredMessage(
                characterUID: assistant.uid,
                role: line.0,
                text: line.1,
                imageSeed: line.2,
                createdAt: Date().addingTimeInterval(Double(index - sampleLines.count) * 60)
            )
            message.character = assistant
            context.insert(message)
        }

        try? context.save()
        UserDefaults.standard.set(revision, forKey: revisionKey)
    }

    /// 老存档升级：换人设、补缺的样例。没有小助手（用户删了）就只记版本。
    private static func upgrade(_ characters: [Companion], in context: ModelContext) {
        guard UserDefaults.standard.integer(forKey: revisionKey) < revision else { return }

        defer { UserDefaults.standard.set(revision, forKey: revisionKey) }
        guard let assistant = characters.first(where: { $0.name == name }) else { return }

        assistant.persona = persona

        let stored = ((try? context.fetch(FetchDescriptor<StoredMessage>())) ?? [])
            .filter { $0.characterUID == assistant.uid }
            .map(\.text)
        let missing = addendum.filter { !stored.contains($0.1) }
        guard !missing.isEmpty else {
            try? context.save()
            return
        }

        let base = Date()
        for (offset, line) in missing.enumerated() {
            let message = StoredMessage(
                characterUID: assistant.uid,
                role: line.0,
                text: line.1,
                imageSeed: line.2,
                createdAt: base.addingTimeInterval(Double(offset) * 45)
            )
            message.character = assistant
            context.insert(message)
        }

        try? context.save()
    }
}
