import SwiftUI
import SwiftData

/// 群里能开口的一个人。
///
/// 成员名单本身只是 `Companion.membersNote` 里一串名字，提示词、头像、
/// 成员页全都按名字回查。角色和「我的人设」在这里合成同一层：对外只给
/// 名字、简介和设定卡，不带来源标记，模型看到的就是群里一个普通成员。
struct GroupPerson: Identifiable {
    let name: String
    /// 列表里的一行简介。
    let detail: String
    /// 进提示词的设定卡。
    let persona: String
    let uid: UUID
    let since: Date
    /// 只用来画头像和跳详情，不进提示词。
    let companion: Companion?
    let profile: UserProfile?

    var id: String { name }
    /// 名单上写了名字，但两边都查不到人（老群手打错的那种）。
    var isOrphan: Bool { companion == nil && profile == nil }

    @ViewBuilder
    func avatar(size: CGFloat = 34) -> some View {
        if let companion {
            AvatarBubble(character: companion, size: size)
        } else if let profile {
            AvatarCircle(
                initial: String(profile.name.first ?? "?"),
                tint: AvatarTint(rawValue: profile.avatarTintRaw) ?? .mint,
                size: size,
                photo: profile.avatarPhoto
            )
        } else {
            AvatarCircle(initial: String(name.first ?? "?"), tint: .slate, size: size)
        }
    }
}

enum GroupPeople {
    /// 现在正用来说话的那个人。默认身份在存储里是空串，落到 isDefault 上。
    static func activeProfileUID(in profiles: [UserProfile]) -> String {
        let scope = IdentityScope.storedUID
        if !scope.isEmpty { return scope }
        return (profiles.first { $0.isDefault } ?? profiles.first)?.uid.uuidString ?? ""
    }

    /// 一个人设的设定卡。只写他自己填过的资料，不交代这份资料从哪来。
    static func persona(of profile: UserProfile) -> String {
        var parts: [String] = []
        let signature = profile.signature.trimmingCharacters(in: .whitespacesAndNewlines)
        if !signature.isEmpty { parts.append(signature) }
        let bio = profile.bio.trimmingCharacters(in: .whitespacesAndNewlines)
        if !bio.isEmpty { parts.append(bio) }
        if !profile.tags.isEmpty {
            parts.append("标签：" + profile.tags.joined(separator: "、"))
        }
        let status = profile.statusText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !status.isEmpty { parts.append("现在：" + status) }
        return parts.joined(separator: "；")
    }

    /// 按名字回查。角色优先；名字撞了的时候，群里的那一位按角色算。
    static func find(
        named name: String,
        in roster: [Companion],
        profiles: [UserProfile]
    ) -> GroupPerson {
        if let character = roster.first(where: { $0.name == name }) {
            let persona = character.persona
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
            return GroupPerson(
                name: name,
                detail: persona,
                persona: persona,
                uid: character.uid,
                since: character.knownSince,
                companion: character,
                profile: nil
            )
        }
        if let profile = profiles.first(where: { $0.name == name }) {
            let text = persona(of: profile)
            return GroupPerson(
                name: name,
                detail: text,
                persona: text,
                uid: profile.uid,
                since: profile.createdAt,
                companion: nil,
                profile: profile
            )
        }
        return GroupPerson(
            name: name,
            detail: "",
            persona: "",
            uid: UUID(),
            since: Date(),
            companion: nil,
            profile: nil
        )
    }

    /// 名单上的人，按名单顺序。
    static func members(
        note: String,
        roster: [Companion],
        profiles: [UserProfile]
    ) -> [GroupPerson] {
        GroupRoster.names(from: note).map {
            find(named: $0, in: roster, profiles: profiles)
        }
    }

    /// 能拉进群的人：已有角色和其它人设混在同一张名单里。
    ///
    /// 正在用来说话的那个人不列：他已经是这段对话里「跟我说话的人」，
    /// 同名再进成员表，模型分不清这两个位置。
    static func candidates(
        roster: [Companion],
        profiles: [UserProfile],
        excluding: Set<String> = []
    ) -> [GroupPerson] {
        let active = activeProfileUID(in: profiles)
        var result: [GroupPerson] = []
        var seen = Set<String>()

        for character in roster where !character.isGroup
            && !character.isFeedOnly
            && character.name != DefaultAssistant.name {
            if excluding.contains(character.name) || seen.contains(character.name) { continue }
            seen.insert(character.name)
            result.append(find(named: character.name, in: roster, profiles: profiles))
        }
        for profile in profiles where profile.uid.uuidString != active {
            if excluding.contains(profile.name) || seen.contains(profile.name) { continue }
            seen.insert(profile.name)
            result.append(find(named: profile.name, in: roster, profiles: profiles))
        }
        return result
    }
}
