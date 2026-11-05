import SwiftUI

/// 原始回复。
///
/// 这一页是给「模型到底吐了什么」用的，不做任何格式化：正文、状态块、
/// 写歪的标签都按原样列出来。解析失败的那几条在最上面标红，
/// 一眼能看出是模型写坏了，还是解析写窄了。
struct RawReplyPage: View {
    /// 用计算属性而不是 `@State`：这个日志是全局单例，
    /// 属性初始化器在非隔离的 init 里跑，直接取 `shared` 会踩并发检查。
    private var log: RawReplyLog { RawReplyLog.shared }

    private var failedCount: Int {
        log.records.filter { $0.hasMeta && !$0.parsedOK }.count
    }

    var body: some View {
        AppPage(title: "原始回复") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.m) {
                    summary

                    if log.records.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: PhoneMetrics.Space.xs) {
                            ForEach(log.records) { record in
                                NavigationLink {
                                    RawReplyDetailPage(record: record)
                                } label: {
                                    card(record)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, PhoneMetrics.Space.m)

                        Button("清空全部记录", role: .destructive) {
                            log.clear()
                        }
                        .font(.system(size: PhoneMetrics.FontSize.sub))
                        .padding(.top, PhoneMetrics.Space.s)
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    private var summary: some View {
        GroupedSection(
            footer: "只记最近 200 条，存在本机。点一条能看模型的原样输出。"
        ) {
            GroupedRow(title: "累计", value: "\(log.records.count) 条")
            RowDivider()
            GroupedRow(
                title: "状态块解析失败",
                value: "\(failedCount) 条"
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: PhoneMetrics.Space.xs) {
            Image(systemName: "text.bubble")
                .font(.system(size: 26))
            Text("还没有记录")
                .font(.system(size: PhoneMetrics.FontSize.body, weight: .medium))
            Text("跟角色聊一句，这里就会留下模型的原样输出。")
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Theme.secondaryLabel)
        .frame(maxWidth: .infinity)
        .padding(.vertical, PhoneMetrics.Space.section)
    }

    private func card(_ record: RawReplyRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: PhoneMetrics.Space.xs) {
                Text(record.characterName)
                    .font(.system(size: PhoneMetrics.FontSize.sub, weight: .semibold))
                    .foregroundStyle(Theme.label)

                badge(for: record)

                Spacer(minLength: 0)

                Text(TimeFormat.callTime(record.at))
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(Theme.secondaryLabel)
                    .monospacedDigit()
            }

            Text(record.preview)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(Theme.label)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: PhoneMetrics.Space.xs) {
                Text("\(record.raw.count) 字")
                if record.metaText != nil {
                    Text("含状态块")
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .font(.system(size: PhoneMetrics.FontSize.caption))
            .foregroundStyle(Theme.secondaryLabel)
        }
        .padding(PhoneMetrics.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                .fill(Theme.rowSurface)
        )
    }

    private func badge(for record: RawReplyRecord) -> some View {
        let text: String
        let color: Color
        if record.metaText == nil {
            text = "无状态块"
            color = Theme.secondaryLabel
        } else if record.parsedOK {
            text = "已解析"
            color = Theme.IconTint.green
        } else {
            text = "解析失败"
            color = Theme.IconTint.pink
        }

        return Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(color.opacity(0.12))
            )
    }
}

/// 单条原始回复。
struct RawReplyDetailPage: View {
    let record: RawReplyRecord

    var body: some View {
        AppPage(title: "回复详情") {
            ScrollView {
                VStack(alignment: .leading, spacing: PhoneMetrics.Space.l) {
                    meta

                    section(
                        title: "上屏正文",
                        note: "解析之后真正显示在聊天里的内容",
                        text: record.visible.isEmpty ? "（空）" : record.visible
                    )

                    if let block = record.metaText {
                        section(
                            title: "状态块",
                            note: record.parsedOK ? "解析成功" : "解析失败，这一轮的状态增量被丢弃",
                            text: block
                        )
                    }

                    section(
                        title: "原始输出",
                        note: "模型返回的全部内容，未经任何处理",
                        text: record.raw
                    )
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    private var meta: some View {
        GroupedSection {
            GroupedRow(title: "角色", value: record.characterName)
            RowDivider()
            GroupedRow(title: "模型", value: record.model)
            RowDivider()
            GroupedRow(title: "时间", value: TimeFormat.callTime(record.at))
            RowDivider()
            GroupedRow(title: "字数", value: "\(record.raw.count)")
        }
    }

    private func section(title: String, note: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: PhoneMetrics.Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: PhoneMetrics.Space.xs) {
                Text(title)
                    .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .semibold))
                    .foregroundStyle(Theme.secondaryLabel)
                Text(note)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(Theme.secondaryLabel.opacity(0.7))
                Spacer(minLength: 0)
            }

            Text(text)
                .font(.system(size: PhoneMetrics.FontSize.footnote).monospaced())
                .foregroundStyle(Theme.label)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(PhoneMetrics.Space.s)
                .background(
                    RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                        .fill(Theme.rowSurface)
                )
        }
        .padding(.top, PhoneMetrics.Space.xs)
    }
}
