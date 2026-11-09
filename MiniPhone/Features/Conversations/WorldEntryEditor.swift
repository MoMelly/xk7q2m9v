import SwiftData
import SwiftUI

/// 新增和修改一条设定，共用一套字段。
///
/// 之前只有「常驻 / 关键词」两档、一个关键词输入框，改一条只能删了重建。
/// 现在三种触发各有自己的字段，编辑和新建走同一张表，改完保存就是同一条。
struct WorldEntryEditor: View {
    /// 传 nil 表示新建。
    let entry: WorldEntry?
    /// 新建时挂到谁名下。nil 表示对所有人生效。
    let defaultOwner: UUID?
    /// 列表页里看见的角色名，只用于说明文案。
    let ownerName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var trigger: WorldTrigger
    @State private var position: WorldPosition
    @State private var priority: Int
    @State private var content: String
    @State private var keywords: String
    @State private var isGlobal: Bool
    @State private var enabled: Bool
    @State private var phases: Set<DayPhase>
    @State private var moods: Set<Mood>
    @State private var locationNeedle: String
    @State private var minDays: Int

    init(entry: WorldEntry?, defaultOwner: UUID?, ownerName: String) {
        self.entry = entry
        self.defaultOwner = defaultOwner
        self.ownerName = ownerName
        _trigger = State(initialValue: entry?.kind ?? .constant)
        _position = State(initialValue: entry?.position ?? .front)
        _priority = State(initialValue: entry?.priority ?? 5)
        _content = State(initialValue: entry?.content ?? "")
        _keywords = State(initialValue: entry?.keywords ?? "")
        _isGlobal = State(initialValue: entry?.isGlobal ?? (defaultOwner == nil))
        _enabled = State(initialValue: entry?.enabled ?? true)
        _phases = State(initialValue: Set(entry?.phaseList ?? []))
        _moods = State(initialValue: Set(entry?.moodList ?? []))
        _locationNeedle = State(initialValue: entry?.condLocation ?? "")
        _minDays = State(initialValue: entry?.condMinDays ?? 0)
    }

