import SwiftUI

/// 锁屏。
///
/// 三个细节决定像不像：字本身是玻璃的大号时钟、底部两颗圆形玻璃按钮、
/// 上滑时整屏跟着手指走并逐渐淡出。
struct LockScreenView: View {
    let selection: WallpaperSelection
    let onUnlock: () -> Void
    var videoWallpaperEnabled: Bool = false
    /// 设了密码就上滑先出键盘；空串表示没设。
    var passcode: String = ""
    /// 隐藏模式：锁屏上那两块（他的心情、没说出口的话）不显示。
    var hidesWidgets: Bool = false

    @Environment(WorldStore.self) private var world
    @State private var dragOffset: CGFloat = 0
    @State private var askingPasscode = false

    private var hasPasscode: Bool { passcode.count == 4 }

    var body: some View {
        ZStack {
            WallpaperBackdrop(selection: selection, videoEnabled: videoWallpaperEnabled)

            VStack(spacing: 0) {
                StatusBarView()

                Spacer(minLength: 0).frame(height: 18)

                dateLine
                    .padding(.bottom, PhoneMetrics.Space.xxs)
                clock

                Spacer(minLength: 0)

                if !hidesWidgets {
                    LockScreenWidgets(
                        moodLabel: world.primaryMood?.mood.label,
                        voiceText: world.state.unresolvedVoices(limit: 1, person: world.primaryName).first?.text
                    )
                }

                Spacer(minLength: 0).frame(height: 32)

                LockScreenQuickActions()

                Spacer(minLength: 0).frame(height: 16)

                homeIndicator
            }
            .offset(y: dragOffset)
            .opacity(1 - min(0.85, -dragOffset / 340))

            if askingPasscode {
                // 键盘盖在整屏之上，解锁后连同一整层一起消失。
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .transition(.opacity)

                PasscodePad(length: 4, onComplete: { entered in
                    guard entered == passcode else { return false }
                    askingPasscode = false
                    dragOffset = 0
                    onUnlock()
                    return true
                }, onCancel: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        askingPasscode = false
                    }
                })
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .contentShape(Rectangle())
        .gesture(unlockGesture)
        // 真机刘海屏的顶部安全区有 59pt，假状态栏会被压到刘海下面去。
        // 状态栏必须从物理最顶端画起，跟系统原生锁屏对齐。
        .ignoresSafeArea(edges: .top)
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
                    if hasPasscode {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                            askingPasscode = true
                            dragOffset = 0
                        }
                    } else {
                        onUnlock()
                        dragOffset = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                }
            }
    }
}
