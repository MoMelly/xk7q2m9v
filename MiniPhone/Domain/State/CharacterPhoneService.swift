import Foundation
import Observation

/// 生成结果。不用 Result：Failure 得是 Error，这里只想带一句能直接给用户看的话。
enum CharacterPhoneOutcome {
    case success(CharacterPhone)
    case failure(String)
}

/// 他手机里那堆内容的生成。
///
/// 和聊天分开：这里是一次性把整台手机的内容要回来，不逐字上屏，
/// 所以走 `complete` 而不是 `streamChat`。生成完直接写进世界状态，
/// 界面下次进来读到的是同一份，不会每点一次换一套内容。
@Observable
@MainActor
final class CharacterPhoneService {
    static let shared = CharacterPhoneService()

    /// 正在给谁生成。界面上用它决定要不要盖一层「正在翻…」。
    private(set) var generatingOwner: String?

    var isGenerating: Bool { generatingOwner != nil }

    func generate(
        character: Companion,
        settings: SettingsStore,
        userName: String?,
        allowPrivate: Bool
    ) async -> CharacterPhoneOutcome {
        guard settings.isConfigured else {
            return .failure("还没填 API Key。点桌面上的设置填一个。")
        }
        guard generatingOwner == nil else {
            return .failure("正在生成，稍等一下。")
        }

        generatingOwner = character.name
        defer { generatingOwner = nil }

        let world = WorldStore.shared
        let request = [
            ChatMessage(role: .system, text: PromptBuilder.characterPhoneSystem),
            ChatMessage(
                role: .user,
                text: PromptBuilder.characterPhonePrompt(
                    character: character,
                    state: world.state,
                    userName: userName,
                    allowPrivate: allowPrivate
                )
            )
        ]

        let client = OpenAICompatibleClient(config: settings.config)
        do {
            let raw = try await client.complete(request)
            guard let phone = CharacterPhoneParser.parse(raw, owner: character.name) else {
                AppLog.ui.error("手机内容解析失败: \(String(raw.prefix(200)), privacy: .public)")
                return .failure("模型这次没按格式给。再点一次试试。")
            }
            world.savePhone(phone)
            return .success(phone)
        } catch {
            AppLog.ui.error("生成手机内容失败: \(error.localizedDescription, privacy: .public)")
            return .failure(error.localizedDescription)
        }
    }
}

/// 从一段可能夹着废话的回复里把 JSON 抠出来。
///
/// 提示词说了只输出 JSON，但模型常常还是会加一句「好的，这是内容：」或者套个代码块。
/// 这里从第一个 `{` 到最后一个 `}` 截一段再解，解不出来就是失败 —— 不猜、不补内容。
enum CharacterPhoneParser {
    static func parse(_ raw: String, owner: String) -> CharacterPhone? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end {
            text = String(text[start...end])
        }
        guard let data = text.data(using: .utf8),
              var phone = try? JSONDecoder().decode(CharacterPhone.self, from: data) else {
            return nil
        }
        if phone.owner.isEmpty { phone.owner = owner }
        phone.generatedAt = Date()
        return phone.isEmpty ? nil : phone
    }
}
