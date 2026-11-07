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
    /// 现在的状态，一句话加表情名。表情名空串表示没挂。
    var statusText: String = ""
    var statusStickerName: String = ""

    /// 全是默认值时这块提示词没有信息量，干脆不写进系统提示词。
    /// 状态算信息量：哪怕别的都空着，一个「在赶作业」也值得让角色看见。
    var isBlank: Bool {
        signature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && tags.isEmpty
            && statusText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
