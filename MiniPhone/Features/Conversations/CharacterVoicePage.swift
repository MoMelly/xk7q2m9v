import AVFoundation
import SwiftUI
import SwiftData

/// 「TA 的声音」。
///
/// 音色原来是按名字哈希自动分的：同一个角色每次都是同一个嗓子，但用户没法挑，
/// 也没法回答「他念起来是什么样」。这里是那个开关的正式位置——
/// 音色是角色的属性，不是全局设置：同一个手机里，每个人本来就该是不同的人声。
///
/// 群成员各用各的：群里谁说话，就用谁自己这一页选的音色。
struct CharacterVoicePage: View {
    @Bindable var character: Companion
    let settings: SettingsStore

    @Environment(\.modelContext) private var context

    /// 试听用的那句。不带标记、不带旁白——带了会被 `spokenForm` 洗掉，
    /// 听不出音色的差别。
    private let sampleLine = "今天有点冷，你出门记得多穿一件。"

    private var voices: [AVSpeechSynthesisVoice] {
        SpeechService.chineseVoices
    }

    private var currentVoiceName: String {
        if let voice = SpeechService.voice(id: character.voiceID) {
            return SpeechService.displayName(of: voice)
        }
        return SpeechService.voiceName(for: character.name)
    }

    private var rate: Float {
        character.voiceRate > 0 ? Float(character.voiceRate) : Float(settings.voiceRate)
    }

    var body: some View {
        AppPage(title: "TA 的声音") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.section) {
                    listenSection
                    voiceSection
                    rateSection
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    // MARK: - 试听

    private var listenSection: some View {
        GroupedSection(footer: "读的时候会去掉 [表情:…] 这类标记和括号里的旁白，只念他说出口的话。") {
            Button(action: listen) {
                HStack(spacing: PhoneMetrics.Space.s) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.tint)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("听一句")
                            .font(.system(size: PhoneMetrics.FontSize.body))
                            .foregroundStyle(AppSurface.light.label)

                        Text(currentVoiceName)
                            .font(.system(size: PhoneMetrics.FontSize.caption))
                            .foregroundStyle(AppSurface.light.secondaryLabel)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: 58)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 音色

    private var voiceSection: some View {
        GroupedSection(
            "音色",
            footer: voices.isEmpty
                ? "这台设备上还没装中文音色，念的时候走系统默认中文音。"
                : "音色是系统自带的，不打包任何模型。每个人挑不同的一档，群里就听得出谁在说话。"
        ) {
            Button {
                character.voiceID = ""
                try? context.save()
                listen()
            } label: {
                row(title: "自动", detail: SpeechService.voiceName(for: character.name),
                    selected: character.voiceID.isEmpty)
            }
            .buttonStyle(.plain)

            ForEach(voices, id: \.identifier) { voice in
                RowDivider()
                Button {
                    character.voiceID = voice.identifier
                    try? context.save()
                    Haptics.select()
                    listen()
                } label: {
                    row(title: voice.name,
                        detail: languageLabel(voice),
                        selected: character.voiceID == voice.identifier)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func languageLabel(_ voice: AVSpeechSynthesisVoice) -> String {
        let localized = Locale(identifier: "zh_CN").localizedString(forIdentifier: voice.language)
        // 「中文（中国大陆）」里那个「中文」是每个音色都一样的，只留地区。
        return localized ?? voice.language
    }

    private func row(title: String, detail: String, selected: Bool) -> some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(AppSurface.light.label)

                Text(detail)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.tint)
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    // MARK: - 语速

    private var rateSection: some View {
        GroupedSection(
            "语速",
            footer: "只对这个人生效。群里每个人可以不一样，通话和朗读都用这一档。"
        ) {
            ForEach(Array(VoiceRateOption.allCases.enumerated()), id: \.offset) { index, option in
                if index > 0 { RowDivider() }

                Button {
                    character.voiceRate = option.rawValue
                    try? context.save()
                    Haptics.select()
                    listen()
                } label: {
                    HStack {
                        Text(option.title)
                            .font(.system(size: PhoneMetrics.FontSize.body))
                            .foregroundStyle(AppSurface.light.label)

                        Spacer(minLength: 0)

                        if abs(character.voiceRate - option.rawValue) < 0.005 {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.tint)
                        }
                    }
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .frame(minHeight: PhoneMetrics.Row.single)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func listen() {
        SpeechService.shared.speak(
            sampleLine,
            as: character.name,
            voiceID: character.voiceID.isEmpty ? nil : character.voiceID,
            rate: rate
        )
    }
}

/// 语速档。0 是「跟设置里的那一档」。
private enum VoiceRateOption: Double, CaseIterable {
    case follow = 0
    case slow = 0.42
    case normal = 0.48
    case fast = 0.54

    var title: String {
        switch self {
        case .follow: return "跟设置里的语速"
        case .slow: return "慢一点"
        case .normal: return "正常"
        case .fast: return "快一点"
        }
    }
}
