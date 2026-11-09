import SwiftUI

/// 锁屏密码键盘。
///
/// 四位数字，跟真机一样：点满四位自己校验，错了整块抖一下清空，不告诉你哪一位错。
/// 不做「忘记密码」——这个密码挡的是拿起你手机的那个人，跳过它的路只有一条，
/// 在设置里关掉，而设置本身在解锁之后。
struct PasscodePad: View {
    let length: Int
    let onComplete: (String) -> Bool
    var onCancel: () -> Void

    @State private var entered = ""
    @State private var shakeOffset: CGFloat = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 18), count: 3)

    var body: some View {
        VStack(spacing: 22) {
            Text("输入密码")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))

            dots

            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(1...9, id: \.self) { number in
                    digit("\(number)")
                }
                blank
                digit("0")
                deleteKey
            }
            .frame(maxWidth: 260)

            Button("取消", action: onCancel)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 4)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
        )
        .offset(x: shakeOffset)
        .padding(.horizontal, 24)
    }

    private var dots: some View {
        HStack(spacing: 16) {
            ForEach(0..<length, id: \.self) { index in
                Circle()
                    .strokeBorder(Color.white.opacity(0.65), lineWidth: 1.2)
                    .background(
                        Circle().fill(index < entered.count ? Color.white : Color.clear)
                    )
                    .frame(width: 12, height: 12)
            }
        }
    }

    private func digit(_ text: String) -> some View {
        Button {
            Haptics.tap()
            append(text)
        } label: {
            Text(text)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(Circle().fill(Color.white.opacity(0.16)))
        }
        .buttonStyle(.plain)
    }

    private var blank: some View {
        Color.clear.frame(width: 62, height: 62)
    }

    private var deleteKey: some View {
        Button {
            Haptics.tap()
            guard !entered.isEmpty else { return }
            entered.removeLast()
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 62, height: 62)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("删除一位")
    }

    private func append(_ text: String) {
        guard entered.count < length else { return }
        entered += text
        guard entered.count == length else { return }

        if onComplete(entered) {
            entered = ""
        } else {
            Haptics.warn()
            entered = ""
            withAnimation(.linear(duration: 0.06).repeatCount(4, autoreverses: true)) {
                shakeOffset = 9
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                shakeOffset = 0
            }
        }
    }
}
