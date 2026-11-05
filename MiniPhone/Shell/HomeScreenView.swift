import SwiftUI

/// 主屏。
///
/// 24 个图标刚好一页，跟真机 4×6 的排布一致，所以这一版不做左右翻页——
/// 伪造一个空白的第二页反而更假。等 P4 加了角色动态、图标超过一页再补。
struct HomeScreenView: View {
    let wallpaper: WallpaperTheme
    let onOpen: (PhoneApp) -> Void
    var videoWallpaperEnabled: Bool = false

    var body: some View {
        ZStack {
            WallpaperBackdrop(theme: wallpaper, videoEnabled: videoWallpaperEnabled)
                .blur(radius: 0.8)
                .overlay(Color.black.opacity(0.1))

            VStack(spacing: 0) {
                StatusBarView()

                Spacer(minLength: 0).frame(height: 10)

                iconGrid

                Spacer(minLength: 0)

                pageDots

                Spacer(minLength: 0).frame(height: 12)

                dock

                Spacer(minLength: 0).frame(height: 10)
            }
        }
    }

    // MARK: - 图标网格

    private var iconGrid: some View {
        LazyVGrid(columns: columns, spacing: PhoneMetrics.gridVerticalSpacing) {
            ForEach(AppCatalog.home) { app in
                Button {
                    onOpen(app)
                } label: {
                    AppIconTile(app: app)
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
                .fill(.white)
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
                    AppIconTile(app: app, showsLabel: false)
                }
                .buttonStyle(IconPressStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, PhoneMetrics.dockHorizontalPadding)
        .frame(height: PhoneMetrics.dockHeight)
        .glassSurface(cornerRadius: 34)
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
