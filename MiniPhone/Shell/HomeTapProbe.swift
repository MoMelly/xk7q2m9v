import SwiftUI

/// 只在 `-previewState homeTapProbe` 时出现的一张自检卡。
///
/// 模拟器截图点不了屏幕，所以把轻点/长按的判定规则在这里跑一遍：
/// 至少能核对阈值和「编辑态短按照样打开」这条，不用靠猜。
struct HomeTapProbeCard: View {
    private struct Check: Identifiable {
        let label: String
        let pass: Bool
        var id: String { label }
    }

    private var checks: [Check] {
        [
            Check(
                label: "短按 0.12s → 打开 App",
                pass: HomeTapPolicy.shouldOpen(heldFor: 0.12, sinceEditing: 99, moved: 0)
            ),
            Check(
                label: "按 0.49s → 仍算轻点",
                pass: !HomeTapPolicy.isLongPress(heldFor: 0.49)
                    && HomeTapPolicy.shouldOpen(heldFor: 0.49, sinceEditing: 99, moved: 0)
            ),
            Check(
                label: "长按 0.6s → 进编辑，不打开",
                pass: HomeTapPolicy.isLongPress(heldFor: 0.6)
                    && !HomeTapPolicy.shouldOpen(heldFor: 0.6, sinceEditing: 99, moved: 0)
            ),
            Check(
                label: "长按刚松手 0.2s → 不误打开",
                pass: !HomeTapPolicy.shouldOpen(heldFor: 0.12, sinceEditing: 0.2, moved: 0)
            ),
            Check(
                label: "手指挪了 10pt → 算拖拽，不打开",
                pass: !HomeTapPolicy.shouldOpen(heldFor: 0.12, sinceEditing: 99, moved: 10)
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("桌面点击自检")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            ForEach(checks) { check in
                HStack(spacing: 8) {
                    Image(systemName: check.pass ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(check.pass ? Color.green : Color.red)
                    Text(check.label)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                }
            }

            Text("长按 \(HomeTapPolicy.longPressDuration)s · 拖动起点 \(Int(HomeTapPolicy.dragStartDistance))pt · 短按一律打开")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.94))
        .overlay(Rectangle().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
        .padding(.horizontal, 32)
    }
}
