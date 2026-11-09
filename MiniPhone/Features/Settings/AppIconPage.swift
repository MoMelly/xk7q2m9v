import SwiftUI
import UIKit

/// App 图标。
///
/// 三套备用图标是脚本画出来的（`scripts/make_alt_icons.py`），
/// 同一部小手机的轮廓换三种底色：奶白、夜里、深绿。配色在
/// `AppIconPalette` 里，和出图脚本是同一组值。
///
/// 切换用系统接口，所以会弹一次「正在更改图标」的确认框，那是 iOS 自己的提示，
/// 去不掉，也不该去掉。
struct AppIconPage: View {
    @State private var current: String?

    private var options: [AppIconPalette.Palette] { AppIconPalette.all }

    var body: some View {
        AppPage(title: "App 图标") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    GroupedSection(
                        nil,
                        footer: "换的是桌面那一格。隐藏模式下图标不会自动跟着换——那是两件事，一个是「别让人看见内容」，一个是「换个样子」。"
                    ) {
                        ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                            row(option)
                            if index != options.count - 1 {
                                RowDivider()
                            }
                        }
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
        .onAppear {
            current = UIApplication.shared.alternateIconName
        }
    }

    private func row(_ option: AppIconPalette.Palette) -> some View {
        let selected = option.id == current

        return Button {
            apply(option.id)
        } label: {
            HStack(spacing: PhoneMetrics.Space.s) {
                preview(option)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.name)
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(Theme.label)
                    Text(option.detail)
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(Theme.secondaryLabel)
                }

                Spacer(minLength: 0)

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.brand)
                }
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: PhoneMetrics.Row.detailed)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 预览是现画的，不读图标资源：读 .appiconset 在运行时拿不到，
    /// 再引一套小图只为画这四行不值得。
    private func preview(_ option: AppIconPalette.Palette) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppIconPalette.corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [option.top, option.bottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 40, height: 40)

            RoundedRectangle(cornerRadius: AppIconPalette.screenCorner, style: .continuous)
                .strokeBorder(option.glyph.opacity(0.9), lineWidth: 1.6)
                .frame(width: 16, height: 24)
        }
    }

    private func apply(_ name: String?) {
        guard UIApplication.shared.alternateIconName != name else { return }
        UIApplication.shared.setAlternateIconName(name) { error in
            Task { @MainActor in
                if error == nil {
                    current = name
                }
            }
        }
    }
}
