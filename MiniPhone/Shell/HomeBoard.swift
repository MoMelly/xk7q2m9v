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
    /// 按下时手指的点。图标按相对位移跟手，才不会在第一次 `onChanged`
    /// 就瞬移到手指下面——那一下跳完就再也看不出「我把图标拎起来了」。
    @State private var dragOrigin: CGPoint = .zero
    @State private var dragStartedAt: Date?
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
                    .offset(x: metrics.origin(at: position).x, y: metrics.origin(at: position).y)
                    .zIndex(dragging == slot.id ? 10 : 0)
                    // 拎起来的样子：放大一点、投影加深、跟手平移。
                    // 原来只有 1.12 的缩放，没有影子也没有位移差，
                    // 拖起来跟没拖一样——看不出这颗图标是「活的」。
                    .scaleEffect(dragging == slot.id ? 1.15 : 1)
                    .animation(.spring(response: 0.26, dampingFraction: 0.74), value: dragging)
                    .shadow(
                        color: .black.opacity(dragging == slot.id ? 0.32 : 0),
                        radius: dragging == slot.id ? 18 : 0,
                        y: dragging == slot.id ? 10 : 0
                    )
                    // offset 放在 animation 之后：拖动位移不能有动画，
                    // 否则图标是「追」手指，慢半拍，看着就像没跟上。
                    .offset(dragging == slot.id ? dragTranslation : .zero)
                    .gesture(iconGesture(slot: slot, page: index, metrics: metrics, size: size))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// 手指相对按下位置的位移。跟手用它，落点另算。
    private var dragTranslation: CGSize {
        CGSize(
            width: dragLocation.x - dragOrigin.x,
            height: dragLocation.y - dragOrigin.y
        )
    }

    // MARK: - 一格

    @ViewBuilder
    private func slotView(_ slot: HomeSlot, editing: Bool, jigglePhase: Int) -> some View {
        switch slot {
        case .app(let appID):
            if let app = app(id: appID) {
                // 名字由 `AppIconTile` 自己画：它还要按 `HomeTextInk` 决定黑白
                // 和那圈描边阴影。这里再补一行就是两个名字叠在同一个位置。
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
                .font(.system(size: 18))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.black.opacity(0.62))
                // 命中区放大到 28，但图形只 18：原来 19 的图形压在图标左上角
                // 那一块本来就有的描边里，看起来像和图标糊在一起。
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .offset(x: -11, y: -11)
        }
        .buttonStyle(.plain)
    }

    private var iconLabelColor: Color {
        ThemeStore.shared.isNight ? Color.white : Theme.IconSurface.labelDay
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
                    dragOrigin = value.startLocation
                    dragStartedAt = Date()
                }
                dragLocation = value.location
            }
            .onEnded { value in
                guard editing, dragging == slot.id else {
                    dragging = nil
                    return
                }
                // 落盘放在 defer 里：下面有三条返回路径，漏一条布局就白拖了——
                // 拖到边界换页那两条原来就漏了，重启之后图标回到原位。
                defer {
                    dragging = nil
                    layout.save()
                }
                let landing = value.location
                // 拖到左/右边界外面 → 换到相邻页。
                if landing.x < -18 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        layout.move(slot.id, toPage: pageIndex - 1, at: nil)
                        page = max(0, pageIndex - 1)
                    }
                    return
                }
                if landing.x > size.width + 18 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        layout.move(slot.id, toPage: pageIndex + 1, at: nil)
                        page = min(max(0, pages.count - 1), pageIndex + 1)
                    }
                    return
                }

                let target = metrics.slotIndex(at: landing)
                let slots = pages[safe: pageIndex] ?? []

                guard let target, target < slots.count else {
                    if let target {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                            layout.move(slot.id, toPage: pageIndex, at: target)
                        }
                    }
                    return
                }

                let other = slots[target]
                guard other.id != slot.id else { return }

                // 判断是不是「压在正中间、并且按住了一会儿」。
                //
                // 原来只要落点在某格里就合并成文件夹。八个图标铺满两行，
                // 几乎任何落点都在别人身上——于是每次「挪个位置」都变成建文件夹，
                // 桌面上凭空长出一堆。现在只有真压在中心、又停住了才合并。
                let center = metrics.center(at: target)
                let distance = hypot(landing.x - center.x, landing.y - center.y)
                let held = Date().timeIntervalSince(dragStartedAt ?? Date())
                let wantsFolder = distance < metrics.cellWidth * 0.26 && held > 0.45

                if wantsFolder, other.isFolder || slot.isFolder {
                    // 拖进文件夹：单独处理，保持文件夹名。
                    appendIntoFolder(slot: slot, folder: other, page: pageIndex)
                } else if wantsFolder {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                        layout.merge(slot.id, into: other.id)
                    }
                } else {
                    // 换位。同页往前挪时，移除自己会让目标下标前移一位。
                    var insertAt = target
                    if let from = slots.firstIndex(where: { $0.id == slot.id }), from < target {
                        insertAt = target - 1
                    }
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                        layout.move(slot.id, toPage: pageIndex, at: insertAt)
                    }
                }

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

    /// 图标 + 间距 + 一行名字。名字是 11pt，行高约 13；
    /// 留 20 而不是刚好 18，是给 `minimumScaleFactor` 和那圈描边阴影一点余量——
    /// 少了这 2pt，第二行图标会压到上一行名字上。
    private static let labelAllowance: CGFloat = 20

    var cellHeight: CGFloat { PhoneMetrics.iconSize + Self.labelAllowance }

    /// 两行。上面还有三块组件，三行会顶到 Dock。
    static let rows = 2
    static var boardHeight: CGFloat {
        let cell = PhoneMetrics.iconSize + labelAllowance
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

    /// 格子中心（按图标本身算，不含下面那行名字）。
    /// 判断「有没有真的压在这一格上」用它。
    func center(at index: Int) -> CGPoint {
        let point = origin(at: index)
        return CGPoint(
            x: point.x + cellWidth / 2,
            y: point.y + PhoneMetrics.iconSize / 2
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
