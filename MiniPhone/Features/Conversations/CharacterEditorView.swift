import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 角色编辑器。新建和编辑共用一套表单。
///
/// 不用系统 Form：外壳强制深色，Form 的 grouped 单元格会跟着变黑，
/// 压在深绿渐变上就是一层脏灰框。改成微信那样的白色顶栏 + 白卡分组，
/// 字段仍先在 @State 里改，按「保存」才落库，取消不会留下半成品。
struct CharacterEditorView: View {
    var character: Companion?
    var onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var tintRaw = AvatarTint.mint.rawValue
    @State private var avatarKey = ""
    @State private var avatarFile = ""
    @State private var showAvatarPicker = false
    @State private var preset: RoleplayPreset = .daily
    @State private var persona = ""
    @State private var greeting = ""
    @State private var replyLength: ReplyLength = .medium
    @State private var isGroup = false
    @State private var membersNote = ""
    @State private var wakeHour = 7
    @State private var sleepHour = 23
    @State private var signature = ""
    @State private var tagsText = ""

    @State private var showImporter = false
    @State private var importMessage: String?
    @State private var showDeleteConfirm = false
    @State private var showWorldEntries = false

    private var isNew: Bool { character == nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    init(character: Companion?, onFinish: @escaping () -> Void) {
        self.character = character
        self.onFinish = onFinish

        _name = State(initialValue: character?.name ?? "")
        _tintRaw = State(initialValue: character?.avatarTintRaw ?? AvatarTint.mint.rawValue)
        _avatarKey = State(initialValue: character?.avatarImageKey ?? "")
        _avatarFile = State(initialValue: character?.avatarFileName ?? "")
        _preset = State(initialValue: character?.preset ?? .daily)
        _persona = State(initialValue: character?.persona ?? "")
        _greeting = State(initialValue: character?.greeting ?? "")
        _replyLength = State(initialValue: character?.replyLength ?? .medium)
        _isGroup = State(initialValue: character?.isGroup ?? false)
        _membersNote = State(initialValue: character?.membersNote ?? "")
        _wakeHour = State(initialValue: character?.wakeHour ?? 7)
        _sleepHour = State(initialValue: character?.sleepHour ?? 23)
        _signature = State(initialValue: character?.signature ?? "")
        _tagsText = State(initialValue: character?.tags.joined(separator: "，") ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                navBar

                ScrollView {
                    VStack(spacing: PhoneMetrics.Space.m) {
                        basicsCard
                        profileCard
                        presetCard
                        personaCard
                        scheduleCard
                        importCard
                        if !isNew { dangerCard }
                    }
                    .padding(PhoneMetrics.Space.m)
                    .padding(.bottom, PhoneMetrics.Space.xl)
                }
            }
            .background(AppSurface.light.background.ignoresSafeArea())
            .environment(\.colorScheme, .light)
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
            .sheet(isPresented: $showAvatarPicker) {
                AvatarPickerSheet(
                    fallbackNote: "不用照片时，头像显示名字第一个字。",
                    imageKey: $avatarKey,
                    fileName: $avatarFile
                )
            }
            .onAppear {
                // 截图流水线要点开换头像面板才看得到三组头像，冷启动点不了。
                if UserDefaults.standard.string(forKey: "previewState") == "avatarPicker" {
                    showAvatarPicker = true
                }
            }
        }
    }

    // MARK: - 头像

    private var avatarTint: AvatarTint {
        AvatarTint(rawValue: tintRaw) ?? .mint
    }

    /// 上传优先，其次内置。跟 `Companion.avatarPhoto` 一个顺序，
    /// 不然编辑器里看到的和存完看到的不是同一张。
    private var previewPhoto: UIImage? {
        if !avatarFile.isEmpty, let uploaded = AvatarPhoto.load(fileName: avatarFile) {
            return uploaded
        }
        if !avatarKey.isEmpty {
            return AvatarPhoto.builtIn(key: avatarKey)
        }
        return nil
    }

