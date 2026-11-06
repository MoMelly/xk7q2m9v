import SwiftUI

/// 八种封面的文字排版。
///
/// 拆出来是因为这一个文件已经四百多行：底色和分发留在 `NoteCover.swift`，
/// 这里只管「字怎么摆」。每加一种版式只动这一个文件。
extension NoteCover {
    /// 海报：emoji 占角、话题贴右上、标题压左下，下面挂一条深色小条。
    var poster: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                Text(CoverText.emoji(seed))
                    .font(.system(size: 24))

                Spacer(minLength: 0)

                if !tag.isEmpty {
                    Text(tag)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(pair.accent))
                        .rotationEffect(.degrees(4))
                }
            }

            Spacer(minLength: 6)

            Text(title)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(pair.ink)
                .lineSpacing(3)
                .lineLimit(4)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)

            if let highlight {
                Text(highlight)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(pair.ink.opacity(0.82)))
                    .padding(.top, 7)
            }
        }
        .padding(11)
    }

    /// 便签：一张歪一点的纸、一条胶带、手写感的标题。
    var sticky: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .padding(EdgeInsets(top: 15, leading: 11, bottom: 11, trailing: 11))
                .rotationEffect(.degrees(-1.6))

            Rectangle()
                .fill(pair.accent.opacity(0.30))
                .frame(width: 46, height: 12)
                .rotationEffect(.degrees(-5))
                .offset(y: 8)

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(pair.ink)
                    .lineSpacing(3)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 6)

                HStack(spacing: 4) {
                    Text(CoverText.emoji(seed, offset: 3))
                        .font(.system(size: 13))
                    if !tag.isEmpty {
                        Text("#\(tag)")
                            .font(.system(size: 9))
                            .foregroundStyle(pair.ink.opacity(0.55))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(EdgeInsets(top: 22, leading: 20, bottom: 20, trailing: 20))
        }
    }

    /// 清单：标题带一道短下划线，下面几行圆点。
    var checklist: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(pair.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Rectangle()
                .fill(pair.accent)
                .frame(width: 24, height: 2)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(CoverText.sentences(coverBody, limit: 3).enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 5) {
                        Circle()
                            .fill(pair.accent)
                            .frame(width: 3, height: 3)
                            .padding(.top, 5)

                        Text(line)
                            .font(.system(size: 10))
                            .foregroundStyle(pair.ink.opacity(0.80))
                            .lineLimit(2)
                    }
                }
            }
            .padding(.top, 9)

            Spacer(minLength: 0)

            if !tag.isEmpty {
                Text("#\(tag)")
                    .font(.system(size: 9))
                    .foregroundStyle(pair.ink.opacity(0.45))
            }
        }
        .padding(11)
    }

    /// 杂志：一个大编号，标题压在编号下面，底部一道细线。
    var magazine: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Text(CoverText.number(seed))
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(pair.accent.opacity(0.92))

                Spacer(minLength: 0)

                Text(CoverText.emoji(seed, offset: 5))
                    .font(.system(size: 14))
                    .padding(.top, 6)
            }

            Spacer(minLength: 4)

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(pair.ink)
                .lineSpacing(2)
                .lineLimit(3)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(pair.ink.opacity(0.16))
                .frame(height: 0.5)
                .padding(.top, 8)

            if !tag.isEmpty {
                Text(tag.uppercased())
                    .font(.system(size: 8, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(pair.ink.opacity(0.5))
                    .padding(.top, 5)
                    .lineLimit(1)
            }
        }
        .padding(EdgeInsets(top: 10, leading: 13, bottom: 10, trailing: 11))
    }

    /// 引号：一句话居中排，像摘抄。
    var quote: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("“")
                .font(.system(size: 40, weight: .bold, design: .serif))
                .foregroundStyle(pair.accent.opacity(0.75))
                .frame(height: 26, alignment: .top)

            Spacer(minLength: 0)

            Text(title)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(pair.ink)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if !tag.isEmpty {
                Text("— \(tag)")
                    .font(.system(size: 9))
                    .foregroundStyle(pair.ink.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(EdgeInsets(top: 9, leading: 13, bottom: 11, trailing: 12))
    }

    /// 竖排：标题从上往下走，左边留一块放 emoji 和话题。
    var vertical: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Spacer(minLength: 0)

                Text(CoverText.emoji(seed, offset: 2))
                    .font(.system(size: 22))

                if !tag.isEmpty {
                    Text(tag)
                        .font(.system(size: 9))
                        .foregroundStyle(pair.ink.opacity(0.55))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            verticalTitle
        }
        .padding(EdgeInsets(top: 11, leading: 11, bottom: 11, trailing: 38))
    }

    var verticalTitle: some View {
        let characters = Array(title.prefix(14))
        let columns: [[Character]] = stride(from: 0, to: characters.count, by: 6).map { start in
            Array(characters[start..<min(start + 6, characters.count)])
        }

        return HStack(alignment: .top, spacing: 3) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                VStack(spacing: 1) {
                    ForEach(Array(column.enumerated()), id: \.offset) { _, character in
                        Text(String(character))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(pair.ink)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// 票根：标题在上，虚线撕口在中间，话题在下。
    var ticket: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(pair.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)

            CoverDashedLine()
                .stroke(
                    pair.ink.opacity(0.32),
                    style: StrokeStyle(lineWidth: 0.8, dash: [3, 3])
                )
                .frame(height: 1)
                .padding(.vertical, 9)

            HStack(spacing: 4) {
                Text(tag.isEmpty ? "西瓜皮" : "#\(tag)")
                    .font(.system(size: 9))
                    .foregroundStyle(pair.ink.opacity(0.55))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(CoverText.emoji(seed, offset: 4))
                    .font(.system(size: 10))
            }

            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 12, leading: 13, bottom: 12, trailing: 13))
    }

    /// 照片：白字压在压暗的下半部，像真图上的配字。
    var photo: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineSpacing(2)
                .lineLimit(3)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)

            if !tag.isEmpty {
                Text("#\(tag)")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    /// 海报版式下面那条深色小条：取正文第一句的前半截。
    var highlight: String? {
        guard style == .poster else { return nil }
        let line = CoverText.sentences(coverBody, limit: 1).first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard line.count >= 2 else { return nil }
        return String(line.prefix(11))
    }
}
