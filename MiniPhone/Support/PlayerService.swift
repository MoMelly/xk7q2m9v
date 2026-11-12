import Foundation
import AVFoundation
import Observation

/// 歌词的一行。
///
/// `id` 用时间而不是 UUID：同一个歌词文件每次解析出来的对象要能对上，
/// 否则滚动高亮每次重进都错位。
struct LyricLine: Identifiable, Hashable {
    let time: Double
    let text: String

    var id: Double { time }
}

/// 全 App 唯一的播放器。
///
/// 之前播放器是 `MusicScene` 的私有 `@State`，退出 App 就 `pause()`——
/// 那样做不出悬浮球，也没法让主屏组件知道「他在听什么」。
/// 现在播放状态提到这里，音乐页、悬浮球、主屏组件读的是同一份。
@Observable
@MainActor
final class PlayerService {
    static let shared = PlayerService()

    private(set) var track: Track?
    private(set) var isPlaying = false
    private(set) var elapsed: Double = 0
    private(set) var duration: Double = 0
    private(set) var lyrics: [LyricLine] = []
    /// 歌词带不带 `[mm:ss]` 时间轴。纯文本歌词没有，只能按整体进度摊开。
    private(set) var lyricsSynced = true
    /// 资料库里有什么。切上一首/下一首靠它，播放时不用再扫一次目录。
    private(set) var queue: [Track] = []

    /// 手指正按在进度条上。这期间 `elapsed` 照常被 tick 更新，
    /// 但界面读的是 `displayElapsed`，所以拖到哪显示到哪。
    private(set) var isScrubbing = false
    private var scrubTarget: Double = 0

    /// 一起听的对象。
    ///
    /// 这是个「邀请」的结果，不是自动状态：没被邀请过就一直是 nil，
    /// 界面上不显示名字，提示词里也不带这一块。邀请本身不调模型，
    /// 只是把两个人的身份对上——歌是本地放的，本来就不需要服务端。
    private(set) var partnerUID: UUID?
    private(set) var partnerName: String?

    /// 歌词页展开着没有。
    ///
    /// 这个状态原来只活在悬浮球内部，所以只有点那个球才能进歌词页；
    /// 音乐页的播放卡片点了没反应。提到这里之后，卡片和球是同一个开关。
    var lyricsPresented = false

    /// 有对象、而且这会儿真的在放，才算「在一起听」。
    /// 只邀请没放歌算半截状态：界面上照样显示名字，但不进提示词。
    var isListeningTogether: Bool {
        partnerUID != nil && isPlaying && track != nil
    }

    private let player = AVPlayer()
    private var observer: Any?

    /// 0~1。控制中心那条音量滑杆写它，写进来直接落到 AVPlayer 上。
    ///
    /// 不读系统音量：这个壳子本来就不出声地用着系统，去改系统音量会把微信语音一起改掉。
    var volume: Double = 0.7 {
        didSet {
            let clamped = min(max(volume, 0), 1)
            if clamped != volume { volume = clamped; return }
            player.volume = Float(clamped)
        }
    }

    /// 拖动时用手指位置，平时是播放位置。界面上显示的时间都读这个。
    var displayElapsed: Double {
        isScrubbing ? scrubTarget : elapsed
    }

