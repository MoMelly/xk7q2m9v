import SwiftUI

/// 主屏图标区：分页、长按抖动、拖动换位、拖到一起建文件夹。
///
/// 布局数据在 `HomeLayout` 里，这里只管画和手势。分成两层是因为
/// 拖动过程中会反复改布局——如果视图自己持有顺序，拖动一次要重建一棵树。
struct HomeBoard: View {
    @Binding var layout: HomeLayout
    @Binding var page: Int
    @Binding var editing: Bool
    let onOpen: (PhoneApp) -> Void

    /// 拖动中的那一格。
    @State private var dragging: String?
    @State private var dragLocation: CGPoint = .zero
    @State private var openFolder: HomeSlot.Folder?
    /// 翻页用的瞬时位移。松手后归零，由 `page` 接手。
    @State private var swipeOffset: CGFloat = 0

    private var pages: [[HomeSlot]] { layout.pages }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, slots in
                    pageView(slots, index: index, size: size)
                        .frame(width: size.width, height: size.height)
                        .offset(x: CGFloat(index - page) * size.width + swipeOffset)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .leading)
            .coordinateSpace(name: "homeBoard")
            .clipped()
            .contentShape(Rectangle())
            .gesture(pagingGesture(size: size))
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                    withAnimation(.easeOut(duration: 0.18)) { editing = true }
                }
            )
            .simultaneousGesture(exitEditingTap)
        }
        .frame(height: PhoneBoardMetrics.boardHeight)
        .sheet(item: $openFolder) { folder in
            FolderPanel(
                folderID: folder.id,
                title: folder.title,
                appIDs: folder.appIDs,
                onOpen: { app in
                    openFolder = nil
                    onOpen(app)
                },
                onRename: { layout.rename(folderID: folder.id, to: $0) },
                onUngroup: { layout.ungroup(folderID: folder.id) }
            )
        }
        .onChange(of: pages.count) { _, newValue in
            if page >= newValue { page = max(0, newValue - 1) }
        }
    }

    // MARK: - 一页

    private func pageView(_ slots: [HomeSlot], index: Int, size: CGSize) -> some View {
        let metrics = PhoneBoardMetrics(size: size)

        return ZStack(alignment: .topLeading) {
            ForEach(Array(slots.enumerated()), id: \.element.id) { position, slot in
                slotView(slot, editing: editing, jigglePhase: position)
                    .frame(width: metrics.cellWidth, height: metrics.cellHeight)
                    .offset(metrics.origin(at: position))
                    .zIndex(dragging == slot.id ? 10 : 0)
                    .scaleEffect(dragging == slot.id ? 1.12 : 1)
                    .offset(dragging == slot.id ? dragOffset(from: metrics, position: position) : .zero)
                    .gesture(iconGesture(slot: slot, page: index, metrics: metrics, size: size))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func dragOffset(from metrics: PhoneBoardMetrics, position: Int) -> CGSize {
        let origin = metrics.origin(at: position)
        return CGSize(
            width: dragLocation.x - origin.x - metrics.cellWidth / 2,
            height: dragLocation.y - origin.y - metrics.cellHeight / 2
        )
    }

    // MARK: - 一格

    @ViewBuilder
    private func slotView(_ slot: HomeSlot, editing: Bool, jigglePhase: Int) -> some View {
        switch slot {
        case .app(let appID):
            if let app = app(id: appID) {
                VStack(spacing: 5) {
                    Button {
                        guard !editing else { return }
                        onOpen(app)
                    } label: {
                        AppIconTile(app: app).iconFrame(app)
                    }
                    .buttonStyle(IconPressStyle())
                    .allowsHitTesting(!editing)
                    .overlay(alignment: .topLeading) {
                        if editing { removeBadge { remove(appID) } }
                    }

                    Text(app.name)
                        .font(.system(size: 11))
                        .foregroundStyle(iconLabelColor)
                        .lineLimit(1)
                }
                .jiggle(editing, phase: jigglePhase)
            }

        case .folder(let folder):
            VStack(spacing: 5) {
                Button {
                    guard !editing else { return }
                    openFolder = folder
                } label: {
                    FolderTile(apps: folder.appIDs.compactMap { app(id: $0) })
                }
                .buttonStyle(IconPressStyle())
                .allowsHitTesting(!editing)
                .overlay(alignment: .topLeading) {
                    if editing { removeBadge { layout.ungroup(folderID: folder.id) } }
                }

                Text(folder.title)
                    .font(.system(size: 11))
                    .foregroundStyle(iconLabelColor)
                    .lineLimit(1)
            }
            .jiggle(editing, phase: jigglePhase)
        }
    }

    private func removeBadge(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 19))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.black.opacity(0.55))
                .offset(x: -7, y: -7)
        }
        .buttonStyle(.plain)
    }

    private var iconLabelColor: Color {
        ThemeStore.shared.isNight ? Color.white : Color(red: 0.16, green: 0.15, blue: 0.17)
    }

    private func app(id: String) -> PhoneApp? {
        AppCatalog.home.first { $0.id == id } ?? AppCatalog.dock.first { $0.id == id }
    }

    // MARK: - 手势：翻页

    private func pagingGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !editing, dragging == nil else { return }
                swipeOffset = value.translation.width * 0.55
            }
            .onEnded { value in
                guard !editing, dragging == nil else {
                    swipeOffset = 0
                    return
                }
                let threshold: CGFloat = 46
                var target = page
                if value.translation.width < -threshold { target = min(pages.count - 1, page + 1) }
                if value.translation.width > threshold { target = max(0, page - 1) }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    swipeOffset = 0
                    page = target
                }
            }
    }

    /// 编辑模式下点空白退出。真机是点一下桌面任意位置。
    private var exitEditingTap: some Gesture {
        TapGesture()
            .onEnded {
                guard editing else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    editing = false
                    dragging = nil
                }
            }
    }

    // MARK: - 手势：拖一格

    private func iconGesture(
        slot: HomeSlot,
        page pageIndex: Int,
        metrics: PhoneBoardMetrics,
        size: CGSize
    ) -> some Gesture {
        // 用整块板的坐标系：手势挂在每一格上，`.local` 拿到的是那一格自己的
        // 角落，既算不出落点也判断不了「拖出边界翻页」。
        DragGesture(minimumDistance: 8, coordinateSpace: .named("homeBoard"))
            .onChanged { value in
                guard editing else { return }
                // 第一次动起来就直接拖：不需要再按一次。
                if dragging == nil {
                    dragging = slot.id
                }
                dragLocation = value.location
            }
            .onEnded { value in
                guard editing, dragging == slot.id else {
                    dragging = nil
                    return
                }
                let landing = value.location
                // 拖到左/右边界外面 → 换到相邻页。
                if landing.x < -18 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        layout.move(slot.id, toPage: pageIndex - 1, at: nil)
                        page = max(0, pageIndex - 1)
                    }
                    dragging = nil
                    return
                }
                if landing.x > size.width + 18 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        layout.move(slot.id, toPage: pageIndex + 1, at: nil)
                        page = min(pages.count - 1, pageIndex + 1)
                    }
                    dragging = nil
                    return
                }

                let target = metrics.slotIndex(at: landing)
                let slots = pages[safe: pageIndex] ?? []
                if let target, target < slots.count {
                    let other = slots[target]
                    if other.id != slot.id {
                        if other.isFolder || slot.isFolder {
                            // 拖进文件夹：单独处理，保持文件夹名。
                            appendIntoFolder(slot: slot, folder: other, page: pageIndex)
                        } else {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                                layout.merge(slot.id, into: other.id)
                            }
                        }
                    }
                } else if let target {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                        layout.move(slot.id, toPage: pageIndex, at: target)
                    }
                }

                dragging = nil
                layout.save()
            }
    }

    /// 把一个图标塞进已有文件夹。
    private func appendIntoFolder(slot: HomeSlot, folder other: HomeSlot, page pageIndex: Int) {
        guard case .folder(let target) = other else { return }
        let incoming = slot.appIDs
        var merged = target.appIDs
        for appID in incoming where !merged.contains(appID) {
            merged.append(appID)
        }
        let replacement = HomeSlot.folder(
            HomeSlot.Folder(id: target.id, title: target.title, appIDs: merged)
        )
        withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
            if let at = pages[safe: pageIndex]?.firstIndex(where: { $0.id == other.id }) {
                var next = layout
                next.pages[pageIndex][at] = replacement
                if let movingAt = next.locate(slot.id) {
                    next.pages[movingAt.page].remove(at: movingAt.index)
                }
                layout = next
            }
        }
    }

    private func remove(_ appID: String) {
        var next = layout
        for pageIndex in next.pages.indices {
            if let index = next.pages[pageIndex].firstIndex(where: { $0.appIDs == [appID] }) {
                next.pages[pageIndex].remove(at: index)
                break
            }
        }
        withAnimation(.easeOut(duration: 0.2)) { layout = next }
        layout.save()
    }
}

