import SwiftUI

/// 主屏。
///
/// 24 个图标刚好一页，跟真机 4×6 的排布一致，所以这一版不做左右翻页——
/// 伪造一个空白的第二页反而更假。等 P4 加了角色动态、图标超过一页再补。
struct HomeScreenView: View {
    let selection: WallpaperSelection
    let onOpen: (PhoneApp) -> Void
    var videoWallpaperEnabled: Bool = false

    var body: some View {
        ZStack {
            WallpaperBackdrop(selection: selection, videoEnabled: videoWallpaperEnabled)
                .blur(radius: 0.8)
                // 压暗只在夜间做。日间是浅色壁纸，再蒙一层黑会整块发灰，
                // 图标下面是深色名字，底又灰，看着就脏。
                .overlay(Color.black.opacity(ThemeStore.shared.isNight ? 0.34 : 0))

            VStack(spacing: 0) {
                StatusBarView()

                // 顶行图标离状态栏近了一贴上去，留够呼吸空间。
                Spacer(minLength: 0).frame(height: 24)

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
        // 玻璃的底色由 tint 决定，但材质本身的明暗跟「配色方案」走：
        // 外壳锁的是深色，于是这块玻璃总按深色材质渲染，外面垫多少白都只是灰。
        // 日间把这一段按浅色渲染再垫一层薄白，出来才是透亮的玻璃；
        // 夜间反过来按深色渲染，只留一点点白——夜里一块白板比灰更假。
        .glassSurface(
            cornerRadius: 34,
            tint: ThemeStore.shared.isNight ? Theme.Glass.dockNight : Theme.Glass.dockDay
        )
        .environment(\.colorScheme, ThemeStore.shared.isNight ? .dark : .light)
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Theme.Glass.dockRim, lineWidth: 0.6)
        }
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
