import Foundation

/// 一个世界（存档）。
struct WorldMeta: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var createdAt: Date
}

/// 多存档。
///
/// 每个世界有自己的一整套东西：角色库、聊天记录、世界状态、日历、人设。
/// 做成目录隔离而不是「加一个 worldID 字段」——后者要在每一张表、每一处查询上
/// 记得带上过滤条件，漏一处就是两个世界互相串味。
///
/// 第一个世界沿用原来的存储位置（`Documents/world-state.json` 与 SwiftData 的
/// 默认库），所以老用户升级之后数据还在原地，不需要迁移，也就没有迁移丢数据的风险。
/// 新建的世界才落到 `Documents/worlds/<id>/`。
///
/// 这里不做热切换：`ModelContainer` 是进程级的，换库要重启。切换只改注册表里的
/// `active`，下一次启动读到的就是新世界。
enum WorldRegistry {
    static let defaultID = "default"

    static var rootURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("worlds", isDirectory: true)
    }

    static var indexURL: URL {
        rootURL.appendingPathComponent("index.json")
    }

    struct Index: Codable {
        var active: String
        var items: [WorldMeta]
    }

    /// 读注册表。文件不存在或读坏了就当只有一个默认世界。
    static var index: Index {
        if let data = try? Data(contentsOf: indexURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let decoded = try? decoder.decode(Index.self, from: data),
               !decoded.items.isEmpty {
                return decoded
            }
        }
        return Index(active: defaultID, items: [defaultMeta])
    }

    static var defaultMeta: WorldMeta {
        WorldMeta(id: defaultID, name: "我的世界", createdAt: Date())
    }

    static var activeID: String {
        index.active
    }

    static var active: WorldMeta {
        let current = index
        return current.items.first { $0.id == current.active }
            ?? current.items.first
            ?? defaultMeta
    }

    static var worlds: [WorldMeta] {
        index.items
    }

    /// 世界状态文件的位置。第一个世界用老路径。
    static func stateURL(for id: String) -> URL {
        if id == defaultID {
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("world-state.json")
        }
        return folder(for: id).appendingPathComponent("world-state.json")
    }

    /// SwiftData 库的位置。第一个世界返回 nil，表示用它自己的默认路径。
    static func storeURL(for id: String) -> URL? {
        guard id != defaultID else { return nil }
        return folder(for: id).appendingPathComponent("MiniPhone.store")
    }

    static func folder(for id: String) -> URL {
        let url = rootURL.appendingPathComponent(id, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - 写

    static func setActive(_ id: String) {
        var current = index
        guard current.items.contains(where: { $0.id == id }) else { return }
        current.active = id
        save(current)
    }

    @discardableResult
    static func create(name: String) -> WorldMeta {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let meta = WorldMeta(
            id: UUID().uuidString,
            name: clean.isEmpty ? "新世界" : String(clean.prefix(12)),
            createdAt: Date()
        )

        var current = index
        current.items.append(meta)
        save(current)
        _ = folder(for: meta.id)
        return meta
    }

    static func rename(_ id: String, to name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        var current = index
        guard let position = current.items.firstIndex(where: { $0.id == id }) else { return }
        current.items[position].name = String(clean.prefix(12))
        save(current)
    }

    /// 删掉一个世界。当前正在用的那个不给删——文件还开着，删了只会在下次启动时炸。
    static func delete(_ id: String) {
        guard id != defaultID, id != activeID else { return }

        var current = index
        current.items.removeAll { $0.id == id }
        save(current)

        // 注册表先落盘再删文件：反过来的话中途失败会留下一个指向空目录的世界。
        try? FileManager.default.removeItem(at: rootURL.appendingPathComponent(id, isDirectory: true))
    }

    private static func save(_ value: Index) {
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
