import Foundation
import SwiftUI
import SwiftData

/// 群聊三屏的演示数据。
///
/// 单独成文件：`PreviewSeed.swift` 已经贴着 600 行上限。
/// 群消息必须带 `speaker`，否则气泡上没有署名，截图验不出「多个人各说各的」；
/// 只放一个人的消息，群聊和单聊在画面上长得一模一样。
/// 模拟器数据不会在两次 `-previewState` 之间清空，且 `chatCalls` 也建了同名群，
/// 所以按名字复用已存在的群，只补齐缺的部分，重复跑不会叠出第二份消息。
extension PreviewSeeder {
    func seedGroupChat() {
        let groupName = "周末饭局"
        let members = ["沈砚", "林渡"]

        let group: Companion
        if let existing = companions.first(where: { $0.name == groupName && $0.isGroup }) {
            group = existing
        } else {
            let created = Companion(
                name: groupName,
                persona: "",
                greeting: "",
                isGroup: true,
                membersNote: members.joined(separator: "、"),
                sortIndex: -1
            )
            context.insert(created)
            group = created
        }
        group.membersNote = members.joined(separator: "、")
        group.sortIndex = -1
        group.lastMessageAt = Date()

        if group.messages.isEmpty {
            let lines: [(ChatMessage.Role, String?, String)] = [
                (.user, nil, "周日中午，老地方？"),
                (.assistant, "沈砚", "我来订位，上次那家靠窗的还空着。"),
                (.assistant, "林渡", "我可能晚十分钟，别等我先点。"),
                (.user, nil, "行，那我先把菜单发群里。"),
                (.assistant, "沈砚", "发吧，别又点香菜。")
            ]
            for (index, line) in lines.enumerated() {
                let message = StoredMessage(
                    characterUID: group.uid,
                    role: line.0,
                    text: line.2,
                    speaker: line.1,
                    createdAt: Date().addingTimeInterval(Double(index - lines.count) * 60)
                )
                message.character = group
                context.insert(message)
            }
        }
        try? context.save()

        // 群共同记忆写在群名下的 PersonMemory，成员各自的视角写在自己的 groupNotes。
        // 两者落在不同位置，单聊和群聊才读得到不同的东西。
        world.syncGroup(named: groupName, members: members)
        world.replaceMemorySummary(
            person: groupName,
            text: "周日中午约在老地方。沈砚负责订位，林渡会晚到十分钟，让他先点。菜单里不点香菜。"
        )
        world.setGroupNote(
            person: "沈砚",
            group: groupName,
            text: "这轮我接了订位的事。靠窗那桌是我记着的，别再点香菜。"
        )
        world.setGroupNote(
            person: "林渡",
            group: groupName,
            text: "我说了会晚到，让他们先点。不想每次都解释为什么迟到。"
        )
    }
}
