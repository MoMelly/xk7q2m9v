import SwiftUI

/// 刷新之后那一行反馈。
///
/// 不做弹窗：页面本身已经变了，用户一眼能看到结果。这里只补一句话，
/// 说明「刚才是点到了」，失败时把原因带出来。
struct RefreshStatusStrip: View {
    let text: String
    var isLoading: Bool = false

    var body: some View {
        HStack(spacing: PhoneMetrics.Space.xxs) {
            if isLoading {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
            }

            Text(text)
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.brand)
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.bottom, PhoneMetrics.Space.xs)
    }
}