    /// 0~1。总时长还没读到时给 0，进度条不画成满格。
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(displayElapsed / duration, 0), 1)
    }

    /// 当前该高亮的歌词行。
    var currentLyricIndex: Int? {
        guard !lyrics.isEmpty else { return nil }
        if lyricsSynced {
            return lyrics.lastIndex { $0.time <= displayElapsed + 0.2 }
        }
        // 纯文本歌词没有时间轴，按整首歌的进度摊到行上。
        guard duration > 0 else { return 0 }
        let ratio = min(max(displayElapsed / duration, 0), 0.999)
        return min(Int(ratio * Double(lyrics.count)), lyrics.count - 1)
    }

    private init() {
        let interval = CMTime(seconds: 0.4, preferredTimescale: 600)
        observer = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // 回调挂在主队列上，这里的隔离假设成立。
            MainActor.assumeIsolated {
                self?.tick(time.seconds)
            }
        }
        NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.advance()
            }
        }
    }

    // MARK: - 播放

    func reloadQueue() {
        queue = MusicMeta.apply(to: MusicLibrary.allTracks())
    }

    /// 改名之后同步正在播的那首。
    ///
    /// `Track` 是值类型，换一份新的就行；不换的话底下的播放条
    /// 和主屏组件还写着旧名字。
    func applyMeta(_ tracks: [Track]) {
        queue = tracks
        guard let current = track,
              let updated = tracks.first(where: { $0.id == current.id })
        else { return }
        track = updated
    }

    /// 放这一首。已经在放它就切暂停。
    func play(_ track: Track) {
        if self.track?.id == track.id {
            toggle()
            return
        }
        guard let url = MusicLibrary.url(for: track) else { return }
        if queue.isEmpty { reloadQueue() }

        activateSession()
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.play()

        self.track = track
        isPlaying = true
        elapsed = 0
        duration = 0
        isScrubbing = false
        let loaded = LyricsLoader.load(for: track)
        lyrics = loaded.lines
        lyricsSynced = loaded.synced
        // 主屏组件和世界状态要跟着这个走：角色「在听」是能写进提示词的事实。
        WorldStore.shared.setCurrentTrack(track)
    }

    func toggle() {
        guard track != nil else { return }
        if isPlaying {
            player.pause()
        } else {
            activateSession()
            player.play()
        }
        isPlaying.toggle()
    }

    /// 把音频会话切到播放类。
    ///
    /// 原来一行 `AVAudioSession` 都没有：AVPlayer 走默认的 soloAmbient，
    /// 手机侧面静音键一开就整首没声，锁屏也会被系统收掉。
    /// `.playback` 是唯一在静音键打开时仍然出声的分类。
    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        track = nil
        isPlaying = false
        elapsed = 0
        duration = 0
        lyrics = []
        lyricsSynced = true
        isScrubbing = false
        // 没歌了，一起听也就散了。留着名字会让界面上挂一个空的「和谁一起在听」。
        endTogether()
    }

    func next() {
        guard let index = currentIndex else { return }
        let target = queue[(index + 1) % queue.count]
        play(target)
    }

    func previous() {
        guard let index = currentIndex else { return }
        // 超过三秒按真机习惯先回到本曲开头，再按才是上一首。
        if elapsed > 3 {
            seek(to: 0)
            return
        }
        let target = queue[(index - 1 + queue.count) % queue.count]
        play(target)
    }

    func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        elapsed = seconds
    }

    // MARK: - 拖动进度

    /// 手指按下去。只记起点，不动播放器。
    func beginScrub() {
        guard duration > 0 else { return }
        isScrubbing = true
        scrubTarget = elapsed
    }

    /// 拖到 0~1 的哪个位置。只更新预览值。
    func scrub(to ratio: Double) {
        guard duration > 0 else { return }
        scrubTarget = min(max(ratio, 0), 1) * duration
    }

    /// 松手才真的跳。边拖边 seek 会让 AVPlayer 每一帧重新找位置，听着像卡带。
    func endScrub() {
        guard isScrubbing else { return }
        let target = scrubTarget
        isScrubbing = false
        seek(to: target)
    }

    /// 刚导入/删掉歌词之后重新读一遍当前这首，不用退出再进来。
    func reloadLyrics() {
        guard let track else { return }
        let loaded = LyricsLoader.load(for: track)
        lyrics = loaded.lines
        lyricsSynced = loaded.synced
    }

    // MARK: - 一起听

    /// 邀请这个角色一起听。已经邀请了另一个人就直接换——同时跟两个人一起听没有意义。
    ///
    /// 换歌不打断邀请：一起听是一段关系，不是一首歌。
    func invite(uid: UUID, name: String) {
        partnerUID = uid
        partnerName = name
    }

    func endTogether() {
        partnerUID = nil
        partnerName = nil
    }

    func isTogether(with uid: UUID) -> Bool {
        partnerUID == uid
    }

    // MARK: - 截图

