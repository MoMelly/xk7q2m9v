import Foundation
import SwiftUI
import AVFoundation

/// 本地视频壁纸。静音循环，铺满裁切，退到后台暂停播放。
///
/// 视频文件放在 Documents/Wallpapers/wallpaper.mov，不进 ipa，
/// 由「设置 → 视频壁纸」导入，并随备份导出（见 DataBackup）。
struct VideoWallpaperView: UIViewRepresentable {
    let url: URL
    @Environment(\.scenePhase) private var scenePhase

    func makeUIView(context: Context) -> LoopingPlayerView {
        let view = LoopingPlayerView()
        view.play(url: url)
        return view
    }

    func updateUIView(_ uiView: LoopingPlayerView, context: Context) {
        if scenePhase == .active {
            uiView.resume()
        } else {
            uiView.pause()
        }
    }
}

final class LoopingPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var currentURL: URL?

    func play(url: URL) {
        guard currentURL != url, FileManager.default.fileExists(atPath: url.path) else { return }
        currentURL = url

        guard let playerLayer = layer as? AVPlayerLayer else { return }
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill

        player.removeAllItems()
        player.isMuted = true
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        player.play()
    }

    func pause() { player.pause() }

    func resume() { player.play() }

    func stop() {
        player.pause()
        player.removeAllItems()
        looper?.disableLooping()
        looper = nil
    }
}

enum VideoWallpaperStore {
    static let fileName = "wallpaper.mov"

    static var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Wallpapers", isDirectory: true)
    }

    static var fileURL: URL {
        directory.appendingPathComponent(fileName)
    }

    static var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// 从 fileImporter 给的安全作用域 URL 复制到沙盒。
    static func importFrom(_ source: URL) throws {
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        try FileManager.default.copyItem(at: source, to: fileURL)
    }

    static func replace(with data: Data) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    static func remove() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