    private var previewInitial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "?" : String(trimmed.prefix(1))
    }

    // MARK: - 顶栏与卡片骨架

    /// 微信式：左边取消、中间标题、右边一个实心保存按钮，底下一条细分隔线。
    private var navBar: some View {
        ZStack {
            Text(isNew ? "新建角色" : "编辑角色")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppSurface.light.label)

            HStack {
                Button("取消") {
                    onFinish()
                    dismiss()
                }
                .font(.system(size: 15))
                .foregroundStyle(AppSurface.light.secondaryLabel)

                Spacer(minLength: 0)

                Button(action: save) {
                    Text("保存")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(canSave ? Theme.retroGreen : AppSurface.light.separator)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .frame(height: 50)
        .background(AppSurface.light.rowSurface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppSurface.light.separator.opacity(0.7))
                .frame(height: 0.5)
        }
    }

    private func card<Content: View>(
        _ title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: PhoneMetrics.FontSize.caption, weight: .medium))
                .foregroundStyle(AppSurface.light.secondaryLabel)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 11) {
                content()
            }
            .padding(PhoneMetrics.Space.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppSurface.light.rowSurface)
            .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.grouped, style: .continuous))

            if let footer {
                Text(footer)
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(AppSurface.light.label)
                .frame(width: 58, alignment: .leading)
            content()
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(AppSurface.light.separator.opacity(0.6))
            .frame(height: 0.5)
    }

    // MARK: - 分区

    private var basicsCard: some View {
        card("基本") {
            labeled("名字") {
                TextField("给这个角色起个名字", text: $name)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
            }
            divider
            HStack(spacing: PhoneMetrics.Space.s) {
                Text("头像")
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(AppSurface.light.label)
                    .frame(width: 58, alignment: .leading)

                Button {
                    showAvatarPicker = true
                } label: {
                    ZStack {
                        if let photo = previewPhoto {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Circle().fill(avatarTint.gradient)
                            Text(previewInitial)
                                .font(.system(size: 18, weight: .semibold, design: .serif))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)

                Text(previewPhoto == nil ? "选一张照片" : "换一张")
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(AppSurface.light.secondaryLabel)

                Spacer(minLength: 0)
            }
            divider
            HStack(spacing: 8) {
                Text("底色")
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(AppSurface.light.label)
                    .frame(width: 58, alignment: .leading)
                ForEach(AvatarTint.allCases) { tint in
                    Button {
                        tintRaw = tint.rawValue
                    } label: {
                        Circle()
                            .fill(tint.gradient)
                            .frame(width: 26, height: 26)
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        tintRaw == tint.rawValue ? Theme.retroGreen : .clear,
                                        lineWidth: 2
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            divider
            HStack(spacing: 10) {
                Text("长度")
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(AppSurface.light.label)
                    .frame(width: 58, alignment: .leading)
                Picker("", selection: $replyLength) {
                    ForEach(ReplyLength.allCases) { length in
                        Text(length.displayName).tag(length)
                    }
                }
                .pickerStyle(.segmented)
            }
            divider
            Toggle("群聊", isOn: $isGroup)
                .font(.system(size: PhoneMetrics.FontSize.sub))
            if isGroup {
                TextField("成员，逗号分隔", text: $membersNote)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
            }
        }
    }

    private var profileCard: some View {
        card("主页") {
            labeled("签名") {
                TextField("主页上那一行", text: $signature)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
            }
            divider
            labeled("标签") {
                TextField("逗号分隔", text: $tagsText)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
            }
        }
    }

    private var presetCard: some View {
        card("玩法", footer: preset.blurb) {
            Picker("", selection: $preset) {
                ForEach(RoleplayPreset.allCases) { item in
                    Text(item.displayName).tag(item)
                }
            }
            .pickerStyle(.segmented)

            if isNew {
                Button("用「\(preset.displayName)」模板填一下") {
                    name = sampleName(for: preset)
                    persona = preset.samplePersona
                    greeting = preset.sampleGreeting
                }
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(Theme.tint)
            }
        }
    }

    private var personaCard: some View {
        card("人设", footer: "直接写「你叫……」。这段会原样进系统提示词。") {
            TextEditor(text: $persona)
                .frame(minHeight: 140)
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(AppSurface.light.label)
            divider
            labeled("开场白") {
                TextField("第一次打开对话时它说的第一句", text: $greeting, axis: .vertical)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .lineLimit(2...4)
            }
        }
    }

    private var scheduleCard: some View {
        card("作息与设定") {
            HStack {
                Text("睡觉")
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(AppSurface.light.label)
                Spacer(minLength: 0)
                Picker("", selection: $sleepHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
                }
                .labelsHidden()
            }
            divider
            HStack {
                Text("起床")
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(AppSurface.light.label)
                Spacer(minLength: 0)
                Picker("", selection: $wakeHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
                }
                .labelsHidden()
            }
            if !isNew {
                divider
                Button {
                    showWorldEntries = true
                } label: {
                    HStack {
                        Text("设定集")
                            .font(.system(size: PhoneMetrics.FontSize.sub))
                            .foregroundStyle(AppSurface.light.label)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundStyle(AppSurface.light.secondaryLabel)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var importCard: some View {
        card("导入", footer: "导入会覆盖当前的人设和开场白；名字为空时也会一起填上。") {
            Button {
                showImporter = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14))
                    Text("从酒馆角色卡导入（PNG / JSON）")
                        .font(.system(size: PhoneMetrics.FontSize.sub))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Theme.tint)
            }
            .buttonStyle(.plain)
        }
    }

    private var dangerCard: some View {
        card("危险操作") {
            Button("删除这个角色") {
                showDeleteConfirm = true
            }
            .font(.system(size: PhoneMetrics.FontSize.sub))
            .foregroundStyle(Theme.price)
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
        target.avatarImageKey = avatarKey
        target.avatarFileName = avatarFile
        // 新建时没挑头像就随手给一张。只在新建这一次给：
        // 编辑页里用户主动选了「不用照片」，再塞一张回去就成了撤销不了的操作。
        if isNew, avatarKey.isEmpty, avatarFile.isEmpty {
            target.avatarImageKey = AvatarPhoto.randomKey()
        }
        target.replyLength = replyLength
        target.isGroup = isGroup
        target.membersNote = membersNote
        target.wakeHour = wakeHour
        target.sleepHour = sleepHour
        target.signature = signature.trimmingCharacters(in: .whitespacesAndNewlines)
        target.tags = tagsText
            .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "、" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

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
