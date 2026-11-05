import Foundation

/// 传给提示词的「用户是谁」。
///
/// 只带提示词用得上的字段：Domain 层不依赖 SwiftData 模型，
/// 这样提示词装配不必知道人设存在哪张表里。
struct UserIdentity: Equatable {
    var name: String
    var signature: String
    var bio: String
    var tags: [String]

    /// 全是默认值时这块提示词没有信息量，干脆不写进系统提示词。
    var isBlank: Bool {
        signature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && tags.isEmpty
    }
}
