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
    var trailingAction: (() -> Void)?
    let content: Content

    init(
        title: String,
        surface: AppSurface = .light,
        onClose: (() -> Void)? = nil,
        trailingTitle: String? = nil,
        trailingAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.surface = surface
        self.onClose = onClose
        self.trailingTitle = trailingTitle
        self.trailingAction = trailingAction
        self.content = content()
    }

    var body: some View {
        NavigationStack {
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
                }
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(surface.background, for: .navigationBar)
        }
    }
}
