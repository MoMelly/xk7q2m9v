import SwiftUI
import SwiftData
import AVFoundation
import UniformTypeIdentifiers

/// 只读场景页的种类。
///
/// 八个页面共用一套卡片和背景，避免为「日历」「购物」各写一份布局。
/// 数据全部来自 WorldStore 或本机已有实体，不额外调用模型。
enum SceneKind: String, Hashable, CaseIterable, Identifiable {
    case calendar
    case notes
    case photos
    case calls
    case health
    case music
    case shopping
    case forum

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: return "日历"
        case .notes: return "备忘录"
        case .photos: return "相册"
        case .calls: return "通话记录"
        case .health: return "健康"
        case .music: return "音乐"
        case .shopping: return "购物"
        case .forum: return "论坛"
        }
    }

    var symbol: String {
        switch self {
        case .calendar: return "calendar"
        case .notes: return "note.text"
        case .photos: return "photo.fill"
        case .calls: return "phone.fill"
        case .health: return "heart.fill"
        case .music: return "music.note"
        case .shopping: return "bag.fill"
        case .forum: return "bubble.left.and.bubble.right.fill"
        }
    }
}

struct ScenePage: View {
    let kind: SceneKind
    @Bindable var settings: SettingsStore
    let world: WorldStore
    var onExit: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\MomentPost.createdAt, order: .reverse)])
    private var moments: [MomentPost]

    @State private var tracks: [Track] = []
    @State private var player: AVPlayer?
    @State private var showMusicImporter = false
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    content
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.settingsBackground.ignoresSafeArea())
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        player?.pause()
                        onExit()
                    }
                }
            }
            .onAppear {
                world.seedSceneContentIfNeeded()
                reloadTracks()
            }
            .fileImporter(
                isPresented: $showMusicImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                handleMusicImport(result)
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
    }

    // MARK: - 页头

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.retroGreen)
                Text(kind.title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryInk)
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var subtitle: String {
        switch kind {
        case .calendar: return "每天一份，聊天时会自然带到，不会主动推送"
        case .notes: return "它记住的事，单聊和群聊读的是同一份"
        case .photos: return "动态墙里的条目"
        case .calls: return "只作界面记录，不拨号"
        case .health: return "角色能查到的手机状态，默认关闭"
        case .music: return "随包歌单 + 自己导入的音频"
        case .shopping: return "本地清单，不涉及支付"
        case .forum: return "本地帖子，不联网"
        }
    }

    // MARK: - 内容分发

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .calendar: calendarRows
        case .notes: notesRows
        case .photos: photosRows
        case .calls: callRows
        case .health: healthRows
        case .music: musicRows
        case .shopping: shoppingRows
        case .forum: forumRows
        }
    }

    private var calendarRows: some View {
        Group {
            let items = world.state.schedule?.items ?? []
            if items.isEmpty {
                emptyRow("今天还没有生成日程")
            } else {
                ForEach(items) { item in
                    row(
                        title: item.title,
                        subtitle: item.note,
                        detail: "\(item.timeText) · \(item.mood.label)",
                        symbol: item.mood.symbol
                    )
                }
                moodRow
            }
        }
    }

    private var moodRow: some View {
        let mood = world.state.mood
        return row(
            title: "当前状态",
            subtitle: mood?.reason ?? "还没有状态",
            detail: mood?.mood.label ?? "—",
            symbol: mood?.mood.symbol ?? "circle.dashed"
        )
    }

    private var notesRows: some View {
        Group {
            let facts = world.state.people
                .flatMap(\.facts)
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(30)
            if facts.isEmpty {
                emptyRow("还没有跨会话记住的事")
            } else {
                ForEach(Array(facts)) { fact in
                    row(
                        title: fact.text,
                        subtitle: fact.sourceName,
                        detail: TimeFormat.monthDayTime(fact.createdAt),
                        symbol: "bookmark.fill"
                    )
                }
            }
        }
    }

    private var photosRows: some View {
        Group {
            if moments.isEmpty {
                emptyRow("动态墙还是空的")
            } else {
                ForEach(Array(moments.prefix(20))) { post in
                    row(
                        title: post.text,
                        subtitle: post.characterName,
                        detail: TimeFormat.monthDayTime(post.createdAt),
                        symbol: "photo.fill"
                    )
                }
            }
        }
    }

    private var callRows: some View {
        let names = ["未知号码", "妈妈", "快递", "同事"]
        let kinds = ["未接来电", "呼出 3 分钟", "呼入 1 分钟", "未接来电"]
        return Group {
            ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                row(
                    title: name,
                    subtitle: kinds[index],
                    detail: TimeFormat.monthDayTime(Date().addingTimeInterval(-Double(index + 1) * 7_200)),
                    symbol: "phone.fill"
                )
            }
        }
    }

    private var healthRows: some View {
        Group {
            Toggle("允许角色查手机", isOn: $settings.allowPhoneLookups)
                .font(.system(size: 14))
                .padding(14)
                .whiteCard()
                .onChange(of: settings.allowPhoneLookups) { _, _ in settings.persist() }

            if settings.allowPhoneLookups {
                ForEach(DeviceSnapshot.lines(allowPhoneLookups: true), id: \.self) { line in
                    row(title: line, subtitle: "来自这台设备", detail: "", symbol: "iphone")
                }
                ForEach(world.state.usage.sorted { $0.seconds > $1.seconds }, id: \.appName) { item in
                    row(
                        title: item.appName,
                        subtitle: "在这个小手机里打开过",
                        detail: "\(Int(item.seconds / 60)) 分钟",
                        symbol: "clock.fill"
                    )
                }
            } else {
                emptyRow("关闭时，电量、机型、使用记录都不会进提示词")
            }
        }
    }

    private var musicRows: some View {
        Group {
            Button {
                showMusicImporter = true
            } label: {
                row(
                    title: "批量导入歌单",
                    subtitle: "多选音频文件；随包发布的那部分不用导入",
                    detail: "＋",
                    symbol: "square.and.arrow.down.fill"
                )
            }
            .buttonStyle(.plain)

            ForEach(tracks) { track in
                Button {
                    play(track)
                } label: {
                    row(
                        title: track.title,
                        subtitle: track.artist,
                        detail: world.state.currentTrack?.id == track.id ? "正在播放" : "▶",
                        symbol: "music.note"
                    )
                }
                .buttonStyle(.plain)
            }

            if tracks.isEmpty {
                emptyRow("把歌单放进仓库的 Assets/Music/ 后会随包发布，也可以直接导入")
            }
        }
    }

    private var shoppingRows: some View {
        Group {
            ForEach(world.state.shopping) { item in
                row(
                    title: item.title,
                    subtitle: item.status,
                    detail: item.price,
                    symbol: "bag.fill"
                )
            }
        }
    }

    private var forumRows: some View {
        Group {
            ForEach(world.state.forum) { post in
                row(
                    title: post.title,
                    subtitle: "\(post.author)：\(post.body)",
                    detail: "\(post.replyCount) 回复",
                    symbol: "bubble.left.fill"
                )
            }
        }
    }

    // MARK: - 统一卡片

    private func row(title: String, subtitle: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.retroGreen)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondaryInk)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 6)

            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .whiteCard()
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.secondaryInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .whiteCard()
    }

    // MARK: - 动作

    private func reloadTracks() {
        tracks = MusicLibrary.allTracks()
    }

    private func play(_ track: Track) {
        guard let url = MusicLibrary.url(for: track) else { return }
        player?.pause()
        player = AVPlayer(url: url)
        player?.play()
        world.setCurrentTrack(track)
    }

    private func handleMusicImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            notice = "导入失败：\(error.localizedDescription)"
        case .success(let urls):
            do {
                let count = try MusicLibrary.importFiles(urls)
                reloadTracks()
                notice = "导入了 \(count) 首"
            } catch {
                notice = "导入失败：\(error.localizedDescription)"
            }
        }
    }
}

