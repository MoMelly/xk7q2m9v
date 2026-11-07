import SwiftUI
import SwiftData

/// 「信息」第四格：我的资料。
///
/// 这一页只做目录：名字、签名、状态、头像各占一行，编辑全部收进次级页。
/// 之前把头像、符号网格、底色、状态条全铺在一页上，看着像一张表单，
/// 找一个要改的东西得扫整屏；列表加次级页是系统设置的标准走法。
struct MyProfilePage: View {
    @Bindable var profile: UserProfile

    @Environment(\.modelContext) private var context
    @State private var showAvatarPicker = false
    /// 正在编辑的次级页。宿主没有导航栈，「信息」页自己拼的顶栏加 tabBar
    /// 也不适合被推入，所以次级菜单全走模态。
    @State private var activeEditor: ActiveEditor?

    enum ActiveEditor: String, Identifiable {
        case name, signature, status, symbol, tint
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PhoneMetrics.Space.m) {
                header

                GroupedSection(
                    "资料",
                    footer: "名字、签名和状态会进角色的提示词。想用别的身份跟角色聊天，去「设置 → 我的人设」另建一个。"
                ) {
                    Button {
                        activeEditor = .name
                    } label: {
                        GroupedRow(
                            symbol: "person.fill",
                            symbolTint: Theme.IconTint.gray,
                            title: "名字",
                            value: profile.name.isEmpty ? nil : profile.name,
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)

                    RowDivider()

                    Button {
                        activeEditor = .signature
                    } label: {
                        GroupedRow(
                            symbol: "pencil.line",
                            symbolTint: Theme.IconTint.green,
                            title: "签名",
                            value: profile.signature.isEmpty ? nil : profile.signature,
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)

                    RowDivider()

                    Button {
                        activeEditor = .status
                    } label: {
                        GroupedRow(
                            symbol: "sparkles",
                            symbolTint: Theme.IconTint.purple,
                            title: "状态",
                            value: profile.statusText.isEmpty ? "没设" : profile.statusText,
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                }

                GroupedSection(
                    "头像",
                    footer: "有照片时符号不显示。想用回符号，在「换头像」里选「不用照片」。"
                ) {
                    Button {
                        showAvatarPicker = true
                    } label: {
                        GroupedRow(
                            symbol: "photo.on.rectangle",
                            symbolTint: Theme.IconTint.orange,
                            title: "换头像",
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)

                    RowDivider()

                    Button {
                        activeEditor = .symbol
                    } label: {
                        GroupedRow(
                            symbol: "face.smiling",
                            symbolTint: Theme.IconTint.indigo,
                            title: "符号头像",
                            value: profile.avatarSymbol.isEmpty ? "首字" : "已选",
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)

                    RowDivider()

                    Button {
                        activeEditor = .tint
                    } label: {
                        GroupedRow(
                            symbol: "paintpalette.fill",
                            symbolTint: Theme.IconTint.pink,
                            title: "底色",
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, PhoneMetrics.Space.s)
            .padding(.bottom, PhoneMetrics.Space.xl)
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .onDisappear(perform: save)
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPickerSheet(
                fallbackNote: "不用照片时，显示首字或符号头像。",
                imageKey: $profile.avatarImageKey,
                fileName: $profile.avatarFileName
            )
            .onDisappear(perform: save)
        }
        .sheet(item: $activeEditor) { editor in
            NavigationStack {
                editorPage(editor)
            }
            .environment(\.colorScheme, .light)
            .onDisappear(perform: save)
        }
    }

    @ViewBuilder
    private func editorPage(_ editor: ActiveEditor) -> some View {
        let base = Group {
            switch editor {
            case .name:
                ProfileFieldPage(title: "名字", placeholder: "我", text: $profile.name)
            case .signature:
                ProfileFieldPage(title: "签名", placeholder: "一句话", text: $profile.signature)
            case .status:
                ProfileStatusPage(profile: profile)
            case .symbol:
                ProfileSymbolPage(profile: profile)
            case .tint:
                ProfileTintPage(profile: profile)
            }
        }

        base.toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { activeEditor = nil }
            }
        }
    }

    // MARK: - 页头

    /// 只负责认人：头像、名字、现在的状态。可点的编辑都在下面的分组里。
    private var header: some View {
        VStack(spacing: PhoneMetrics.Space.xs) {
            Button {
                showAvatarPicker = true
            } label: {
                currentAvatar
            }
            .buttonStyle(.plain)

            Text(profile.name.isEmpty ? "我" : profile.name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppSurface.light.label)

            if !profile.statusText.isEmpty {
                HStack(spacing: 5) {
                    if let item = StickerLibrary.shared.item(named: profile.statusStickerName) {
                        StickerView(item: item, size: 18)
                    }
                    Text(profile.statusText)
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PhoneMetrics.Space.s)
    }

    private var currentAvatar: some View {
        let tint = AvatarTint(rawValue: profile.avatarTintRaw) ?? .mint

        return ZStack {
            if let photo = profile.avatarPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(tint.gradient)

                if profile.avatarSymbol.isEmpty {
                    Text(String(profile.name.prefix(1)))
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: profile.avatarSymbol)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 68, height: 68)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1)
        }
    }

    private func save() {
        try? context.save()
    }
}

// MARK: - 次级页

/// 单行文字的次级编辑页。进去就能打字，离开时写回。
struct ProfileFieldPage: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    @Environment(\.modelContext) private var context
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView {
            GroupedSection(title) {
                TextField(
                    placeholder,
                    text: $text,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(.system(size: PhoneMetrics.FontSize.body))
                .foregroundStyle(AppSurface.light.label)
                .tint(Theme.retroGreen)
                .lineLimit(1...4)
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.detailed)
                .focused($isFocused)
            }
            .padding(.top, PhoneMetrics.Space.s)
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isFocused = true }
        .onDisappear { try? context.save() }
    }
}

/// 状态：一句话 + 一个表情。表情在这里挑，不再塞在主页面上。
struct ProfileStatusPage: View {
    @Bindable var profile: UserProfile

    @Environment(\.modelContext) private var context

    /// 状态表情的全集。这里不管角色那边的开关——状态是「我」设的，
    /// 角色看不到哪张由「能用哪些表情」管，自己这边全给挑。
    private var stickerChoices: [StickerItem] {
        StickerLibrary.shared.items.filter { !$0.name.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PhoneMetrics.Space.m) {
                GroupedSection("在干嘛") {
                    TextField(
                        "在干嘛，一句话",
                        text: $profile.statusText,
                        prompt: Text("在干嘛，一句话").foregroundStyle(AppSurface.light.secondaryLabel),
                        axis: .vertical
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(AppSurface.light.label)
                    .tint(Theme.retroGreen)
                    .lineLimit(1...3)
                    .padding(.horizontal, PhoneMetrics.Space.m)
                    .frame(minHeight: PhoneMetrics.Row.detailed)
                }

                GroupedSection("挂个表情", footer: "再点一次已选中的那张就是取消。") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(stickerChoices) { item in
                                Button {
                                    profile.statusStickerName =
                                        profile.statusStickerName == item.name ? "" : item.name
                                    save()
                                } label: {
                                    StickerView(item: item, size: 44)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 44 * 0.16, style: .continuous)
                                                .strokeBorder(
                                                    profile.statusStickerName == item.name ? Theme.retroGreen : .clear,
                                                    lineWidth: 2
                                                )
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .padding(.vertical, PhoneMetrics.Space.s)
                    }
                }
            }
            .padding(.top, PhoneMetrics.Space.s)
            .padding(.bottom, PhoneMetrics.Space.xl)
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("状态")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear(perform: save)
    }

    private func save() {
        try? context.save()
    }
}

/// 没照片时显示的符号头像。有照片时这页白选，页脚写了提醒。
struct ProfileSymbolPage: View {
    @Bindable var profile: UserProfile

    @Environment(\.modelContext) private var context

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 8
    )

    var body: some View {
        ScrollView {
            GroupedSection(
                "符号",
                footer: profile.avatarPhoto == nil
                    ? "选一个，头像就是它加底色。"
                    : "现在用的是照片，符号看不见。换回符号要去「换头像」里选「不用照片」。"
            ) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(FeedDefaultAvatar.symbols, id: \.self) { symbol in
                        Button {
                            profile.avatarSymbol =
                                profile.avatarSymbol == symbol ? "" : symbol
                            save()
                        } label: {
                            ZStack {
                                Circle().fill(AppSurface.light.background)
                                Image(systemName: symbol)
                                    .font(.system(size: 15))
                                    .foregroundStyle(AppSurface.light.label)
                            }
                            .frame(width: 32, height: 32)
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        profile.avatarSymbol == symbol ? Theme.retroGreen : .clear,
                                        lineWidth: 2
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(PhoneMetrics.Space.s)
            }
            .padding(.top, PhoneMetrics.Space.s)
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("符号头像")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear(perform: save)
    }

    private func save() {
        try? context.save()
    }
}

/// 头像底色。只在没照片时看得见。
struct ProfileTintPage: View {
    @Bindable var profile: UserProfile

    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            GroupedSection("底色", footer: "照片盖住底色；不设照片时它就是头像的底。") {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8),
                    spacing: 12
                ) {
                    ForEach(AvatarTint.allCases) { tint in
                        Button {
                            profile.avatarTintRaw = tint.rawValue
                            save()
                        } label: {
                            Circle()
                                .fill(tint.gradient)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Circle()
                                        .strokeBorder(
                                            profile.avatarTintRaw == tint.rawValue ? Theme.retroGreen : .clear,
                                            lineWidth: 2
                                        )
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(PhoneMetrics.Space.s)
            }
            .padding(.top, PhoneMetrics.Space.s)
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("底色")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear(perform: save)
    }

    private func save() {
        try? context.save()
    }
}
