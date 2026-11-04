import Foundation

/// 一条消息。P0 阶段只保留最小字段，P2 接入数据库时会扩展为持久化实体。
struct ChatMessage: Identifiable, Equatable {
    enum Role: String, Codable {
        case system
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var text: String
    let createdAt: Date

    init(id: UUID = UUID(), role: Role, text: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}