// MARK: - 度量

/// 一页里每一格的位置。手势命中判定和画图用同一份，懒得两边对不齐。
struct PhoneBoardMetrics {
    let size: CGSize
    let columns = PhoneMetrics.gridColumns
    let hSpacing = PhoneMetrics.gridHorizontalSpacing
    let vSpacing = PhoneMetrics.gridVerticalSpacing

    var cellWidth: CGFloat {
        (size.width - CGFloat(columns - 1) * hSpacing) / CGFloat(columns)
    }

    var cellHeight: CGFloat {
        PhoneMetrics.iconSize + 18
    }

    /// 两行。上面还有三块组件，三行会顶到 Dock。
    static let rows = 2
    static var boardHeight: CGFloat {
        let cell = PhoneMetrics.iconSize + 18
        return cell * CGFloat(rows) + PhoneMetrics.gridVerticalSpacing * CGFloat(rows - 1)
    }

    func origin(at index: Int) -> CGPoint {
        let col = index % columns
        let row = index / columns
        return CGPoint(
            x: CGFloat(col) * (cellWidth + hSpacing),
            y: CGFloat(row) * (cellHeight + vSpacing)
        )
    }

    /// 落在哪一格。超出一页范围返回 nil。
    func slotIndex(at point: CGPoint) -> Int? {
        let col = Int((point.x / (cellWidth + hSpacing)).rounded(.down))
        let row = Int((point.y / (cellHeight + vSpacing)).rounded(.down))
        guard (0..<columns).contains(col), (0..<PhoneBoardMetrics.rows).contains(row) else {
            return nil
        }
        return row * columns + col
    }
}

// MARK: - 抖动

private struct JiggleEffect: ViewModifier {
    let active: Bool
    let phase: Int

    @State private var swing = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(active ? (swing ? 1.1 : -1.1) : 0))
            .animation(
                active
                    ? .easeInOut(duration: 0.16).repeatForever(autoreverses: true)
                        .delay(Double(phase % 3) * 0.03)
                    : .easeOut(duration: 0.12),
                value: swing
            )
            .onChange(of: active) { _, now in
                swing = now
            }
    }
}

extension View {
    func jiggle(_ active: Bool, phase: Int) -> some View {
        modifier(JiggleEffect(active: active, phase: phase))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
