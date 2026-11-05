import SwiftUI

/// 设置分组里每一行的统一内边距。
struct RowPadding: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func rowPadding() -> some View {
        modifier(RowPadding())
    }
}

/// 壁纸预览小方块。只画基底渐变，不画光斑——尺寸太小，光斑糊成一团反而看不清差别。
struct WallpaperSwatch: View {
    let theme: WallpaperTheme

    var body: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(
                LinearGradient(
                    colors: theme.baseColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 40, height: 40)
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.12), lineWidth: 0.5)
            }
    }
}