#if DEBUG
    /// 只摆出「有一首在放」的样子，不真的播。
    ///
    /// 仓库里没有音频文件，`play` 会因为没有 URL 直接返回，
    /// 截图流水线就拍不到球和歌词页。这里只写状态、不碰 AVPlayer。
    func stagePreview(track: Track, lyrics: [LyricLine], elapsed: Double = 62, duration: Double = 203) {
        self.track = track
        self.lyrics = lyrics
        self.lyricsSynced = true
        self.elapsed = elapsed
        self.duration = duration
        self.isPlaying = true
    }
#endif

    // MARK: - 内部

    private var currentIndex: Int? {
        guard let track else { return nil }
        return queue.firstIndex { $0.id == track.id }
    }

    private func tick(_ seconds: Double) {
        guard isPlaying else { return }
        elapsed = seconds
        if let item = player.currentItem {
            let total = item.duration.seconds
            if total.isFinite, total > 0 {
                duration = total
            }
        }
    }

    private func advance() {
        guard !queue.isEmpty else {
            isPlaying = false
            return
        }
        next()
    }
}

/// 歌词来源：先看自己导进来的，再看音频旁边同名的 `.lrc`。
enum LyricsLoader {
    struct Loaded {
        let lines: [LyricLine]
        /// 带 `[mm:ss]` 时间轴。纯文本歌词没有，只能按播放进度摊开。
        let synced: Bool

        static let empty = Loaded(lines: [], synced: true)
    }

    static func load(for track: Track) -> Loaded {
        if let custom = LyricStore.text(for: track) {
            let parsed = parse(custom)
            if !parsed.lines.isEmpty { return parsed }
        }
        guard let audio = MusicLibrary.url(for: track) else { return .empty }
        let lrc = audio.deletingPathExtension().appendingPathExtension("lrc")
        guard let text = try? String(contentsOf: lrc, encoding: .utf8) else { return .empty }
        return parse(text)
    }

    /// 有时间轴就按时间轴；没有就按行均匀摊在整首歌上。
    ///
    /// 之前只认时间轴，纯文本歌词会被整段丢掉，用户贴进来一行都不显示，
    /// 看起来就是「导了没用」。
    static func parse(_ text: String) -> Loaded {
        let timed = parseTimed(text)
        if !timed.isEmpty { return Loaded(lines: timed, synced: true) }

        let lines = fallbackLines(text)
            .enumerated()
            .map { LyricLine(time: Double($0.offset), text: $0.element) }
        return Loaded(lines: lines, synced: false)
    }

    /// 按行拆，去掉空行和 `[ti:标题]` 这类元信息。
    private static func fallbackLines(_ text: String) -> [String] {
        text.split(separator: "\n").compactMap { raw -> String? in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return nil }
            if line.hasPrefix("["), line.contains(":"), line.hasSuffix("]") { return nil }
            return line
        }
    }

    /// `[01:23.45]词` 一行一条，一行挂多个时间戳就复制多条。
    private static func parseTimed(_ text: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        for raw in text.split(separator: "\n") {
            var rest = String(raw)
            var stamps: [Double] = []

            while rest.hasPrefix("["), let close = rest.firstIndex(of: "]") {
                let inner = String(rest[rest.index(after: rest.startIndex)..<close])
                if let seconds = seconds(from: inner) {
                    stamps.append(seconds)
                }
                rest = String(rest[rest.index(after: close)...])
            }

            let content = rest.trimmingCharacters(in: .whitespaces)
            guard !content.isEmpty, !stamps.isEmpty else { continue }
            for stamp in stamps {
                lines.append(LyricLine(time: stamp, text: content))
            }
        }
        return lines.sorted { $0.time < $1.time }
    }

    private static func seconds(from stamp: String) -> Double? {
        let parts = stamp.split(separator: ":")
        guard parts.count == 2, let minutes = Double(parts[0]) else { return nil }
        let tail = parts[1].replacingOccurrences(of: ",", with: ".")
        guard let seconds = Double(tail) else { return nil }
        return minutes * 60 + seconds
    }
}
