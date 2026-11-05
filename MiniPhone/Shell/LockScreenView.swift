import SwiftUI

/// 锁屏。
///
/// 三个细节决定像不像：字本身是玻璃的大号时钟、底部两颗圆形玻璃按钮、
/// 上滑时整屏跟着手指走并逐渐淡出。
struct LockScreenView: View {
    let wallpaper: WallpaperTheme
    let onUnlock: () -> Void
    var videoWallpaperEnabled: Bool = false

    @Environment(WorldStore.self) private var world
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            WallpaperBackdrop(theme: wallpaper, videoEnabled: videoWallpaperEnabled)

            VStack(spacing: 0) {
                StatusBarView()

                Spacer(minLength: 0).frame(height: 18)

                dateLine
                    .padding(.bottom, PhoneMetrics.Space.xxs)
                clock

                Spacer(minLength: 0)

                LockScreenWidgets(
                    moodLabel: world.state.mood?.mood.label,
                    voiceText: world.state.unresolvedVoices(limit: 1).first?.text
                )

                Spacer(minLength: 0).frame(height: 32)

                LockScreenQuickActions()

                Spacer(minLength: 0).frame(height: 16)

                homeIndicator
            }
            .offset(y: dragOffset)
            .opacity(1 - min(0.85, -dragOffset / 340))
        }
        .contentShape(Rectangle())
        .gesture(unlockGesture)
    }

    private var dateLine: some View {
        TimelineView(.everyMinute) { context in
            Text(TimeFormat.lockDate(context.date) + " · 农历" + TimeFormat.lunarMonthDay(context.date))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
        }
    }

    /// 时间源与状态栏同为 `TimelineView(.everyMinute)`，读的是同一个系统时钟。
    private var clock: some View {
        TimelineView(.everyMinute) { context in
            GlassClock(text: TimeFormat.clock(context.date))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 20)
        }
    }

    private var homeIndicator: some View {
        Capsule()
            .fill(.white.opacity(0.85))
            .frame(width: 134, height: 5)
    }

    private var unlockGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                // 只跟手向上拖，向下拉不给反馈。
                dragOffset = min(0, value.translation.height)
            }
            .onEnded { value in
                let travelled = -value.translation.height
                let projected = -value.predictedEndTranslation.height

                // 甩动速度也算进去，否则快速上滑会因为位移不够被判失败。
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