    private var isNew: Bool { entry == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.l) {
                    triggerSection
                    contentSection
                    if trigger == .keyword { keywordSection }
                    if trigger == .condition { conditionSection }
                    placementSection
                    scopeSection
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
            .background(Theme.groupedBackground)
            .navigationTitle(isNew ? "新设定" : "改设定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Theme.secondaryLabel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .foregroundStyle(canSave ? Theme.brand : Theme.secondaryLabel)
                        .disabled(!canSave)
                }
            }
        }
        .environment(\.colorScheme, ThemeStore.shared.isNight ? .dark : .light)
        .presentationDetents([.large])
    }

    // MARK: - 触发方式

    private var triggerSection: some View {
        GroupedSection("什么时候用得上", footer: triggerFooter) {
            SegmentedTabs(items: WorldTrigger.allCases, title: \.label, selection: $trigger)
                .padding(.horizontal, PhoneMetrics.Space.m)
                .padding(.vertical, PhoneMetrics.Space.s)
        }
    }

    private var triggerFooter: String {
        switch trigger {
        case .constant:
            return "每轮都带上。基本设定写在这里：你们住哪儿、他做什么、家里有谁。"
        case .condition:
            return "状态对上了才带上。比如「夜里不太愿意提工作」——用户一晚上没提工作，角色也该知道。底下四组条件可以叠加。"
        case .keyword:
            return "聊天里提到关键词才注入。灯塔、旧伤、那只猫的名字，这类用到才想起来的细节。"
        }
    }

    // MARK: - 内容

    private var contentSection: some View {
        GroupedSection("内容", footer: "写成一句陈述，不要写指令。「你们住在城西的老小区」比「请记住你们住城西」有效。") {
            TextEditor(text: $content)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(Theme.label)
                .tint(Theme.brand)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 130)
                .padding(.horizontal, PhoneMetrics.Space.s)
                .padding(.vertical, PhoneMetrics.Space.xs)
                .overlay(alignment: .topLeading) {
                    if content.isEmpty {
                        Text("比如：你们住在城西的老小区，六楼没电梯。")
                            .font(.system(size: PhoneMetrics.FontSize.sub))
                            .foregroundStyle(Theme.secondaryLabel.opacity(0.7))
                            .padding(.horizontal, PhoneMetrics.Space.m)
                            .padding(.vertical, PhoneMetrics.Space.s)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - 关键词

    private var keywordSection: some View {
        GroupedSection("关键词", footer: "逗号分隔。聊天内容里出现任一个，上面那段就会被带上。") {
            TextField("灯塔，旧伤，那只猫", text: $keywords)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(Theme.label)
                .tint(Theme.brand)
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.single)
        }
    }

    // MARK: - 条件

    private var conditionSection: some View {
        VStack(spacing: PhoneMetrics.Space.l) {
            GroupedSection("时段", footer: "不选表示不限时间。选了多个，命中任意一个就算成立。") {
                chipGrid(items: DayPhase.allCases, title: { "\($0.label) \($0.hourRange)" }, selection: $phases)
                    .padding(PhoneMetrics.Space.s)
            }

            GroupedSection("心情", footer: "只在他心情是选中的那几种时成立。他现在没有心情记录的话，这一条不会通过。") {
                chipGrid(items: Mood.allCases, title: \.label, selection: $moods)
                    .padding(PhoneMetrics.Space.s)
            }

            GroupedSection("地点", footer: "他当前所在地包含这几个字时成立。留空表示不限。") {
                TextField("比如：学校、公司、家", text: $locationNeedle)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(Theme.label)
                    .tint(Theme.brand)
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .frame(minHeight: PhoneMetrics.Row.single)
            }

            GroupedSection("认识满", footer: "从把角色加进手机那天算起。0 表示不限。") {
                HStack {
                    Text(minDays == 0 ? "不限" : "\(minDays) 天")
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(Theme.label)

                    Spacer(minLength: 0)

                    Stepper(
                        "",
                        value: $minDays,
                        in: 0...365,
                        step: 1
                    )
                    .labelsHidden()
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.single)
            }
        }
    }

    /// 多选胶囊。用自适应网格而不是横向滚动：选项最多七个，全铺开一眼看全，
    /// 横滚会让人以为后面还有。
    private func chipGrid<Item: Hashable>(
        items: [Item],
        title: @escaping (Item) -> String,
        selection: Binding<Set<Item>>
    ) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 78), spacing: PhoneMetrics.Space.xs)],
            alignment: .leading,
            spacing: PhoneMetrics.Space.xs
        ) {
            ForEach(items, id: \.self) { item in
                let picked = selection.wrappedValue.contains(item)
                Button {
                    withAnimation(.easeOut(duration: 0.14)) {
                        if picked {
                            selection.wrappedValue.remove(item)
                        } else {
                            selection.wrappedValue.insert(item)
                        }
                    }
                } label: {
                    Text(title(item))
                        .font(.system(size: PhoneMetrics.FontSize.caption, weight: picked ? .semibold : .regular))
                        .foregroundStyle(picked ? Color.white : Theme.label)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(picked ? Theme.brand : Theme.separator.opacity(0.22))
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 位置与优先级

    private var placementSection: some View {
        VStack(spacing: PhoneMetrics.Space.l) {
            GroupedSection("放在哪", footer: position.hint) {
                SegmentedTabs(items: WorldPosition.allCases, title: \.label, selection: $position)
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .padding(.vertical, PhoneMetrics.Space.s)
            }

            GroupedSection("优先级", footer: "1–10，大的排在前面。同一组超过上限时，排在后面的会先被挤掉。") {
                HStack {
                    Text("\(priority)")
                        .font(.system(size: PhoneMetrics.FontSize.body, weight: .semibold))
                        .foregroundStyle(Theme.label)
                        .frame(minWidth: 24, alignment: .leading)

                    Slider(
                        value: Binding(
                            get: { Double(priority) },
                            set: { priority = Int($0.rounded()) }
                        ),
                        in: 1...10,
                        step: 1
                    )
                    .tint(Theme.brand)
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.single)
            }
        }
    }

    // MARK: - 作用范围

    private var scopeSection: some View {
        GroupedSection(
            "这条设定对谁成立",
            footer: isGlobal
                ? "对所有人生效。世界观、城市、时代这类人人共用的事放这里。"
                : "只对\(ownerName)生效。"
        ) {
            Toggle(isOn: $isGlobal) {
                Text("对所有人生效")
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(Theme.label)
            }
            .tint(Theme.brand)
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: PhoneMetrics.Row.single)

            if !isNew {
                RowDivider()
                Toggle(isOn: $enabled) {
                    Text("启用")
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(Theme.label)
                }
                .tint(Theme.brand)
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.single)
            }
        }
    }

    // MARK: - 存

    private var canSave: Bool {
        let hasContent = !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasContent else { return false }
        if trigger == .keyword {
            return !keywords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func save() {
        guard canSave else { return }
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanKeywords = keywords.trimmingCharacters(in: .whitespacesAndNewlines)

        let target: WorldEntry
        if let entry {
            target = entry
        } else {
            target = WorldEntry(
                characterUID: isGlobal ? nil : defaultOwner,
                keywords: cleanKeywords,
                content: cleanContent,
                kind: trigger,
                priority: priority,
                position: position
            )
            context.insert(target)
        }

        target.characterUID = isGlobal ? nil : (target.characterUID ?? defaultOwner)
        target.kind = trigger
        target.position = position
        target.priority = priority
        target.content = cleanContent
        // 换成常驻或条件之后关键词就没用了，但留着不碍事：切回来时还在。
        target.keywords = cleanKeywords
        target.enabled = enabled
        target.condPhases = phases.map(\.rawValue).sorted().joined(separator: ",")
        target.condMoods = moods.map(\.rawValue).sorted().joined(separator: ",")
        target.condLocation = locationNeedle.trimmingCharacters(in: .whitespacesAndNewlines)
        target.condMinDays = max(0, minDays)

        try? context.save()
        dismiss()
    }
}
