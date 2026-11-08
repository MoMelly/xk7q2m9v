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
    /// 资料库里有什么。切上一首/下一首靠它，播放时不用再扫一次目录。
    private(set) var queue: [Track] = []

    private let player = AVPlayer()
    private var observer: Any?

    /// 0~1。总时长还没读到时给 0，进度条不画成满格。
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(elapsed / duration, 0), 1)
    }

    /// 当前该高亮的歌词行。
    var currentLyricIndex: Int? {
        guard !lyrics.isEmpty else { return nil }
        let passed = lyrics.lastIndex { $0.time <= elapsed + 0.2 }
        return passed
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
        queue = MusicLibrary.allTracks()
    }

    /// 放这一首。已经在放它就切暂停。
    func play(_ track: Track) {
        if self.track?.id == track.id {
            toggle()
            return
        }
        guard let url = MusicLibrary.url(for: track) else { return }
        if queue.isEmpty { reloadQueue() }

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.play()

        self.track = track
        isPlaying = true
        elapsed = 0
        duration = 0
        lyrics = LyricsLoader.load(for: track)
        // 主屏组件和世界状态要跟着这个走：角色「在听」是能写进提示词的事实。
        WorldStore.shared.setCurrentTrack(track)
    }

    func toggle() {
        guard track != nil else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        track = nil
        isPlaying = false
        elapsed = 0
        duration = 0
        lyrics = []
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

    // MARK: - 截图

#if DEBUG
    /// 只摆出「有一首在放」的样子，不真的播。
    ///
    /// 仓库里没有音频文件，`play` 会因为没有 URL 直接返回，
    /// 截图流水线就拍不到球和歌词页。这里只写状态、不碰 AVPlayer。
    func stagePreview(track: Track, lyrics: [LyricLine], elapsed: Double = 62, duration: Double = 203) {
        self.track = track
        self.lyrics = lyrics
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

/// 歌词来源。
///
/// 只读音频旁边同名的 `.lrc`。没有就是没有，不做假的逐行字幕——
/// 歌词对不上唱到哪儿，比没有歌词更假。
enum LyricsLoader {
    static func load(for track: Track) -> [LyricLine] {
        guard let audio = MusicLibrary.url(for: track) else { return [] }
        let lrc = audio.deletingPathExtension().appendingPathExtension("lrc")
        guard let text = try? String(contentsOf: lrc, encoding: .utf8) else { return [] }
        return parse(text)
    }

    /// `[01:23.45]词` 一行一条，一行挂多个时间戳就复制多条。
    static func parse(_ text: String) -> [LyricLine] {
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
