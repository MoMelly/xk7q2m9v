import SwiftUI

/// 浅色页面里的分段控件。
///
/// 系统的 `Picker(.segmented)` 在外壳锁深色的上下文里会跟着翻成深色，
/// 落在浅色底上就是一条黑带。这里手搓一个，颜色全部取自 `Theme`，
/// 不参与配色方案翻转。
struct SegmentedTabs<Item: Hashable>: View {
    var items: [Item]
    var title: (Item) -> String
    @Binding var selection: Item

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                let isSelected = item == selection

                Button {
                    guard !isSelected else { return }
                    withAnimation(.easeOut(duration: 0.16)) {
                        selection = item
                    }
                } label: {
                    Text(title(item))
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Theme.label : Theme.secondaryLabel)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background {
                            if isSelected {
                                RoundedRectangle(
                                    cornerRadius: PhoneMetrics.Radius.grouped - 3,
                                    style: .continuous
                                )
                                .fill(Theme.rowSurface)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: PhoneMetrics.Radius.grouped, style: .continuous)
                .fill(Theme.separator.opacity(0.18))
        )
    }
}
