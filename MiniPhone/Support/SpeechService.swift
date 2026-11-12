import AVFoundation
import Foundation
import Observation
import Speech

/// 说话和听话。
///
/// 两件事都在系统里做，不引第三方模型：`AVSpeechSynthesizer` 自带中文音色，
/// `SFSpeechRecognizer` 支持离线识别。之前台账上写着「+110MB」是按塞一个
/// 本地 TTS 模型估的包体——用系统音色不需要打包，体积是零。
///
/// 音色按角色名做一次哈希挑一个，同一个角色每次都是同一个嗓子：
/// 换一次音色，角色就换了个人。
@Observable
@MainActor
final class SpeechService {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    private var recognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// 正在读的段落。
    private(set) var speakingName: String?
    /// 正在听，界面上那颗麦克风要变成红色。
    private(set) var isListening = false
    /// 识别到一半的文字，直接往输入框里填。
    private(set) var transcript = ""
    /// 上次失败的原因，给界面弹一句。
    var failure: String?
    /// 全局语速档。设置里选的那一档落到这里，各调用点不用各传一个数。
    var defaultRate: Float = 0.48

    var isSpeaking: Bool { speakingName != nil }

    // MARK: - 读出来

    /// 把一段回复读出来。
    ///
    /// 先洗一遍：`[表情:嫌弃]`、`[图:窗外的雨]` 这种标记读出来是噪音，
    /// 括号里的旁白也不读——那是动作，不是他说的话。
    func speak(_ text: String, as name: String, voiceID: String? = nil, rate: Float? = nil) {
        let clean = Self.spokenForm(of: text)
        guard !clean.isEmpty else { return }

        stopSpeaking()

        // 不配会话的话 TTS 走默认环境音，静音键一开就只剩嘴动没声音。
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: clean)
        // 角色自己选过音色就用它，没选过按名字挑一个固定的。
        utterance.voice = Self.voice(id: voiceID) ?? Self.voice(for: name)
        utterance.rate = rate ?? defaultRate
        utterance.pitchMultiplier = Self.pitch(for: name)
        utterance.postUtteranceDelay = 0.02

        speakingName = name
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        speakingName = nil
    }

    /// 音色表在真机上才有值；模拟器里也可能空，空了就用系统默认中文音。
    static func voice(for name: String) -> AVSpeechSynthesisVoice? {
        let chinese = chineseVoices
        guard !chinese.isEmpty else {
            return AVSpeechSynthesisVoice(language: "zh-CN")
        }
        // 用 `StableSeed`，不是 `hashValue`：后者每个进程重新播种，
        // 同一个角色重启一次就换个嗓子。
        let index = StableSeed.index(StableSeed.of(name), count: chinese.count)
        return chinese[index]
    }

    /// 系统里所有中文音色，按质量从高到低、再按名字排。
    ///
    /// 给「TA 的声音」那一页列出来挑。数量按系统装了什么变，
    /// 真机上一般有婷婷、美佳、语舒几档，模拟器里可能只有一条。
    static var chineseVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("zh") }
            .sorted { lhs, rhs in
                if lhs.quality.rawValue != rhs.quality.rawValue {
                    return lhs.quality.rawValue > rhs.quality.rawValue
                }
                return lhs.name < rhs.name
            }
    }

    static func voice(id: String?) -> AVSpeechSynthesisVoice? {
        guard let id, !id.isEmpty else { return nil }
        return AVSpeechSynthesisVoice(identifier: id)
    }

    /// 一档音色怎么写在界面上：「婷婷（中文（中国大陆））」。
    static func displayName(of voice: AVSpeechSynthesisVoice) -> String {
        let localized = Locale(identifier: "zh_CN").localizedString(forIdentifier: voice.language)
        return localized.map { "\(voice.name)（\($0)）" } ?? voice.name
    }

    /// 只要名字，不带地区。列表行尾放得下。
    static func voiceShortName(id: String?) -> String? {
        voice(id: id)?.name
    }

    /// 这个角色会用到的系统音色叫什么。
    ///
    /// 设置页要把它写出来——她问过「读出来的语音是什么」，光有一个开关
    /// 是答不上来的。取到音色就报名字，取不到说明回落到了系统中文默认音。
    static func voiceName(for name: String) -> String {
        guard let voice = voice(for: name) else { return "系统默认中文音" }
        let localized = Locale(identifier: "zh_CN").localizedString(forIdentifier: voice.language)
        return localized.map { "\(voice.name)（\($0)）" } ?? voice.name
    }

    /// 0.9–1.1 之间微调音高。同一个音色配不同音高，听感上就是两个人。
    static func pitch(for name: String) -> Float {
        let seed = StableSeed.index(StableSeed.of(name), count: 21)
        return 0.90 + Float(seed) / 100.0
    }

    /// 去掉标记和旁白，只留能读出来的句子。
    static func spokenForm(of text: String) -> String {
        var result = text
        // [表情:xxx] / [图:xxx]
        result = result.replacingOccurrences(
            of: "\\[[^\\]]*\\]",
            with: "",
            options: .regularExpression
        )
        // 括号旁白
        result = result.replacingOccurrences(
            of: "（[^）]*）|\\([^)]*\\)",
            with: "",
            options: .regularExpression
        )
        return result
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 听你说

    func startListening() {
        guard !isListening else { return }
        transcript = ""
        failure = nil

        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                guard status == .authorized else {
                    self.failure = "系统里的语音识别权限没开。去「设置 → 小手机 → 语音识别」打开。"
                    return
                }
                self.requestMicPermission()
            }
        }
    }

    private func requestMicPermission() {
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in
                guard granted else {
                    self.failure = "麦克风权限没开，听不到你说话。"
                    return
                }
                do {
                    try self.beginSession()
                } catch {
                    self.failure = error.localizedDescription
                    self.stopListening()
                }
            }
        }
    }

    private func beginSession() throws {
        let locale = Locale(identifier: "zh-CN")
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            failure = "这台设备上暂时没有中文识别器。"
            return
        }
        self.recognizer = recognizer

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // 关掉「只用离线识别」。开着的话，没下载过离线模型就直接失败；
        // 联网识别够快，边走边说的延迟可以接受。
        request.requiresOnDeviceRecognition = false

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        try engine.start()

        audioEngine = engine
        self.request = request
        isListening = true

        task = recognizer.recognitionTask(with: request) { result, error in
            Task { @MainActor in
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal { self.stopListening() }
                }
                if error != nil {
                    self.stopListening()
                }
            }
        }
    }

    func stopListening() {
        guard isListening || audioEngine != nil else { return }
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        audioEngine = nil
        request = nil
        task = nil
        isListening = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
