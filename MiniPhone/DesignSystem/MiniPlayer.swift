import SwiftUI

/// 悬浮球 + 歌词页。
///
/// 球只在这台手机上真的有歌在放时出现——没在放就什么都不显示，
/// 不留一个点了没反应的圆。球上那一圈是进度，不是装饰。
///
/// 位置在右边缘、垂直 58% 处：聊天页的输入框在底部 12%，
/// 通知横幅在顶部，这个位置两边都不挡。
struct MiniPlayerOverlay: View {
    let player: PlayerService

    /// 截图流水线要直接拍到歌词页，正常启动读不到这个键。
    @State private var expanded = UserDefaults.standard.string(forKey: "previewState") == "musicLyrics"

    var body: some View {
        ZStack {
            if expanded {
                LyricsPage(player: player) {
                    expanded = false
                }
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
                .zIndex(1)
            } else {
                ball
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: expanded)
    }

    /// 贴右边缘、垂直 58%。用 `position` 而不是 Spacer 堆：
    /// 球要能落在任意高度的页面上，不该跟着内容流走。
    private var ball: some View {
        GeometryReader { proxy in
            Button {
                expanded = true
            } label: {
                ballFace
            }
            .buttonStyle(.plain)
            .position(x: proxy.size.width - 37, y: proxy.size.height * 0.58)
        }
    }

    private var ballFace: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial)
            Circle().fill(Color.white.opacity(0.14))
            Circle().strokeBorder(Color.white.opacity(0.46), lineWidth: 0.8)

            Circle()
                .trim(from: 0, to: max(player.progress, 0.001))
                .stroke(Theme.tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(2.5)

            Image(systemName: player.isPlaying ? "waveform" : "play.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.variableColor.iterative, isActive: player.isPlaying)
        }
        .frame(width: 50, height: 50)
        .shadow(color: Color.black.opacity(0.2), radius: 9, y: 3)
        .accessibilityLabel(player.track?.title ?? "正在播放")
        .accessibilityHint("打开歌词")
    }
}

// MARK: - 歌词页

/// 整页歌词。
///
/// 不用系统 sheet：手机外壳里再弹一个系统面板，圆角和拖动条都露在外面，
/// 那层拟真就破了。这里自己做一层深色玻璃，从球的位置淡出来。
struct LyricsPage: View {
    let player: PlayerService
    var onClose: () -> Void

    private var track: Track? { player.track }

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                topBar

                cover
                    .padding(.top, PhoneMetrics.Space.l)

                titleBlock
                    .padding(.top, PhoneMetrics.Space.m)

                lyricsScroll
                    .padding(.top, PhoneMetrics.Space.m)

                controls
                    .padding(.horizontal, PhoneMetrics.Space.xl)
                    .padding(.bottom, PhoneMetrics.Space.s)

                transport
                    .padding(.bottom, PhoneMetrics.Space.l)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.glass, style: .continuous))
        .ignoresSafeArea()
    }

    private var backdrop: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(
                colors: [Color.black.opacity(0.62), Color.black.opacity(0.86)],
                startPoint: .top,
                endPoint: .bottom
            )
            // 顶部铺一点曲目封面的暖色，整页不至于死黑。
            RadialGradient(
                colors: [Theme.IconTint.pink.opacity(0.34), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 320
            )
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Text("正在播放")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))

            Spacer(minLength: 0)

            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.top, PhoneMetrics.Space.l)
    }

    private var cover: some View {
        RoundedRectangle(cornerRadius: PhoneMetrics.Radius.widget, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Theme.IconTint.pink, Theme.IconTint.orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 168, height: 168)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .shadow(color: Color.black.opacity(0.35), radius: 24, y: 10)
    }

    private var titleBlock: some View {
        VStack(spacing: 3) {
            Text(track?.title ?? "没在放")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(track?.artist ?? "")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
        .padding(.horizontal, PhoneMetrics.Space.xl)
    }

    // MARK: - 歌词

    private var lyricsScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                if player.lyrics.isEmpty {
                    noLyrics
                } else {
                    VStack(alignment: .leading, spacing: 17) {
                        ForEach(player.lyrics) { line in
                            lyricLine(line)
                                .id(line.id)
                        }
                    }
                    .padding(.horizontal, PhoneMetrics.Space.xl)
                    .padding(.vertical, 40)
                }
            }
            .frame(maxHeight: .infinity)
            .mask {
                // 上下淡出，避免歌词硬切在边缘上。
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.14),
                        .init(color: .black, location: 0.82),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .onAppear {
                guard let index = player.currentLyricIndex else { return }
                proxy.scrollTo(player.lyrics[index].id, anchor: .center)
            }
            .onChange(of: player.currentLyricIndex) { _, new in
                guard let new, player.lyrics.indices.contains(new) else { return }
                withAnimation(.easeInOut(duration: 0.32)) {
                    proxy.scrollTo(player.lyrics[new].id, anchor: .center)
                }
            }
        }
    }

    private func lyricLine(_ line: LyricLine) -> some View {
        let active = line.id == activeLyricID

        return Text(line.text)
            .font(.system(size: active ? 18 : 15, weight: active ? .semibold : .regular))
            .foregroundStyle(.white.opacity(active ? 1 : 0.4))
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.28), value: active)
    }

    /// 高亮那一行的时间戳。取不到就不亮任何一行——数组下标先查边界。
    private var activeLyricID: Double? {
        guard let index = player.currentLyricIndex,
              player.lyrics.indices.contains(index) else { return nil }
        return player.lyrics[index].id
    }

    private var noLyrics: some View {
        VStack(spacing: PhoneMetrics.Space.s) {
            Image(systemName: "text.quote")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.white.opacity(0.28))

            Text("这首歌没有歌词")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            Text("把同名 .lrc 放在音频旁边，这里就会跟着唱到哪儿滚到哪儿。")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, PhoneMetrics.Space.xl)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 控制

    private var controls: some View {
        VStack(spacing: 5) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 3.5)

                    Capsule()
                        .fill(Color.white.opacity(0.82))
                        .frame(width: max(proxy.size.width * player.progress, 3.5), height: 3.5)
                }
                .frame(height: 3.5)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            guard player.duration > 0 else { return }
                            let ratio = min(max(value.location.x / proxy.size.width, 0), 1)
                            player.seek(to: ratio * player.duration)
                        }
                )
            }
            .frame(height: 12)

            HStack {
                Text(clock(player.elapsed))
                Spacer(minLength: 0)
                Text(remaining)
            }
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(.white.opacity(0.42))
        }
    }

    private var transport: some View {
        HStack(spacing: 34) {
            Button { player.previous() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 21))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.plain)

            Button { player.toggle() } label: {
                ZStack {
                    Circle().fill(Color.white.opacity(0.94))
                        .frame(width: 58, height: 58)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.84))
                        .offset(x: player.isPlaying ? 0 : 1.5)
                }
            }
            .buttonStyle(.plain)

            Button { player.next() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 21))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, PhoneMetrics.Space.m)
    }

    private func clock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var remaining: String {
        guard player.duration > 0 else { return "-0:00" }
        return "-" + clock(max(player.duration - player.elapsed, 0))
    }
}
