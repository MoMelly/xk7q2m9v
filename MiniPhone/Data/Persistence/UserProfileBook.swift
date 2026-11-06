import Foundation
import SwiftData

/// 人设的读写入口。
///
/// 「我」在这部手机里可以有多个身份，其中恰好一个被标成默认。
/// 读的时候三级兜底：会话指定的 → 默认的 → 第一个。
/// 一个都没有时由这里补一个，免得提示词里连名字都没有。
@MainActor
enum UserProfileBook {
    static func all(in context: ModelContext) -> [UserProfile] {
        let descriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\UserProfile.createdAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 会话里用的那个身份。
    static func resolve(uid: String, in context: ModelContext) -> UserProfile? {
        let profiles = all(in: context)
        if !uid.isEmpty, let matched = profiles.first(where: { $0.uid.uuidString == uid }) {
            return matched
        }
        return profiles.first(where: { $0.isDefault }) ?? profiles.first
    }

    @discardableResult
    static func ensureDefault(in context: ModelContext) -> UserProfile {
        let profiles = all(in: context)
        if let existing = profiles.first(where: { $0.isDefault }) ?? profiles.first {
            return existing
        }

        let profile = UserProfile(name: "我", isDefault: true)
        // 第一次打开就随手给一张，别让所有默认身份都是同一个字母圈。
        profile.avatarImageKey = AvatarPhoto.randomKey()
        context.insert(profile)
        try? context.save()
        return profile
    }

    /// 设为默认。默认只能有一个，所以顺手把别的清掉。
    static func makeDefault(_ profile: UserProfile, in context: ModelContext) {
        for item in all(in: context) {
            item.isDefault = (item.uid == profile.uid)
        }
        try? context.save()
    }

    /// 删掉一个身份。默认身份删掉之后把剩下最早的那个顶上去。
    static func delete(_ profile: UserProfile, in context: ModelContext) {
        let wasDefault = profile.isDefault
        context.delete(profile)
        try? context.save()

        if wasDefault, let next = all(in: context).first {
            makeDefault(next, in: context)
        }
    }
}
