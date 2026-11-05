import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

/// 音乐。
///
/// 结构照系统音乐的资料库：分组列表 + 底部常驻的正在播放条。
/// 之前只有一行「批量导入」和一条空态说明，看着不像一个 App。
/// 歌单来源两处：随包的 `Assets/Music/`，和自己导入到 Documents 的音频。
struct MusicScene: View {
    let world: WorldStore
    var onClose: () -> Void

    @State private var tracks: [Track] = []
    @State private var player: AVPlayer?
    @State private var playingID: String?
    @State private var showImporter = false
    @State private var notice: String?

    private var current: Track? {
        world.state.currentTrack
    }

    var body: some View {
        AppScreen(
            title: "音乐",
            onClose: exit,
            trailingSymbol: "plus",
            trailingAction: { showImporter = true }
        ) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: PhoneMetrics.Space.section) {
                        if tracks.isEmpty {
                            emptyLibrary
                        } else {
                            songSection
                        }
                    }
                    .padding(.top, PhoneMetrics.Space.s)
                    .padding(.bottom, PhoneMetrics.Space.l)
                }

                if let current {
                    nowPlayingBar(current)
                }
            }
        }
        .onAppear { tracks = MusicLibrary.allTracks() }
        .onDisappear { player?.pause() }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .alert("提示", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button("好") { notice = nil }
        } message: {
            Text(notice ?? "")
        }
    }

    // MARK: - 歌曲

    private var songSection: some View {
        GroupedSection(
            "歌曲",
            footer: "随包发布的是 Assets/Music/ 里那些，重装不会丢；导入的放在本机，不进备份。"
        ) {
            ForEach(tracks) { track in
                songRow(track)
                if track.id != tracks.last?.id {
                    RowDivider()
                }
            }
        }
    }

    private func songRow(_ track: Track) -> some View {
        Button {
            toggle(track)
        } label: {
            HStack(spacing: PhoneMetrics.Space.s) {
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.cover, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.IconTint.pink, Theme.IconTint.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(playingID == track.id ? Theme.tint : Theme.label)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: PhoneMetrics.FontSize.footnote))
                        .foregroundStyle(Theme.secondaryLabel)
                        .lineLimit(1)
                }

                Spacer(minLength: PhoneMetrics.Space.xs)

                Image(systemName: playingID == track.id ? "speaker.wave.2.fill" : "ellipsis")
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(playingID == track.id ? Theme.tint : Theme.secondaryLabel.opacity(0.7))
                    .frame(width: 28)
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: PhoneMetrics.Row.detailed)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(track.title)，\(track.artist)")
    }

    private var emptyLibrary: some View {
        VStack(spacing: PhoneMetrics.Space.s) {
            Image(systemName: "music.note.list")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(Theme.secondaryLabel.opacity(0.6))

            Text("资料库还是空的")
                .font(.system(size: PhoneMetrics.FontSize.body, weight: .semibold))
                .foregroundStyle(Theme.label)

            Text("把音频放进仓库的 Assets/Music/ 会随包发布，\n也可以直接导入这台设备。")
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(Theme.secondaryLabel)
                .multilineTextAlignment(.center)

            Button {
                showImporter = true
            } label: {
                Text("导入音频")
                    .font(.system(size: PhoneMetrics.FontSize.sub, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, PhoneMetrics.Space.l)
                    .frame(height: 40)
                    .background(Capsule().fill(Theme.tint))
            }
            .buttonStyle(.plain)
            .padding(.top, PhoneMetrics.Space.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PhoneMetrics.Space.xl)
    }

    // MARK: - 正在播放条

    private func nowPlayingBar(_ track: Track) -> some View {
        VStack(spacing: 0) {
            RowDivider().padding(.leading, 0)

            HStack(spacing: PhoneMetrics.Space.s) {
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.cover, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.IconTint.pink, Theme.IconTint.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title)
                        .font(.system(size: PhoneMetrics.FontSize.sub, weight: .medium))
                        .foregroundStyle(Theme.label)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(Theme.secondaryLabel)
                        .lineLimit(1)
                }

                Spacer(minLength: PhoneMetrics.Space.xs)

                Button {
                    toggle(track)
                } label: {
                    Image(systemName: playingID == track.id ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.label)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(height: 60)
        }
        .background(Theme.rowSurface)
    }

    // MARK: - 播放

    private func toggle(_ track: Track) {
        if playingID == track.id {
            player?.pause()
            playingID = nil
            return
        }

        guard let url = MusicLibrary.url(for: track) else {
            notice = "找不到这个文件，可能被移出了 Documents。"
            return
        }

        player?.pause()
        player = AVPlayer(url: url)
        player?.play()
        playingID = track.id
        world.setCurrentTrack(track)
    }

    private func exit() {
        player?.pause()
        onClose()
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            notice = "导入失败：\(error.localizedDescription)"
        case .success(let urls):
            do {
                let count = try MusicLibrary.importFiles(urls)
                tracks = MusicLibrary.allTracks()
                notice = "导入了 \(count) 首"
            } catch {
                notice = "导入失败：\(error.localizedDescription)"
            }
        }
    }
}
