import SwiftUI

/// 锁屏。
///
/// 三个细节决定像不像：字号极大的细体时钟、底部左右两颗圆形玻璃按钮、
/// 以及上滑时整屏跟着手指走并且逐渐淡出。缺了任何一个都会立刻露馅。
struct LockScreenView: View {
    let wallpaper: WallpaperTheme
    let onUnlock: () -> Void
    var videoWallpaperEnabled: Bool = false

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            WallpaperBackdrop(theme: wallpaper, videoEnabled: videoWallpaperEnabled)

            VStack(spacing: 0) {
                StatusBarView()

                Spacer(minLength: 0).frame(height: 22)

                dateLine
                clock

                Spacer(minLength: 0)

                weatherWidget

                Spacer(minLength: 0).frame(height: 40)

                quickActions

                Spacer(minLength: 0).frame(height: 20)

                homeIndicator
            }
            .offset(y: dragOffset)
            .opacity(1 - min(0.85, -dragOffset / 340))
        }
        .contentShape(Rectangle())
        .gesture(unlockGesture)
    }

    // MARK: - 时钟与日期

    private var dateLine: some View {
        TimelineView(.everyMinute) { context in
            Text(TimeFormat.lockDate(context.date))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
        }
    }

    /// 玻璃数字时钟。
    ///
    /// 时间源与状态栏同为 `TimelineView(.everyMinute)` 读系统时间，天然同步；
    /// 缺的是质感，用渐变数字 + 内高光 + 原生玻璃容器补上。
    private var clock: some View {
        TimelineView(.everyMinute) { context in
            Text(TimeFormat.clock(context.date))
                .font(.system(size: PhoneMetrics.lockClockFontSize, weight: .thin, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.74)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 14, y: 5)
                .shadow(color: .white.opacity(0.22), radius: 1, y: -1)
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
                .glassSurface(cornerRadius: 28)
        }
    }

    // MARK: - 玻璃小组件

    /// 天气方块。内容目前是写死的占位，等 P4 做完角色状态再换成角色的日常。
    private var weatherWidget: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 12))
                Text("多云")
                    .font(.system(size: 12, weight: .medium))
                Spacer(minLength: 0)
                Text("绍兴")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }

            HStack(alignment: .top, spacing: 2) {
                Text("18")
                    .font(.system(size: 40, weight: .light, design: .rounded))
                Text("°")
                    .font(.system(size: 20, weight: .light, design: .rounded))
                    .padding(.top, 4)
                Spacer(minLength: 0)
            }

            Text("最高 22° 最低 13°")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.65))
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: 156, alignment: .leading)
        .glassSurface(cornerRadius: 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    // MARK: - 底部按钮

    private var quickActions: some View {
        HStack {
            circleButton(symbol: "flashlight.off.fill")
            Spacer()
            circleButton(symbol: "camera.fill")
        }
        .padding(.horizontal, 44)
    }

    private func circleButton(symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .glassSurface(cornerRadius: 24)
    }

    private var homeIndicator: some View {
        Capsule()
            .fill(.white.opacity(0.85))
            .frame(width: 134, height: 5)
    }

    // MARK: - 手势

    private var unlockGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                // 只跟手向上拖，向下拉不给任何反馈。
                dragOffset = min(0, value.translation.height)
            }
            .onEnded { value in
                let travelled = -value.translation.height
                let projected = -value.predictedEndTranslation.height

                // 甩动速度也算进去，否则快速上滑会因为位移不够而被判定失败。
                if travelled > PhoneMetrics.unlockDragThreshold || projected > 280 {
                    onUnlock()
                    dragOffset = 0
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                }
            }
    }
}
