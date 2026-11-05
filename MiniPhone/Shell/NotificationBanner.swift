import SwiftUI

/// 仿 iOS 原生通知的横幅。
///
/// 真机的通知是一块圆角很大的玻璃卡：左边 App 图标，右边标题加一行正文，
/// 右上角时间。这里照这个结构画，不用系统 `UNNotification` 的 UI
/// （App 在前台时系统本来也不展示它），所以能完全控制玻璃质感和动效。
struct NotificationBanner: View {
    let symbol: String
    let colors: [Color]
    let title: String
    let body: String
    var onTap: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: PhoneMetrics.Space.s) {
            icon

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: PhoneMetrics.Space.xs) {
                    Text(title)
                        .font(.system(size: PhoneMetrics.FontSize.sub, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("现在")
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Text(body)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.s + 2)
        .padding(.vertical, PhoneMetrics.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: PhoneMetrics.Radius.notification)
        .contentShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.notification, style: .continuous))
        .onTapGesture { onTap?() }
    }

    /// 图标按真机 App 图标的比例做：圆角方形、渐变底、白色图形。
    private var icon: some View {
        RoundedRectangle(cornerRadius: 7.5, style: .continuous)
            .fill(
                LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            )
            .frame(width: 30, height: 30)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

/// 外壳里的横幅队列。
///
/// 一次刷新可能同时涉及购物和小红书，两条横幅一起冒出来会挤满屏幕，
/// 所以排队逐条显示。
struct NotificationStack: View {
    let notices: [Notice]
    var onDismiss: () -> Void

    struct Notice: Identifiable, Hashable {
        let id = UUID()
        let symbol: String
        let colors: [Color]
        let title: String
        let body: String
    }

    var body: some View {
        VStack(spacing: PhoneMetrics.Space.xs) {
            ForEach(notices.prefix(2)) { notice in
                NotificationBanner(
                    symbol: notice.symbol,
                    colors: notice.colors,
                    title: notice.title,
                    body: notice.body,
                    onTap: onDismiss
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.xs)
    }
}
