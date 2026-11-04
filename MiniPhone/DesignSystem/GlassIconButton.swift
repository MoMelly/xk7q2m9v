import SwiftUI

/// 顶部栏那颗圆形玻璃按钮：返回、加号、更多、生成，全是同一个东西。
///
/// 之前聊天页、会话列表、动态页各手写了一遍「34×34 玻璃圆角 17」，
/// 尺寸和圆角一旦想调就得改三处，迟早改漏一处。收成一个组件。
struct GlassIconButton: View {
    let symbol: String
    /// 忙的时候把图标换成转圈，用于「正在生成」这类按钮。
    var isBusy: Bool = false
    var size: CGFloat = 34
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isBusy {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Theme.cream)
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.cream)
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .glassSurface(cornerRadius: size / 2)
    }
}

/// 页面顶部的小标题行：页面名 + 一行灰色说明。
///
/// 会话列表和动态页的结构完全一样，只有文案不同。
struct ScreenTitle: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.serif(22, weight: .semibold))
                .foregroundStyle(Theme.cream)

            Text(detail)
                .font(.system(size: 10, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(Theme.mint.opacity(0.62))
        }
    }
}
