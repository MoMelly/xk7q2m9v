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
    /// 播放状态在 `PlayerService` 里，退出这个页面不会停——悬浮球接着放。
    private var player: PlayerService { .shared }
    @State private var showImporter = false
    @State private var notice: String?
    /// 点行尾「…」打开的那首歌。
    @State private var menuTarget: Track?
    /// 等二次确认的删除目标。
    @State private var deleteTarget: Track?
    /// 这一页的 sheet 只有一个出口：导入歌词和重命名共用它。
    /// 同一个视图挂两个 `.sheet` 时系统只认最后一个。
    @State private var sheet: MusicSheet?

    private enum MusicSheet: Identifiable {
        case lyrics(Track)
        case rename(Track)

        var id: String {
            switch self {
            case .lyrics(let track): return "lyrics-\(track.id)"
            case .rename(let track): return "rename-\(track.id)"
            }
        }
    }

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
        .onAppear {
            reload()
            player.reloadQueue()
        }
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
        .confirmationDialog(
            "这首歌",
            isPresented: Binding(
                get: { menuTarget != nil },
                set: { if !$0 { menuTarget = nil } }
            ),
            presenting: menuTarget
        ) { track in
            Button("现在播放") { toggle(track) }
            Button("重命名") { sheet = .rename(track) }
            Button("导入歌词") { sheet = .lyrics(track) }
            if MusicLibrary.isDeletable(track) {
                Button("删除这首歌", role: .destructive) { deleteTarget = track }
            }
            Button("取消", role: .cancel) { menuTarget = nil }
        } message: { track in
            Text(track.title)
        }
        .alert(
            "删除这首歌？",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            presenting: deleteTarget
        ) { track in
            Button("删除", role: .destructive) { performDelete(track) }
            Button("取消", role: .cancel) { deleteTarget = nil }
        } message: { track in
            Text("「\(track.title)」会从这台设备上删掉，配的歌词一起清掉。随包发布的歌删不了。")
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .lyrics(let track):
                LyricImportSheet(track: track) {
                    player.reloadLyrics()
                }
            case .rename(let track):
                TrackRenameSheet(
                    track: track,
                    onSave: { title, artist in
                        MusicMeta.rename(track.id, title: title, artist: artist)
                        reload()
                    },
                    onReset: {
                        MusicMeta.reset(track.id)
                        reload()
                    }
                )
            }
        }
    }

    /// 重读曲库。改名之后列表和正在播放的那条都要跟着换，
    /// 不然底下的播放条还写着旧名字。
    private func reload() {
        tracks = MusicMeta.apply(to: MusicLibrary.allTracks())
        player.applyMeta(tracks)
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
        HStack(spacing: 0) {
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
                            .foregroundStyle(player.track?.id == track.id ? Theme.tint : Theme.label)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.system(size: PhoneMetrics.FontSize.footnote))
                            .foregroundStyle(Theme.secondaryLabel)
                            .lineLimit(1)
                    }

                    Spacer(minLength: PhoneMetrics.Space.xs)
                }
                .padding(.leading, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.detailed)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(track.title)，\(track.artist)")

            // 行尾这颗原来只是装饰：画了个「…」，点下去还是播放，删不掉也导不了歌词。
            // 现在它是真的菜单入口。
            Button {
                menuTarget = track
            } label: {
                Image(systemName: playingID(of: track) ? "speaker.wave.2.fill" : "ellipsis")
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(playingID(of: track) ? Theme.tint : Theme.secondaryLabel.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("更多，\(track.title)")
        }
        .padding(.trailing, PhoneMetrics.Space.xs)
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
            HStack(spacing: PhoneMetrics.Space.s) {
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.cover, style: .continuous)
                    .fill(TrackArt.gradient(for: track.id))
                    .frame(width: 44, height: 44)
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
                    Image(systemName: playingID(of: track) && player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.label)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(height: 56)
            // 点封面或标题就进歌词页。之前只有那个悬浮球能进，
            // 这张卡片点了没反应——她说的「不合理」就是这条。
            .contentShape(Rectangle())
            .onTapGesture { player.lyricsPresented = true }

            HStack(spacing: PhoneMetrics.Space.s) {
                Text(clock(player.displayElapsed))
                    .frame(width: 34, alignment: .leading)

                SeekBar(
                    progress: player.progress,
                    isScrubbing: player.isScrubbing,
                    trackColor: Color.white.opacity(0.28),
                    fillColor: .white,
                    thumbColor: .white,
                    barHeight: 3,
                    hitHeight: 26,
                    onScrubBegan: { player.beginScrub() },
                    onScrub: { player.scrub(to: $0) },
                    onScrubEnded: { player.endScrub() }
                )

                Text(remaining)
                    .frame(width: 42, alignment: .trailing)
            }
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(.white.opacity(0.62))
            .padding(.horizontal, PhoneMetrics.Space.m)
            .padding(.bottom, 8)
            .allowsHitTesting(true)
        }
        // 原来是一块实色。改成液态玻璃：半透明材质 + 一层薄白 + 一圈高光边，
        // 底下的列表和壁纸从缝里透上来。
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                    .fill(Color.black.opacity(0.28))
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8)
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.s)
        .padding(.bottom, PhoneMetrics.Space.xs)
    }

    private func clock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var remaining: String {
        guard player.duration > 0 else { return "-0:00" }
        return "-" + clock(max(player.duration - player.displayElapsed, 0))
    }

    private func performDelete(_ track: Track) {
        do {
            if player.track?.id == track.id { player.stop() }
            try MusicLibrary.delete(track)
            tracks = MusicLibrary.allTracks()
            player.reloadQueue()
            notice = "删了「\(track.title)」"
        } catch {
            notice = "删不掉：\(error.localizedDescription)"
        }
    }

    // MARK: - 播放

    /// 是不是这一首在放（暂停也算「当前这首」）。
    private func playingID(of track: Track) -> Bool {
        player.track?.id == track.id
    }

    private func toggle(_ track: Track) {
        guard playingID(of: track) || MusicLibrary.url(for: track) != nil else {
            notice = "找不到这个文件，可能被移出了 Documents。"
            return
        }
        player.play(track)
    }

    private func exit() {
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
