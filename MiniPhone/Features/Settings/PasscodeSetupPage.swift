import SwiftUI

/// 锁屏密码设置。
///
/// 只收四位数字。这里不存明文提示、不做找回——它是挡「别人拿起这台手机」的，
/// 不是挡专业取证的；与其做一套假的找回流程，不如把边界说清楚。
struct PasscodeSetupPage: View {
    @Bindable var settings: SettingsStore

    /// 第一次输入完，再输一次确认，防止手滑。
    @State private var stage: Stage = .first
    @State private var first = ""
    @State private var entered = ""
    @State private var hint: String = ""

    private enum Stage {
        case first
        case confirm
    }

    private var dots: some View {
        HStack(spacing: 14) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .strokeBorder(Theme.separator, lineWidth: 1)
                    .background(Circle().fill(index < entered.count ? Theme.brand : Color.clear))
                    .frame(width: 13, height: 13)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PhoneMetrics.Space.l)
    }

    var body: some View {
        AppPage(title: "锁屏密码") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    header
                    dots
                    keypad

                    if !settings.passcode.isEmpty {
                        Button {
                            settings.setPasscode("")
                            reset()
                            hint = "密码已关掉，上滑就能直接进桌面。"
                        } label: {
                            Text("关掉密码")
                                .font(.system(size: PhoneMetrics.FontSize.body, weight: .medium))
                                .foregroundStyle(Theme.IconTint.pink)
                                .frame(maxWidth: .infinity)
                                .frame(height: PhoneMetrics.Row.single)
                                .background(Theme.cardSurface)
                                .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, PhoneMetrics.Space.m)
                    }
                }
                .padding(.top, PhoneMetrics.Space.m)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(stage == .first ? "设置四位数字" : "再输一次确认")
                .font(.system(size: PhoneMetrics.FontSize.body, weight: .medium))
                .foregroundStyle(Theme.label)

            Text(hint.isEmpty
                 ? "设好之后，锁屏上滑会先出数字键盘。密码只存在这台手机里。"
                 : hint)
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .foregroundStyle(hint.isEmpty ? Theme.secondaryLabel : Theme.IconTint.pink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PhoneMetrics.Space.l)
        }
    }

    private var keypad: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
            spacing: 12
        ) {
            ForEach(1...9, id: \.self) { number in
                key("\(number)")
            }
            Color.clear.frame(height: 54)
            key("0")
            deleteKey
        }
        .padding(.horizontal, PhoneMetrics.Space.l)
    }

    private func key(_ text: String) -> some View {
        Button {
            Haptics.tap()
            append(text)
        } label: {
            Text(text)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Theme.label)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Theme.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.block, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var deleteKey: some View {
        Button {
            Haptics.tap()
            guard !entered.isEmpty else { return }
            entered.removeLast()
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 16))
                .foregroundStyle(Theme.secondaryLabel)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("删除一位")
    }

    private func append(_ text: String) {
        guard entered.count < 4 else { return }
        entered += text
        guard entered.count == 4 else { return }
        commit()
    }

    private func commit() {
        switch stage {
        case .first:
            first = entered
            entered = ""
            stage = .confirm
            hint = ""
        case .confirm:
            if entered == first {
                settings.setPasscode(entered)
                hint = "密码已设好。下次上滑要输这四位。"
                reset()
            } else {
                Haptics.warn()
                hint = "两次不一样，重来一次。"
                reset()
            }
        }
    }

    private func reset() {
        stage = .first
        first = ""
        entered = ""
    }
}
