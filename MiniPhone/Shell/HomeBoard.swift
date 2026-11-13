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

    /// 被拎起来的那一格。
    @State private var dragging: String?
    /// 手指现在在板上的位置。
    @State private var finger: CGPoint = .zero
    /// 按下点相对被拖格子左上角的偏移。
    ///
    /// 换位会让格子换到别的下标，格子原点跟着变；手指没动。
    /// 用「手指 − 这个偏移」反算图标该画在哪，换位前后绝对位置不变，
    /// 看着才不会每换一次位就跳一下。
    @State private var grip: CGSize = .zero
    /// 鼠标悬停语义：手指当前压在哪一格上，用来判要不要换位。
    @State private var hover: Int?
    @State private var openFolder: HomeSlot.Folder?
    /// 等着确认要卸掉的那一格。
    ///
    /// 减号原来一点就没了：她误触过一次，桌面上的图标当场消失，还以为数据一起删了。
    /// 现在先问一句，并且说清楚「只是拿走图标」。
    @State private var pendingRemoval: Removal?
    /// 翻页用的瞬时位移。松手后归零，由 `page` 接手。
    @State private var swipeOffset: CGFloat = 0
    /// 刚进编辑态的时刻。
    ///
    /// `onTapGesture` 不看按了多久，长按之后松手它照样会判成一次轻点，
    /// 于是「长按抖起来 → 松手立刻退出」连一帧都不留。用时间隔开这一下。
    @State private var editingSince: Date = .distantPast

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
            // 只裁左右，不裁上下。
            //
            // 原来这里是一整块 `.clipped()`：编辑模式下把图标往上或往下拖，
            // 一出网格就被切掉半截；第一排左上角的减号也被上边缘裁掉一块。
            // 翻页仍然要裁（相邻那页会滑进屏幕），所以横着裁、竖着放任它画出去。
            .clipShape(BoardWindow())
            .contentShape(Rectangle())
            .gesture(pagingGesture(size: size))
            // 兜底：图标那套手势万一没起来，板子这一层也认一次长按。
            //
            // 手势仲裁偶尔会把触点判给别处，只留一条路的话，落了空就是「长按整个
            // 桌面没反应」。`beginEditing()` 自己有 `guard !editing`，两条都命中
            // 也只进一次。`maximumDistance` 卡在 12：手指一动就是在翻页，
            // 不该顺带把桌面抖起来。
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.3, maximumDistance: 12)
                    .onEnded { _ in beginEditing() }
            )
            // 编辑模式下点一下空白退出。
            //
            // 上一版这里挂的是 simultaneousGesture(TapGesture)：它会跟图标上的
            // 拖动手势一起响应，于是「按下去准备拖」这一下先被它判成轻点、
            // 把编辑状态退掉了，第二次再按就没有编辑模式可拖——她说的
            // 「只有第一次点击有效果」就是这条。
            .onTapGesture { location in
                // 0.45 秒内不认：那一下是长按松手，不是「点空白」。
                // 这里不再要求 `dragging == nil`——手势被系统打断时那一位可能
                // 一直挂着，卡住的话点哪儿都退不出编辑态。退出时顺手清掉。
                guard editing, Date().timeIntervalSince(editingSince) > 0.45 else { return }
                exitEditing(at: location, metrics: PhoneBoardMetrics(size: size))
            }
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
        // 退出编辑态时把拖拽留下的一切清干净。
        //
        // 手势中途被别的东西打断（弹窗、来电浮层）时 `onEnded` 不一定会走，
        // `dragging` 就停在那儿：那颗图标一直浮着，翻页和「点空白退出」全被它挡住，
        // 看上去就是「桌面卡在编辑状态，点什么都点不进去」。
        .onChange(of: editing) { _, now in
            guard !now else { return }
            dragging = nil
            hover = nil
            swipeOffset = 0
        }
        .confirmationDialog(
            pendingRemoval.map { "把「\($0.name)」从桌面移除？" } ?? "",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("从桌面移除", role: .destructive) { confirmRemoval() }
            Button("取消", role: .cancel) { pendingRemoval = nil }
        } message: {
            Text("只是拿走这个图标，聊天记录和里面的东西都还在。想装回来去底栏的「应用商店」。")
        }
    }

    // MARK: - 一页

    private func pageView(_ slots: [HomeSlot], index: Int, size: CGSize) -> some View {
        let metrics = PhoneBoardMetrics(size: size)

        return ZStack(alignment: .topLeading) {
            ForEach(Array(slots.enumerated()), id: \.element.id) { position, slot in
                let origin = metrics.origin(at: position)
                let lifted = dragging == slot.id

                slotView(slot, editing: editing, jigglePhase: position)
                    .frame(width: metrics.cellWidth, height: metrics.cellHeight)
                    .offset(x: origin.x, y: origin.y)
                    // 换位时被挤开的格子滑过去。这一行必须排在拖动位移**之前**：
                    // 它只该动「排在网格里的第几格」，不该把手指带出来的那段也动画化。
                    .animation(.spring(response: 0.30, dampingFraction: 0.82), value: position)
                    // 拎起来的样子：放大、投影加深。没有这两样，拖起来跟没拖一样，
                    // 看不出这颗图标已经脱离桌面了。
                    .scaleEffect(lifted ? 1.12 : 1)
                    .shadow(
                        color: .black.opacity(lifted ? 0.34 : 0),
                        radius: lifted ? 22 : 0,
                        y: lifted ? 12 : 0
                    )
                    .animation(.spring(response: 0.24, dampingFraction: 0.72), value: lifted)
                    // offset 放在动画之后：跟手的那段位移不能有动画，
                    // 否则图标是「追」手指，慢半拍，手感就是钝的。
                    .offset(lifted ? dragOffset(origin: origin) : .zero)
                    .zIndex(lifted ? 100 : Double(position))
                    .gesture(iconGesture(slot: slot, page: index, metrics: metrics, size: size))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// 手指把图标带出来多远。
    ///
    /// 只跟手指和按下点，跟格子现在排在第几格无关。所以换位之后
    /// 图标在屏幕上的绝对位置不变，手指下面是同一颗图标。
    private func dragOffset(origin: CGPoint) -> CGSize {
        CGSize(
            width: finger.x - grip.width - origin.x,
            height: finger.y - grip.height - origin.y
        )
    }

    // MARK: - 一格

    @ViewBuilder
    private func slotView(_ slot: HomeSlot, editing: Bool, jigglePhase: Int) -> some View {
        switch slot {
        case .app(let appID):
            if let app = app(id: appID) {
                // 这里不能用 Button。
                //
                // 手势挂在 Button 上时，SwiftUI 会先让 Button 自己那套点击识别器
                // 吃掉触点，同一层的「长按 + 拖动」根本收不到事件——长按不进编辑态、
                // 也拎不起来，两条都是这个原因。换成普通视图之后，打开走
                // onTapGesture，拖动走外面那个 sequenced 手势，两边不抢。
                AppIconTile(app: app)
                    .iconFrame(app)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !editing else { return }
                        onOpen(app)
                    }
                    .accessibilityAddTraits(.isButton)
                    // 不要再按 `editing` 关掉命中：手势挂在这一层上，
                    // `allowsHitTesting(false)` 会连拖动手势一起挡掉，
                    // 编辑态里就按不动任何图标。打开动作由 onTapGesture
                    // 自己那行 `guard !editing` 拦住。
                    .overlay(alignment: .topLeading) {
                        if editing { removeBadge { remove(appID) } }
                    }
                    .jiggle(editing, phase: jigglePhase)
            }

        case .folder(let folder):
            VStack(spacing: 5) {
                FolderTile(apps: folder.appIDs.compactMap { app(id: $0) })
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !editing else { return }
                        openFolder = folder
                    }
                    .accessibilityAddTraits(.isButton)
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

    /// 点一下退出编辑。
    private func exitEditing(at point: CGPoint, metrics: PhoneBoardMetrics) {
        withAnimation(.easeOut(duration: 0.18)) {
            editing = false
        }
        dragging = nil
        hover = nil
    }

    // MARK: - 手势：拖一格

    private func iconGesture(
        slot: HomeSlot,
        page pageIndex: Int,
        metrics: PhoneBoardMetrics,
        size: CGSize
    ) -> some Gesture {
        // 长按和拖动串成一个手势，但两段都要处理。
        //
        // 上一版只在 `.second` 里干活，等于「长按满 0.3 秒还必须手指动起来」
        // 才会进编辑态；长按按住了不动就是什么都没发生——她说的「长按进不了
        // 编辑状态」就是这条。iOS 的规矩是长按一满足就抖起来，手指再动才拎起，
        // 所以 `.first` 只开编辑态，`.second` 才真正开始拖。
        LongPressGesture(minimumDuration: 0.28, maximumDistance: 22)
            .sequenced(
                before: DragGesture(minimumDistance: 0, coordinateSpace: .named("homeBoard"))
            )
            .onChanged { value in
                switch value {
                case .first(_):
                    beginEditing()

                case .second(true, let drag):
                    if dragging == nil {
                        beginDrag(slot: slot, page: pageIndex, metrics: metrics, at: drag?.startLocation)
                    }
                    guard let drag else { return }
                    finger = drag.location
                    retarget(drag.location, page: pageIndex, metrics: metrics)

                case .second(false, _):
                    break
                }
            }
            .onEnded { value in
                var landing: CGPoint?
                if case .second(true, let drag) = value { landing = drag?.location }
                finishDrag(landing, page: pageIndex, metrics: metrics, size: size)
            }
    }

    /// 进编辑态：图标开始抖，左上角长出减号。
    private func beginEditing() {
        guard !editing else { return }
        editingSince = Date()
        withAnimation(.easeOut(duration: 0.16)) { editing = true }
        Haptics.tap()
    }

    /// 拎起来的那一下。记下「手指按在格子里的哪个位置」，之后图标就按这个
    /// 关系跟着手指走，不会在拎起来的瞬间跳到手指中心。
    private func beginDrag(
        slot: HomeSlot,
        page pageIndex: Int,
        metrics: PhoneBoardMetrics,
        at point: CGPoint?
    ) {
        guard let index = pages[safe: pageIndex]?.firstIndex(where: { $0.id == slot.id })
        else { return }
        let origin = metrics.origin(at: index)
        let grab = point ?? CGPoint(x: origin.x + metrics.cellWidth / 2, y: origin.y)
        grip = CGSize(width: grab.x - origin.x, height: grab.y - origin.y)
        finger = grab
        dragging = slot.id
        hover = index
        if !editing {
            withAnimation(.easeOut(duration: 0.16)) { editing = true }
        }
    }

    /// 手指移到哪，就把被拖的格子排到哪一格。
    ///
    /// 换位发生在拖动过程中，不是松手那一刻——被挤开的图标是用弹簧推走的，
    /// 所以看到的是「旁边让位」，不是「松手后整排突然重排」。
    private func retarget(_ point: CGPoint, page pageIndex: Int, metrics: PhoneBoardMetrics) {
        guard let movingID = dragging,
              let slots = pages[safe: pageIndex],
              let target = metrics.slotIndex(at: point),
              target < slots.count
        else {
            hover = nil
            return
        }

        let other = slots[target]
        // 文件夹不参与实时换位：拖到文件夹上是「并进去」，那是松手才算的事。
        guard !other.isFolder, other.id != movingID else {
            hover = target
            return
        }
        guard hover != target else { return }
        hover = target

        withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
            layout.move(movingID, toPage: pageIndex, at: target)
        }
    }

    /// 松手。位置在拖动中已经定好，这里只处理跨页和「并进文件夹」。
    private func finishDrag(
        _ landing: CGPoint?,
        page pageIndex: Int,
        metrics: PhoneBoardMetrics,
        size: CGSize
    ) {
        guard let movingID = dragging else { return }
        let point = landing ?? finger

        defer {
            dragging = nil
            hover = nil
            layout.save()
        }

        // 拖出左右边界：换到相邻页，追加到那页末尾。
        if point.x < -26, pageIndex > 0 {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                layout.move(movingID, toPage: pageIndex - 1, at: nil)
                page = pageIndex - 1
            }
            return
        }
        if point.x > size.width + 26, pageIndex < pages.count - 1 {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                layout.move(movingID, toPage: pageIndex + 1, at: nil)
                page = pageIndex + 1
            }
            return
        }

        guard let target = metrics.slotIndex(at: point),
              let slots = pages[safe: pageIndex],
              target < slots.count
        else { return }

        let other = slots[target]
        // 只有「拖到已有的文件夹上」才并进去。
        //
        // 上一版只要压在某格中心够久就把两个 App 合成新文件夹，实际用起来
        // 每次想挪位置都会长出一个文件夹。合并不是主诉，先按她抱怨的方向关掉。
        guard case .folder = other, other.id != movingID else { return }
        guard let moving = slots.first(where: { $0.id == movingID }) else { return }
        appendIntoFolder(slot: moving, folder: other, page: pageIndex)
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
        guard let app = app(id: appID) else { return }
        pendingRemoval = Removal(id: appID, name: app.name)
    }

    private func confirmRemoval() {
        guard let pending = pendingRemoval else { return }
        pendingRemoval = nil
        // 落在 HomeLayout 里：应用商店装回去用的是同一套读写，两边不会各写一份。
        HomeLayout.remove(pending.id)
        withAnimation(.easeOut(duration: 0.2)) {
            layout = HomeLayout.load().pruned()
        }
    }
}

/// 减号按下去之后要确认的那一格。
struct Removal: Identifiable {
    let id: String
    let name: String
}

/// 桌面网格的可见范围：横着裁到板子，竖着几乎不裁。
///
/// 翻页靠横向位移，必须裁；拖拽是竖向的，裁了就成「拖出两行就消失」。
struct BoardWindow: Shape {
    func path(in rect: CGRect) -> Path {
        Path(CGRect(
            x: rect.minX,
            y: rect.minY - 600,
            width: rect.width,
            height: rect.height + 1_200
        ))
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

    /// 落在哪一格。
    ///
    /// 网格外面也照样给一格（取最近的列和行）：手指往组件那边或者 Dock 那边
    /// 一偏就返回 nil 的话，换位会忽然停住，感觉像拖拽只认这两行。
    func slotIndex(at point: CGPoint) -> Int? {
        guard size.width > 0, cellWidth > 0 else { return nil }
        let rawCol = Int((point.x / (cellWidth + hSpacing)).rounded(.down))
        let rawRow = Int((point.y / (cellHeight + vSpacing)).rounded(.down))
        let col = min(max(0, rawCol), columns - 1)
        let row = min(max(0, rawRow), PhoneBoardMetrics.rows - 1)
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
