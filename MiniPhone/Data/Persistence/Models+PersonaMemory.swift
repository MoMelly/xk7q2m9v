import Foundation

/// 摘要按身份分开存。
///
/// 从 `Models.swift` 拆出来是因为那边已经贴着 600 行上限。这几个都是
/// 计算属性、不落库，放在扩展里和放在模型里是一回事。
extension Companion {
    /// `memoryByPersonaRaw` 的字典形态。
    var memoryByPersona: [String: String] {
        get {
            guard let data = memoryByPersonaRaw.data(using: .utf8) else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            memoryByPersonaRaw = (try? JSONEncoder().encode(newValue))
                .flatMap { String(data: $0, encoding: .utf8) } ?? ""
        }
    }

    /// 当前身份看到的那份摘要。空串表示这个身份还没攒出记忆。
    var activeMemorySummary: String {
        let scope = IdentityScope.storedUID
        return scope.isEmpty ? memorySummary : (memoryByPersona[scope] ?? "")
    }

    func setActiveMemorySummary(_ text: String) {
        let scope = IdentityScope.storedUID
        guard !scope.isEmpty else {
            memorySummary = text
            return
        }
        var map = memoryByPersona
        map[scope] = text
        memoryByPersona = map
    }
}
