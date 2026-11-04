import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 角色编辑器。新建和编辑共用一套表单。
///
/// 字段在本地 `@State` 里改，按「保存」才落库——这样取消不会留下半成品角色。
struct CharacterEditorView: View {
    var character: Companion?
    var onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var tintRaw = AvatarTint.mint.rawValue
    @State private var preset: RoleplayPreset = .daily
    @State private var persona = ""
    @State private var greeting = ""
    @State private var replyLength: ReplyLength = .medium
    @State private var isGroup = false
    @State private var membersNote = ""
    @State private var wakeHour = 7
    @State private var sleepHour = 23

    @State private var showImporter = false
    @State private var importMessage: String?
    @State private var showDeleteConfirm = false
    @State private var showWorldEntries = false

    private var isNew: Bool { character == nil }

    init(character: Companion?, onFinish: @escaping () -> Void) {
        self.character = character
        self.onFinish = onFinish

        _name = State(initialValue: character?.name ?? "")
        _tintRaw = State(initialValue: character?.avatarTintRaw ?? AvatarTint.mint.rawValue)
        _preset = State(initialValue: character?.preset ?? .daily)
        _persona = State(initialValue: character?.persona ?? "")
        _greeting = State(initialValue: character?.greeting ?? "")
        _replyLength = State(initialValue: character?.replyLength ?? .medium)
        _isGroup = State(initialValue: character?.isGroup ?? false)
        _membersNote = State(initialValue: character?.membersNote ?? "")
        _wakeHour = State(initialValue: character?.wakeHour ?? 7)
        _sleepHour = State(initialValue: character?.sleepHour ?? 23)
    }

    var body: some View {
        NavigationStack {
            Form {
                basicsSection
                presetSection
                personaSection
                scheduleSection
                importSection
                if !isNew { dangerSection }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle(isNew ? "新建角色" : "编辑角色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onFinish()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .font(.system(size: 15, weight: .semibold))
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.png, .json, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert("导入", isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )) {
                Button("好") { importMessage = nil }
            } message: {
                Text(importMessage ?? "")
            }
            .confirmationDialog("删除角色", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) { deleteCharacter() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("这个角色的全部聊天记录和摘要会一起删掉，不能恢复。")
            }
            .sheet(isPresented: $showWorldEntries) {
                if let character {
                    WorldEntryListView(character: character)
                }
            }
        }
    }

    // MARK: - 分区

    private var basicsSection: some View {
        Section {
            TextField("名字", text: $name)

            HStack(spacing: 8) {
                ForEach(AvatarTint.allCases) { tint in
                    Button {
                        tintRaw = tint.rawValue
                    } label: {
                        Circle()
                            .fill(tint.gradient)
                            .frame(width: 28, height: 28)
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        tintRaw == tint.rawValue ? Theme.cream : .clear,
                                        lineWidth: 2
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)

            Picker("回复长度", selection: $replyLength) {
                ForEach(ReplyLength.allCases) { length in
                    Text(length.displayName).tag(length)
                }
            }
            .pickerStyle(.segmented)

            Toggle("群聊", isOn: $isGroup)

            if isGroup {
                TextField("成员（逗号分隔，例如：阿岚，柏川，小满）", text: $membersNote, axis: .vertical)
                    .lineLimit(1...3)
            }
        } header: {
            Text("基本")
        } footer: {
            Text(isGroup
                 ? "群聊时模型会以「名字：台词」的形式分行输出，界面会自动拆成多个气泡。"
                 : "回复长度只是提示词里的约束，不会硬截断句子。")
        }
    }

    private var presetSection: some View {
        Section {
            Picker("对话形式", selection: $preset) {
                ForEach(RoleplayPreset.allCases) { item in
                    Text(item.displayName).tag(item)
                }
            }
            .pickerStyle(.segmented)

            Text(preset.blurb)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if isNew {
                Button("用「\(preset.displayName)」模板填一下") {
                    name = sampleName(for: preset)
                    persona = preset.samplePersona
                    greeting = preset.sampleGreeting
                }
                .font(.system(size: 13))
            }
        } header: {
            Text("玩法")
        }
    }

    private var personaSection: some View {
        Section {
            TextEditor(text: $persona)
                .frame(minHeight: 150)
                .font(.system(size: 14))

            TextField("开场白（第一次打开对话时它说的第一句）", text: $greeting, axis: .vertical)
                .lineLimit(2...4)
        } header: {
            Text("人设")
        } footer: {
            Text("直接写「你叫……」。这段会原样进系统提示词，写得越具体，它越不像在敷衍。")
        }
    }

    private var scheduleSection: some View {
        Section {
            Picker("睡觉", selection: $sleepHour) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(String(format: "%02d:00", hour)).tag(hour)
                }
            }
            Picker("起床", selection: $wakeHour) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(String(format: "%02d:00", hour)).tag(hour)
                }
            }

            if !isNew {
                Button {
                    showWorldEntries = true
                } label: {
                    HStack {
                        Text("设定集")
                        Spacer()
                        Text("关键词触发的背景设定")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("作息与设定")
        } footer: {
            Text("睡着的时段里回话会带困意、句子变短。设定集里的条目只有提到关键词时才会进提示词。")
        }
    }

    private var importSection: some View {
        Section {
            Button("从酒馆角色卡导入（PNG / JSON）") {
                showImporter = true
            }
        } footer: {
            Text("导入会覆盖当前的人设和开场白；名字为空时也会一起填上。")
        }
    }

    private var dangerSection: some View {
        Section {
            Button("删除这个角色", role: .destructive) {
                showDeleteConfirm = true
            }
        }
    }

    // MARK: - 动作

    private func sampleName(for preset: RoleplayPreset) -> String {
        switch preset {
        case .daily: return "阿岚"
        case .story: return "柏川"
        case .live: return "小满"
        case .letter: return "远"
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importMessage = "选文件失败：\(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let card = try CharacterCardImporter.load(from: url)
                if !card.name.isEmpty { name = card.name }
                if !card.persona.isEmpty { persona = card.persona }
                if !card.greeting.isEmpty { greeting = card.greeting }
                importMessage = "导入成功：读到 \(card.filledFields) 个字段。检查一下人设，再点保存。"
            } catch {
                importMessage = error.localizedDescription
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let target: Companion
        if let character {
            target = character
        } else {
            let existing = (try? context.fetch(FetchDescriptor<Companion>())) ?? []
            let nextIndex = (existing.map(\.sortIndex).max() ?? -1) + 1
            let created = Companion(
                name: trimmedName,
                persona: persona,
                greeting: greeting,
                preset: preset,
                avatarTintRaw: tintRaw,
                replyLength: replyLength,
                isGroup: isGroup,
                membersNote: membersNote,
                wakeHour: wakeHour,
                sleepHour: sleepHour,
                sortIndex: nextIndex
            )
            context.insert(created)
            target = created
        }

        target.name = trimmedName
        target.persona = persona
        target.greeting = greeting
        target.preset = preset
        target.avatarTintRaw = tintRaw
        target.replyLength = replyLength
        target.isGroup = isGroup
        target.membersNote = membersNote
        target.wakeHour = wakeHour
        target.sleepHour = sleepHour

        do {
            try context.save()
        } catch {
            AppLog.storage.error("保存角色失败: \(error.localizedDescription, privacy: .public)")
        }

        onFinish()
        dismiss()
    }

    private func deleteCharacter() {
        guard let character else { return }
        context.delete(character)
        try? context.save()
        onFinish()
        dismiss()
    }
}
