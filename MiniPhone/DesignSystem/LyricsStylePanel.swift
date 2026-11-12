import SwiftUI

/// 歌词排版的两个键。
///
/// 存的是原始字符串而不是枚举：`@AppStorage` 只认基本类型，
/// 存 rawValue 的话还得在每个读的地方处理「值不认识」的分支。
enum LyricsStyle {
    static let leading = "leading"
    static let center = "center"
    static let defaultAlign = leading

    static let small = "small"
    static let medium = "medium"
    static let large = "large"
    static let defaultSize = medium

    /// 字号倍率。高档只到 1.18：歌词一行本来就长，再大就得折成两行。
    static func scale(_ raw: String) -> CGFloat {
        switch raw {
        case small: return 0.86
        case large: return 1.18
        default: return 1
        }
    }
}

/// 歌词页的排版面板。
///
/// 飘在底部播放条上方，不占一整屏——调对齐和字号的时候要能立刻看到
/// 上面那几行字怎么变，面板挡住半屏就等于没有预览。
struct LyricsStylePanel: View {
    @Binding var alignRaw: String
    @Binding var sizeRaw: String
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 13) {
            HStack(spacing: 0) {
                Text("歌词排版")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer(minLength: 0)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }

            row("对齐") {
                chip("居左", active: alignRaw == LyricsStyle.leading) {
                    alignRaw = LyricsStyle.leading
                }
                chip("居中", active: alignRaw == LyricsStyle.center) {
                    alignRaw = LyricsStyle.center
                }
            }

            row("字号") {
                chip("小", active: sizeRaw == LyricsStyle.small) {
                    sizeRaw = LyricsStyle.small
                }
                chip("中", active: sizeRaw == LyricsStyle.medium) {
                    sizeRaw = LyricsStyle.medium
                }
                chip("大", active: sizeRaw == LyricsStyle.large) {
                    sizeRaw = LyricsStyle.large
                }
            }
        }
        .padding(16)
        .glassSurface(cornerRadius: 24)
    }

    private func row<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 34, alignment: .leading)

            content()

            Spacer(minLength: 0)
        }
    }

    private func chip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? Color.black.opacity(0.85) : Color.white.opacity(0.8))
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(
                    Capsule().fill(
                        active ? Color.white.opacity(0.92) : Color.white.opacity(0.12)
                    )
                )
        }
        .buttonStyle(.plain)
    }
}
