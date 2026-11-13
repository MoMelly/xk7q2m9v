import Foundation

/// 世界状态在备份里的两份来源。
///
/// `world-state.json` 固定是默认身份那一份；其它身份各有自己的文件，
/// 落在 `identity-states/` 目录里，由 `DataBackup+Files` 整份搬走。
/// 两处都必须按「默认身份的老路径」读写，不能跟着备份时的当前身份走：
/// 否则站在哪个身份做备份，恢复后那一份就会被当成默认身份的状态。
extension DataBackup {

    static func exportWorldState(to folder: URL) throws {
        let source = WorldRegistry.stateURL(for: WorldRegistry.activeID)
        guard let snapshot = try? Data(contentsOf: source) else { return }
        try snapshot.write(
            to: folder.appendingPathComponent("world-state.json"),
            options: .atomic
        )
    }

    @discardableResult
    static func restoreWorldState(from folder: URL) -> Bool {
        let source = folder.appendingPathComponent("world-state.json")
        guard let snapshot = try? Data(contentsOf: source) else { return false }
        try? snapshot.write(
            to: WorldRegistry.stateURL(for: WorldRegistry.activeID),
            options: .atomic
        )
        return true
    }
}
