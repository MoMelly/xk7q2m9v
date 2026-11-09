import SwiftUI

/// 一排名字胶囊，用来在多个角色之间切。
///
/// 查手机、情侣空间这类「一个角色一份」的页面都用它。不传角色对象只传名字：
/// 组件不该知道 SwiftData 的存在，页面自己决定名字从哪来。
///
/// 只有一个名字时不显示——一个胶囊的切换条是纯装饰。
struct NameChipStrip: View {
    let names: [String]
    @Binding var selected: String
    /// 浅色页上用浅色胶囊，深色页上用磨砂。默认浅色。
    var onLight: Bool = true

    var body: some View {
        if names.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(names, id: \.self) { name in
                        chip(name)
                    }
                }
                .padding(.vertical, PhoneMetrics.Space.xs)
            }
        }
    }

    private func chip(_ name: String) -> some View {
        let isOn = name == selected

        return Button {
            Haptics.select()
            withAnimation(.easeOut(duration: 0.16)) { selected = name }
        } label: {
            Text(name)
                .font(.system(size: 13, weight: isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? chipInk : restInk)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background {
                    Capsule().fill(isOn ? onColor : offColor)
                }
        }
        .buttonStyle(.plain)
    }

    private var onColor: Color {
        onLight ? Theme.mint : Theme.mint.opacity(0.9)
    }

    private var offColor: Color {
        onLight ? Theme.rowSurface : Theme.cream.opacity(0.08)
    }

    /// 选中的胶囊是薄荷底，字得走深绿，不能用米白——那组对比在这个底色上读不清。
    private var chipInk: Color { Theme.deepGreen }

    private var restInk: Color {
        onLight ? Theme.label : Theme.cream.opacity(0.7)
    }
}
