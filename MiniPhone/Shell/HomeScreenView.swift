import SwiftUI

/// 主屏。
///
/// 从上到下三块：小组件、图标网格、Dock。图标现在 12 个（4×3），
/// 上面留给三块组件——今日日程、心情、在听。之前只有图标，
/// 底下空一大片，看着不像一台被用过的手机。
///
/// 不做左右翻页：图标还没多到需要第二页，伪造一页空的反而更假。
struct HomeScreenView: View {
    let selection: WallpaperSelection
    let world: WorldStore
    let onOpen: (PhoneApp) -> Void
    var videoWallpaperEnabled: Bool = false
    /// 音乐是否正在放。组件上的波形跟着它动。
    var musicPlaying: Bool = false

    var body: some View {
        ZStack {
            WallpaperBackdrop(selection: selection, videoEnabled: videoWallpaperEnabled)
                .blur(radius: 0.8)
                // 压暗只在夜间做。日间是浅色壁纸，再蒙一层黑会整块发灰，
                // 图标下面是深色名字，底又灰，看着就脏。
                .overlay(Color.black.opacity(ThemeStore.shared.isNight ? 0.34 : 0))

            VStack(spacing: 0) {
                StatusBarView()

                Spacer(minLength: 0).frame(height: 14)

                widgetStack

                Spacer(minLength: 0).frame(height: 22)

                iconGrid

                Spacer(minLength: 0)

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
            HomeTodayWidget(schedule: world.state.schedule) {
                openApp("calendar")
            }

            HStack(spacing: HomeWidgetSize.gap) {
                HomeMoodWidget(mood: world.state.mood) {
                    openApp("messages")
                }
                HomeMusicWidget(track: world.state.currentTrack, playing: musicPlaying) {
                    openApp("music")
                }
            }
        }
        .padding(.horizontal, 20)
    }

    /// 组件点开对应的 App。找不到就当没点——主屏不该因为一个 id 崩掉。
    private func openApp(_ id: String) {
        guard let app = AppCatalog.home.first(where: { $0.id == id }) else { return }
        onOpen(app)
    }

    // MARK: - 图标网格

    private var iconGrid: some View {
        LazyVGrid(columns: columns, spacing: PhoneMetrics.gridVerticalSpacing) {
            ForEach(AppCatalog.home) { app in
                Button {
                    onOpen(app)
                } label: {
                    AppIconTile(app: app).iconFrame(app)
                }
                .buttonStyle(IconPressStyle())
            }
        }
        .padding(.horizontal, 20)
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: PhoneMetrics.gridHorizontalSpacing, alignment: .top),
            count: PhoneMetrics.gridColumns
        )
    }

    // MARK: - 页面指示

    private var pageDots: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ThemeStore.shared.isNight ? Color.white : Theme.IconSurface.pageDotDay)
                .frame(width: 6, height: 6)
        }
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
