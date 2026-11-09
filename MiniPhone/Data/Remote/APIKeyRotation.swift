import Foundation

/// Key 轮换之后「哪把试通了」的落点。
///
/// 客户端不该知道设置存在哪儿，它只负责换一把再试。
/// 把主位换人这件事交给设置自己做——写回去之后下一个请求就带新的那把，
/// 不用等用户下次进设置页手动改。
enum APIKeyRotation {
    static func promote(_ key: String) {
        Task { @MainActor in
            SettingsStore.current?.promoteKey(key)
        }
    }
}
