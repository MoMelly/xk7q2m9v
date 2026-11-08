import SwiftUI

/// 角色的记忆，只读。
///
/// 这里放的每一行都是对话里自己长出来的，不是手填的字段——
/// 所以能看、能删掉整份，但不能在这里改一句「他应该记得我喜欢猫」，
/// 那会让记忆和实际发生过的事对不上。
struct CharacterMemoryPage: View {
    let character: Companion
    let world: WorldStore

    private var person: PersonMemory? {
        world.state.people.first { $0.name == character.name }
    }

    private var facts: [PersonFact] {
        (person?.facts ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    private var openVoices: [InnerVoiceEntry] {
        (person?.voices ?? [])
            .filter { !$0.isResolved }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var resolvedVoices: [InnerVoiceEntry] {
        (person?.voices ?? [])
            .filter(\.isResolved)
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var days: [CharacterDay] {
        world.characterDays(named: character.name, limit: 14)
    }

    var body: some View {
        AppPage(title: "记忆") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.section) {
                    summarySection

                    GroupedSection(
                        "记得的事",
                        footer: facts.isEmpty
                            ? "还没记住具体的事。多聊几次，值得留下的会自己进来。"
                            : "每一轮都会带上这些，和你最近说的话更相关的排前面。记错了就长按删掉——留着错的，之后每轮都跟着错。"
                    ) {
                        if facts.isEmpty {
                            placeholder("还没有")
                        } else {
                            ForEach(facts) { fact in
                                GroupedRow(
                                    title: fact.text,
                                    subtitle: "\(fact.sourceName) · \(TimeFormat.callTime(fact.createdAt))"
                                )
                                .padding(.vertical, PhoneMetrics.Space.xs)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        world.deleteFact(person: character.name, id: fact.id)
                                    } label: {
                                        Label("这条记错了", systemImage: "trash")
                                    }
                                }

                                if fact.id != facts.last?.id {
                                    RowDivider()
                                }
                            }
                        }
                    }

                    if !openVoices.isEmpty || !resolvedVoices.isEmpty {
                        voicesSection
                    }

                    daysSection
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    // MARK: - 概括

    private var summarySection: some View {
        GroupedSection("他心里的你") {
            let summary = person?.summary.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if summary.isEmpty {
                placeholder("还没有形成概括。聊得够多之后，旧的对话会被压成一段。")
            } else {
                Text(summary)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(Theme.label)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(PhoneMetrics.Space.m)
            }
        }
    }

    // MARK: - 心事

    private var voicesSection: some View {
        GroupedSection(
            "没说出口的",
            footer: "没放下的会一直在，直到被聊开。放下了的留在这儿，不再提起。"
        ) {
            ForEach(Array(openVoices.enumerated()), id: \.element.id) { index, voice in
                voiceRow(voice, resolved: false)
                if index != openVoices.count - 1 || !resolvedVoices.isEmpty {
                    RowDivider()
                }
            }

            ForEach(Array(resolvedVoices.enumerated()), id: \.element.id) { index, voice in
                voiceRow(voice, resolved: true)
                if index != resolvedVoices.count - 1 {
                    RowDivider()
                }
            }
        }
    }

    private func voiceRow(_ voice: InnerVoiceEntry, resolved: Bool) -> some View {
        HStack(alignment: .top, spacing: PhoneMetrics.Space.s) {
            Image(systemName: resolved ? "checkmark.circle" : "bubble.left")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(resolved ? Theme.secondaryLabel.opacity(0.6) : Theme.IconTint.purple)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(voice.text)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(resolved ? Theme.secondaryLabel : Theme.label)
                    .strikethrough(resolved, color: Theme.secondaryLabel.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)

                Text(TimeFormat.callTime(voice.createdAt))
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(Theme.secondaryLabel.opacity(0.8))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.s)
    }

    // MARK: - 这几天的日子

    private var daysSection: some View {
        GroupedSection(
            "这几天的日子",
            footer: "只有当天说过话才会有这一天。没聊的日子不会凭空编出来。"
        ) {
            if days.isEmpty {
                placeholder("还没有留下任何一天")
            } else {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    dayRow(day)
                    if index != days.count - 1 {
                        RowDivider()
                    }
                }
            }
        }
    }

    private func dayRow(_ day: CharacterDay) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(MoodColor.of(day.mood))
                    .frame(width: 7, height: 7)

                Text(dayLabel(day.dateKey))
                    .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .semibold))
                    .foregroundStyle(Theme.label)

                Text(day.mood.label)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(Theme.secondaryLabel)

                Spacer(minLength: 0)

                if !day.didChat {
                    Text("没聊")
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(Theme.secondaryLabel.opacity(0.7))
                }
            }

            Text(day.items.map(\.title).joined(separator: "、"))
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .foregroundStyle(Theme.secondaryLabel)
                .lineLimit(2)

            if !day.summary.isEmpty {
                Text(day.summary)
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(Theme.label.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 1)
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayLabel(_ key: String) -> String {
        TimeFormat.dayLabel(key)
    }

    // MARK: - 小组件

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: PhoneMetrics.FontSize.footnote))
            .foregroundStyle(Theme.secondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PhoneMetrics.Space.m)
    }
}
