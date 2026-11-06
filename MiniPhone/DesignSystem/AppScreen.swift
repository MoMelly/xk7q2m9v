import SwiftUI

/// 系统 App 的页面容器。
///
/// 只负责三件事：底色、内联标题、左上角返回。内容自己决定要不要滚动，
/// 日历页需要固定月份头 + 滚动列表，不能由容器硬套一层 ScrollView。
///
/// 出口放左上角。系统 App 没有右上角「完成」这种模态按钮，那是弹窗的写法。
struct AppScreen<Content: View>: View {
    var title: String
    var surface: AppSurface
    var onClose: (() -> Void)?
    var trailingTitle: String?
    var trailingSymbol: String?
    var trailingAction: (() -> Void)?
    /// 顶栏透明、让内容里的封面图一直铺到状态栏下面；按钮和标题仍然保留。
    var transparentBar: Bool = false
    let content: Content

    init(
        title: String,
        surface: AppSurface = .light,
        onClose: (() -> Void)? = nil,
        trailingTitle: String? = nil,
        trailingSymbol: String? = nil,
        trailingAction: (() -> Void)? = nil,
        transparentBar: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.surface = surface
        self.onClose = onClose
        self.trailingTitle = trailingTitle
        self.trailingSymbol = trailingSymbol
        self.trailingAction = trailingAction
        self.transparentBar = transparentBar
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            // 先设 hidden 再设 style 会把可见性改回 visible，两条只能走不同分支。
            if transparentBar {
                stackContent
                    .toolbarBackground(.hidden, for: .navigationBar)
            } else {
                stackContent
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(surface.background, for: .navigationBar)
            }
        }
        .environment(\.colorScheme, surface.colorScheme)
    }

    private var stackContent: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(surface.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .tint(surface.tint)
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: onClose) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                }

                if let trailingTitle, let trailingAction {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(trailingTitle, action: trailingAction)
                            .font(.system(size: PhoneMetrics.FontSize.body))
                    }
                }

                if let trailingSymbol, let trailingAction {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: trailingAction) {
                            Image(systemName: trailingSymbol)
                                .font(.system(size: PhoneMetrics.FontSize.body, weight: .semibold))
                        }
                    }
                }
            }
    }
}
