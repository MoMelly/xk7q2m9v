import Foundation
import SwiftData

/// 数据库容器。
///
/// 用 SwiftData 而不是手写 SQLite：模型少、关系简单，代码量只有 C API 的十分之一。
/// 代价是迁移过程不透明——所以真正开始改字段结构时，要在这里加
/// `VersionedSchema`，而不是直接改属性。
enum AppStore {
    static let schema = Schema([
        Companion.self,
        StoredMessage.self,
        MomentPost.self,
        WorldEntry.self,
        NoteItem.self
    ])

    /// 落盘的容器。建不出来时退回内存模式，让 App 还能打开——
    /// 打不开比丢数据更让人无从下手。
    static let container: ModelContainer = {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            AppLog.storage.error("持久化容器创建失败，退回内存模式: \(error.localizedDescription, privacy: .public)")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // 内存容器几乎不可能失败；真失败说明 Schema 本身写错了，属于开发期错误。
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }()
}
