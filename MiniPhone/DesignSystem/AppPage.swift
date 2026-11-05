import SwiftUI

/// 被 `NavigationLink` push 进去的页面。
///
/// 与 `AppScreen` 的区别只有一个：不再自己包 `NavigationStack`。
/// 二级页嵌在设置的导航栈里，再包一层会出现两条导航栏。
struct AppPage<Content: View>: View {
    var title: String
    var surface: AppSurface
    let content: Content

    init(
        title: String,
        surface: AppSurface = .light,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.surface = surface
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(surface.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .tint(surface.tint)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(surface.background, for: .navigationBar)
            .environment(\.colorScheme, surface.colorScheme)
    }
}
