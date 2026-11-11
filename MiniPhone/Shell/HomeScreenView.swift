import SwiftUI

/// 主屏。
///
/// 从上到下三块：小组件、图标网格、Dock。
/// 图标区现在分页、支持长按抖动、拖动换位、拖到一起建文件夹——
/// 这些都在 `HomeBoard` 里，这一层只管把三块排好。
///
/// 分页只在放不下的时候才有第二页：默认八个 App 正好一屏，
/// 翻过去是一整屏空的反而更假。
struct HomeScreenView: View {
    let selection: WallpaperSelection
    let world: WorldStore
    let onOpen: (PhoneApp) -> Void
    var videoWallpaperEnabled: Bool = false
    /// 音乐是否正在放。组件上的波形跟着它动。
    var musicPlaying: Bool = false
    /// 隐藏模式：三块组件都不显示。日程和「他在听什么」比壁纸更容易露馅。
    var hidesWidgets: Bool = false

    @State private var layout = HomeLayout.load()
    @State private var page = 0
    @State private var editing = false
    /// 下面那排（心情 + 音乐）是不是放在「今天」上面。编辑模式下上下拖一下能换。
    @AppStorage("shell.widgetPairFirst") private var pairFirst = false

    var body: some View {
        ZStack {
            WallpaperBackdrop(selection: selection, videoEnabled: videoWallpaperEnabled)
                .blur(radius: 0.8)
                // 压暗只在夜间做。日间是浅色壁纸，再蒙一层黑会整块发灰，
                // 图标下面是深色名字，底又灰，看着就脏。
                .overlay(Color.black.opacity(ThemeStore.shared.isNight ? 0.34 : 0))

            VStack(spacing: 0) {
                StatusBarView()

                // 灵动岛到组件之间要留出一条空：14 的时候第一块组件顶在岛边上，
                // 看着像被岛压住了。26 是文字基线下面还有一层留白的高度。
                Spacer(minLength: 0).frame(height: 26)

                if !hidesWidgets {
                    widgetStack

                    Spacer(minLength: 0).frame(height: 24)
                } else {
                    Spacer(minLength: 0).frame(height: 28)
                }

                iconGrid

                Spacer(minLength: 0)

                if editing {
                    doneEditingButton
                        .padding(.bottom, 6)
                }

                pageDots

                Spacer(minLength: 0).frame(height: 12)

                dock

                Spacer(minLength: 0).frame(height: 10)
            }
        }
        // 同锁屏：真机顶部安全区会把假状态栏压下来，让它从物理最顶端画起。
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - 小组件

    private var widgetStack: some View {
        VStack(spacing: HomeWidgetSize.gap) {
            if pairFirst {
                widgetPair
                todayWidget
            } else {
                todayWidget
                widgetPair
            }
        }
        .padding(.horizontal, 20)
        // 三块组件原来钉死在上面，怎么拖都不动。现在编辑模式下上下拖一下，
        // 「今天」和下面那排能换位置。
        .gesture(widgetDrag)
    }

    private var todayWidget: some View {
        HomeTodayWidget(schedule: world.state.schedule) {
            openApp("calendar")
        }
    }

    private var widgetPair: some View {
        HStack(spacing: HomeWidgetSize.gap) {
            HomeMoodWidget(mood: world.primaryMood, owner: world.primaryName) {
                openApp("messages")
            }
            HomeMusicWidget(track: world.state.currentTrack, playing: musicPlaying) {
                openApp("music")
            }
        }
    }

    private var widgetDrag: some Gesture {
        DragGesture(minimumDistance: 14)
            .onEnded { value in
                guard editing, abs(value.translation.height) > 44 else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                    pairFirst.toggle()
                }
            }
    }

    /// 组件点开对应的 App。找不到就当没点——主屏不该因为一个 id 崩掉。
    ///
    /// 桌面和 Dock 一起找：心情组件点开的是「信息」，它现在只在 Dock 里，
    /// 只翻桌面那张表会静默失灵。
    private func openApp(_ id: String) {
        guard let app = (AppCatalog.home + AppCatalog.dock).first(where: { $0.id == id }) else { return }
        onOpen(app)
    }

    // MARK: - 图标网格

    private var iconGrid: some View {
        HomeBoard(layout: $layout, page: $page, editing: $editing) { app in
            onOpen(app)
        }
        .padding(.horizontal, 20)
        // 编辑模式下删除角标是画在格子外面的，上面留一点，
        // 免得第一排的角标压到小组件下沿（之前两块是叠在一起的）。
        .padding(.top, editing ? 8 : 0)
        .animation(.easeOut(duration: 0.18), value: editing)
    }

    /// 编辑模式下的退出按钮。点空白也能退，但一个看得见的入口更稳。
    private var doneEditingButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { editing = false }
        } label: {
            Text("完成")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconLabelColor)
                .padding(.horizontal, 18)
                .frame(height: 30)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var iconLabelColor: Color {
        ThemeStore.shared.isNight ? Color.white : Theme.IconSurface.labelDay
    }

    // MARK: - 页面指示

    /// 只有一页的时候不画点：一个点等于在说「这里还能翻」。
    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(Array(layout.pages.indices), id: \.self) { index in
                Circle()
                    .fill(dotColor(active: index == page))
                    .frame(width: 6, height: 6)
            }
        }
        .opacity(layout.pages.count > 1 ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: page)
    }

    private func dotColor(active: Bool) -> Color {
        let base = ThemeStore.shared.isNight ? Color.white : Theme.IconSurface.pageDotDay
        return active ? base : base.opacity(0.45)
    }

    // MARK: - Dock

    private var dock: some View {
        HStack(spacing: 0) {
            ForEach(AppCatalog.dock) { app in
                Button {
                    onOpen(app)
                } label: {
                    AppIconTile(app: app, showsLabel: false).iconFrame(app)
                }
                .buttonStyle(IconPressStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, PhoneMetrics.dockHorizontalPadding)
        .frame(height: PhoneMetrics.dockHeight)
        // 磨砂而不是玻璃：`glassEffect` 在外壳的深色方案里总按深色材质渲染，
        // 垫多少白都是一块发灰的板子。磨砂走材质 + 薄白，壁纸颜色能透上来，
        // 边缘只剩一圈细高光——这才是参考图里那种毛玻璃。
        .frostedBar(cornerRadius: 34)
        .padding(.horizontal, 12)
    }
}

/// 按下时轻微缩小。真机的图标按下就是这个反馈，弹回用的是弹簧而不是线性动画。
struct IconPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

/// 图标画在主屏的哪一格（全局坐标）。
///
/// 打开动效要从被点的那颗图标长出来，所以外壳得先知道它的位置和大小。
/// 主屏网格和 Dock 各上报一次，外壳收成一份按 App id 索引的字典。
struct IconFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// 把这一块的全局坐标报给外壳。只在主屏上用。
    func iconFrame(_ app: PhoneApp) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: IconFramePreferenceKey.self,
                    value: [app.id: proxy.frame(in: .global)]
                )
            }
        )
    }
}
