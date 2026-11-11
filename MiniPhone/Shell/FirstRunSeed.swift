import Foundation
import SwiftData

/// 第一次打开时自带的东西。
///
/// 原来装完是一张空列表：没有角色、没有聊天、点进任何一屏都是空态，
/// 得先自己建角色、写设定、开口说话，才知道这个 App 是干嘛的。
/// 这里放两个能直接聊的人，加一个两人都在的群。
@MainActor
enum FirstRunSeed {
    /// 第二版：v1 装出来的机器只剩一个小助手（种子顺序打架），
    /// 换个键让手上那台也能补上两个人一个群。守卫会挡住已经有角色的人。
    private static let key = "seed.firstRun.v2"

    static func runIfNeeded(context: ModelContext, world: WorldStore, companions: [Companion]) {
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        // 库里已经有别人就说明不是第一次（老版本升级、或者手动导过），不插手。
        //
        // 小助手不算别人：它在启动时比这里早一步入库，用 `isEmpty` 判断会让
        // 这两个人和一个群永远种不进去——装完只剩一个小助手。
        guard companions.allSatisfy({ $0.name == DefaultAssistant.name }) else { return }

        let shen = companion(
            context: context,
            name: "沈砚",
            persona: "在杭州做独立设计，话少，记性好，习惯把事压在心里。回消息不快，但每句都接得住。",
            greeting: "回来了？",
            signature: "晚点到",
            lines: [
                (true, "刚到，今天忙死了"),
                (false, "先坐会儿。水在桌上，凉了再倒。"),
                (true, "你今天画完那张了吗"),
                (false, "画完了。不太满意，明天再改一版。")
            ]
        )

        let lin = companion(
            context: context,
            name: "林渡",
            persona: "深夜电台主播，话密，爱开玩笑，但听得懂别人没说出口的那部分。作息颠倒。",
            greeting: "喂，还没睡？",
            signature: "凌晨两点在播",
            lines: [
                (true, "睡不着"),
                (false, "那正好，我这边刚放完一首。要不要听我讲两句废话？"),
                (true, "讲吧"),
                (false, "今天有个听众点了一首八年前的歌，说是分手那天听的。我没敢念他的名字。")
            ]
        )

        let group = group(context: context, members: [shen.name, lin.name])

        world.state.people = [
            person(name: shen.name, summary: "刚认识。他不太主动说自己的事。", voice: "她今天回得比平时快，可能是真的累了。", groupNote: "约了周日中午在老地方吃饭，他负责订位。"),
            person(name: lin.name, summary: "刚认识。半夜才醒着。", voice: "其实那首放完我本来想再讲两句，忍住了。", groupNote: "周日会晚到十分钟，让人先点。")
        ]
        world.primaryName = shen.name
        world.save()

        // 群在会话列表里排最前，单聊按时间。
        group.sortIndex = -1
        try? context.save()
    }

    /// 重置版本号。清空全部数据之后应该回到「刚装好」的样子。
    static func resetFlag() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - 建对象

    private static func companion(
        context: ModelContext,
        name: String,
        persona: String,
        greeting: String,
        signature: String,
        lines: [(Bool, String)]
    ) -> Companion {
        let character = Companion(name: name, persona: persona, greeting: greeting)
        character.signature = signature
        character.lastMessageAt = Date()
        context.insert(character)

        let base = Date().addingTimeInterval(-Double(lines.count) * 90)
        for (index, line) in lines.enumerated() {
            let message = StoredMessage(
                characterUID: character.uid,
                role: line.0 ? .user : .assistant,
                text: line.1,
                speaker: nil,
                createdAt: base.addingTimeInterval(Double(index) * 90)
            )
            message.character = character
            context.insert(message)
        }

        try? context.save()
        return character
    }

    private static func group(context: ModelContext, members: [String]) -> Companion {
        let created = Companion(
            name: "周末饭局",
            persona: "",
            greeting: "",
            isGroup: true,
            membersNote: members.joined(separator: "、"),
            sortIndex: -1
        )
        created.lastMessageAt = Date()
        context.insert(created)

        let lines: [(ChatMessage.Role, String?, String)] = [
            (.user, nil, "周日中午，老地方？"),
            (.assistant, "沈砚", "我来订位，上次那家靠窗的还空着。"),
            (.assistant, "林渡", "我可能晚十分钟，别等我先点。"),
            (.user, nil, "行，那我先把菜单发群里。"),
            (.assistant, "沈砚", "发吧，别又点香菜。")
        ]

        for (index, line) in lines.enumerated() {
            let message = StoredMessage(
                characterUID: created.uid,
                role: line.0,
                text: line.2,
                speaker: line.1,
                createdAt: Date().addingTimeInterval(Double(index - lines.count) * 60)
            )
            message.character = created
            context.insert(message)
        }

        try? context.save()
        return created
    }

    private static func person(name: String, summary: String, voice: String, groupNote: String) -> PersonMemory {
        PersonMemory(
            name: name,
            summary: summary,
            facts: [],
            voices: [
                InnerVoiceEntry(
                    id: UUID(),
                    personName: name,
                    text: voice,
                    createdAt: Date(),
                    source: .chat,
                    isResolved: false,
                    resolvedAt: nil,
                    lastReferencedAt: nil
                )
            ],
            groupNotes: ["周末饭局": groupNote]
        )
    }
}
