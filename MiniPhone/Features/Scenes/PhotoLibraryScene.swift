import PhotosUI
import SwiftData
import SwiftUI

/// 「照片」App。
///
/// 原来只收聊天里发过的模拟图：自己一张都放不进来，打开就是「还没有照片」，
/// 看不出这个 App 是干嘛的。现在两路都收——手机里的真照片导进来，
/// 聊天里收到的图也留在同一面墙上。
struct PhotoLibraryScene: View {
    var onClose: () -> Void

    @Query private var photoMessages: [StoredMessage]

    @State private var imported: [PhotoFile] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPicker = false
    @State private var viewerIndex: Int?
    @State private var notice: String?

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        _photoMessages = Query(
            filter: #Predicate<StoredMessage> { $0.imageSeed > 0 },
            sort: [SortDescriptor(\StoredMessage.createdAt, order: .reverse)]
        )
    }

    private var entries: [PhotoEntry] {
        var list: [PhotoEntry] = imported.map { .file($0) }

        // 同一张图可能被发过多次，按种子去重，保留最新一条的时间。
        var seen: Set<Int> = []
        for message in photoMessages where seen.insert(message.imageSeed).inserted {
            list.append(.mock(seed: message.imageSeed, date: message.createdAt))
        }

        return list.sorted { $0.date > $1.date }
    }

    var body: some View {
        AppScreen(
            title: "照片",
            surface: .light,
            onClose: onClose,
            trailingSymbol: "plus",
            trailingAction: { showPicker = true }
        ) {
            Group {
                if entries.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
        }
        .photosPicker(
            isPresented: $showPicker,
            selection: $pickerItems,
            maxSelectionCount: 12,
            matching: .images
        )
        .onChange(of: pickerItems) { _, items in
            Task { await importAll(items) }
        }
        .onAppear { reload() }
        .fullScreenCover(item: Binding(
            get: { viewerIndex.map { ViewerTarget(index: $0) } },
            set: { if $0 == nil { viewerIndex = nil } }
        )) { target in
            PhotoViewer(
                entries: entries,
                index: target.index,
                onDelete: { entry in deleteEntry(entry) },
                onClose: { viewerIndex = nil }
            )
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

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3),
                spacing: 2
            ) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { offset, entry in
                    Button {
                        viewerIndex = offset
                    } label: {
                        PhotoThumb(entry: entry)
                            .aspectRatio(1, contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, PhoneMetrics.Space.m)
        }
    }

    private var emptyState: some View {
        VStack(spacing: PhoneMetrics.Space.s) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppSurface.light.secondaryLabel.opacity(0.7))

            Text("还没有照片")
                .font(.system(size: PhoneMetrics.FontSize.body, weight: .medium))
                .foregroundStyle(AppSurface.light.label)

            Text("从手机里选几张进来，聊天里收到的图也会一起排在这里。")
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(AppSurface.light.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PhoneMetrics.Space.xl)

            Button {
                showPicker = true
            } label: {
                Text("导入照片")
                    .font(.system(size: PhoneMetrics.FontSize.sub, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, PhoneMetrics.Space.l)
                    .frame(height: 40)
                    .background(Capsule().fill(Theme.tint))
            }
            .buttonStyle(.plain)
            .padding(.top, PhoneMetrics.Space.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }

    // MARK: - 行为

    private func reload() {
        imported = PhotoStore.all()
    }

    private func importAll(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        var count = 0
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            if (try? PhotoStore.save(data)) != nil { count += 1 }
        }
        pickerItems = []
        reload()
        notice = count > 0 ? "导入了 \(count) 张" : "这几张读不出来，可能没给访问权限。"
    }

    private func deleteEntry(_ entry: PhotoEntry) {
        guard case .file(let file) = entry else {
            notice = "聊天里收到的图不能在这里删，去对话里撤回。"
            return
        }
        do {
            try PhotoStore.delete(file.name)
            reload()
            notice = "删掉了这张"
        } catch {
            notice = "删不掉：\(error.localizedDescription)"
        }
    }
}

/// 相册里的一格。真实文件走 UIImage，聊天里那张按种子现画。
private struct PhotoThumb: View {
    let entry: PhotoEntry

    var body: some View {
        switch entry {
        case .mock(let seed, _):
            MockPhoto(seed: seed)
        case .file(let file):
            if let image = PhotoStore.image(named: file.name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.black.opacity(0.6)
            }
        }
    }
}

/// 全屏看大图。左右滑是同一批照片，不是单张。
private struct PhotoViewer: View {
    let entries: [PhotoEntry]
    @State var index: Int
    var onDelete: (PhotoEntry) -> Void
    var onClose: () -> Void

    @State private var confirmDelete = false

    private var current: PhotoEntry? {
        entries.indices.contains(index) ? entries[index] : nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { offset, entry in
                    PhotoThumb(entry: entry)
                        .scaledToFit()
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.white.opacity(0.16)))
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    Button {
                        confirmDelete = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.white.opacity(0.16)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .padding(.top, PhoneMetrics.Space.s)

                Spacer(minLength: 0)

                if let current {
                    Text(TimeFormat.lockDate(current.date))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.bottom, PhoneMetrics.Space.l)
                }
            }
        }
        .confirmationDialog("删除这张照片？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let current { onDelete(current) }
                onClose()
            }
            Button("取消", role: .cancel) {}
        }
    }
}

private struct ViewerTarget: Identifiable {
    let index: Int
    var id: Int { index }
}

/// 相册里的一项：本机文件，或者聊天里那张现画的图。
enum PhotoEntry: Identifiable, Hashable {
    case mock(seed: Int, date: Date)
    case file(PhotoFile)

    var id: String {
        switch self {
        case .mock(let seed, _): return "mock-\(seed)"
        case .file(let file): return "file-\(file.name)"
        }
    }

    var date: Date {
        switch self {
        case .mock(_, let date): return date
        case .file(let file): return file.date
        }
    }
}
