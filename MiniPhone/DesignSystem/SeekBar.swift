import SwiftUI

/// 可拖动的播放进度条。
///
/// 原来那条是 3.5pt 的 Capsule，`DragGesture(minimumDistance: 0)` 只挂了
/// `.onEnded`：手指没有抓得住的东西，拖动过程中画面也不跟手，看起来就是死的。
/// 这里把命中区域做到 36pt，加一颗跟手走的圆点；拖动时只更新预览值，
/// 松手才真正 seek——每帧 seek 会让 AVPlayer 反复起播，听起来像卡带。
struct SeekBar: View {
    /// 0~1。外部进度，`isScrubbing` 为 true 时以手指位置为准。
    let progress: Double
    var isScrubbing: Bool = false
    var trackColor: Color = .white.opacity(0.20)
    var fillColor: Color = .white.opacity(0.86)
    var thumbColor: Color = .white
    var barHeight: CGFloat = 4
    var hitHeight: CGFloat = 36
    var onScrubBegan: () -> Void = {}
    var onScrub: (Double) -> Void = { _ in }
    var onScrubEnded: () -> Void = {}

    @State private var localProgress: Double?
    @State private var dragging = false

    private var shown: Double {
        min(max(localProgress ?? progress, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let knob = dragging ? 17.0 : 13.0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)
                    .frame(height: barHeight)

                Capsule()
                    .fill(fillColor)
                    .frame(width: max(width * shown, barHeight), height: barHeight)

                Circle()
                    .fill(thumbColor)
                    .frame(width: knob, height: knob)
                    .shadow(color: .black.opacity(0.28), radius: 3, y: 1)
                    .offset(x: min(max(width * shown - knob / 2, 0), max(width - knob, 0)))
                    .animation(.easeOut(duration: 0.14), value: dragging)
            }
            .frame(width: width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !dragging {
                            dragging = true
                            onScrubBegan()
                        }
                        let ratio = min(max(value.location.x / width, 0), 1)
                        localProgress = ratio
                        onScrub(ratio)
                    }
                    .onEnded { value in
                        let ratio = min(max(value.location.x / width, 0), 1)
                        onScrub(ratio)
                        onScrubEnded()
                        dragging = false
                        localProgress = nil
                    }
            )
        }
        .frame(height: hitHeight)
        .accessibilityElement()
        .accessibilityLabel("播放进度")
        .accessibilityValue("\(Int(shown * 100))%")
    }
}
