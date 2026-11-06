import SwiftUI

/// 后加的四种版式。
///
/// 原来的八种在 `NoteCoverStyles.swift`，单独拆一份是让两边都不超过 400 行。
/// 同一个 `extension NoteCover`，所以底色、标题、seed 这些属性照常能用。
extension NoteCover {
    /// 气泡：一句台词装在白气泡里，右下角放个表情当落款。
    var bubble: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(CoverText.emoji(seed, offset: 6))
                .font(.system(size: 18))
                .padding(.bottom, 8)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(pair.ink)
                .lineSpacing(3)
                .lineLimit(3)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
                .padding(EdgeInsets(top: 10, leading: 11, bottom: 10, trailing: 11))
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                )

            Spacer(minLength: 6)

            HStack(spacing: 4) {
                if !tag.isEmpty {
                    Text("#\(tag)")
                        .font(.system(size: 9))
                        .foregroundStyle(pair.ink.opacity(0.55))
                }
                Spacer(minLength: 0)
                Text(CoverText.emoji(seed, offset: 8))
                    .font(.system(size: 12))
            }
        }
        .padding(11)
    }

    /// 荧光笔：标题底下压一道半透明粗条，像手账里划重点。
    var marker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(CoverText.emoji(seed, offset: 9))
                .font(.system(size: 16))

            Spacer(minLength: 6)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(pair.ink)
                .lineSpacing(4)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(pair.accent.opacity(0.42))
                            .frame(height: 7)
                    }
                )

            Spacer(minLength: 8)

            if let highlight {
                Text(highlight)
                    .font(.system(size: 9))
                    .foregroundStyle(pair.ink.opacity(0.60))
                    .lineLimit(1)
            }

            if !tag.isEmpty {
                Text("#\(tag)")
                    .font(.system(size: 9))
                    .foregroundStyle(pair.ink.opacity(0.45))
                    .padding(.top, 3)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 13, bottom: 12, trailing: 13))
    }

    /// 上下分栏：上面一块强调色，压着编号和表情；下面才是标题。
    var split: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(CoverText.emoji(seed, offset: 1))
                        .font(.system(size: 20))
                    Spacer(minLength: 0)
                    Text("NO.\(CoverText.number(seed))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .frame(height: proxy.size.height * 0.28)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(pair.ink)
                    .lineSpacing(3)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)

                if !tag.isEmpty {
                    Text("#\(tag)")
                        .font(.system(size: 9))
                        .foregroundStyle(pair.ink.opacity(0.5))
                        .padding(.top, 6)
                }
            }
            .padding(12)
        }
    }

    /// 小票：等宽字、虚线撕口、编号和时间感的一行小字。
    var receipt: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("西瓜皮 · 小票")
                .font(.system(size: 9, weight: .medium).monospaced())
                .foregroundStyle(pair.ink.opacity(0.55))

            HStack {
                Text("NO. \(CoverText.number(seed))\(CoverText.number(seed + 3))")
                    .font(.system(size: 9).monospaced())
                    .foregroundStyle(pair.ink.opacity(0.45))
                Spacer(minLength: 0)
                Text(CoverText.emoji(seed, offset: 7))
                    .font(.system(size: 11))
            }
            .padding(.top, 4)

            CoverDashedLine()
                .stroke(pair.ink.opacity(0.28), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                .frame(height: 1)
                .padding(.vertical, 9)

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(pair.ink)
                .lineSpacing(3)
                .lineLimit(3)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 6)

            CoverDashedLine()
                .stroke(pair.ink.opacity(0.20), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                .frame(height: 1)

            HStack(spacing: 4) {
                Text(tag.isEmpty ? "已记录" : "#\(tag)")
                    .font(.system(size: 9).monospaced())
                    .foregroundStyle(pair.ink.opacity(0.55))
                Spacer(minLength: 0)
                Text(CoverText.emoji(seed, offset: 11))
                    .font(.system(size: 11))
            }
            .padding(.top, 7)
        }
        .padding(EdgeInsets(top: 14, leading: 15, bottom: 14, trailing: 15))
    }
}
