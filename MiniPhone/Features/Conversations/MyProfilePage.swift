import SwiftUI
import SwiftData

/// 「信息」第四格：我的资料。
///
/// 名字和签名直接写回 UserProfile，角色在提示词里读的就是同一份，
/// 不再另存一份资料。头像从内置的矢量头像里挑，选中项存符号名。
struct MyProfilePage: View {
    @Bindable var profile: UserProfile

    @Environment(\.modelContext) private var context
    @State private var showAvatarPicker = false
    /// 状态行的表情条展开状态。跟头像选择一样是就地展开，不弹窗。
    @State private var showStatusStickers = false

    /// 状态表情的全集。这里不管角色那边的开关——状态是「我」设的，
    /// 角色看不到哪张由「能用哪些表情」管，自己这边全给挑。
    private var stickerChoices: [StickerItem] {
        StickerLibrary.shared.items.filter { !$0.name.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: PhoneMetrics.Space.m) {
                avatarCard
                infoCard
                hintCard
            }
            .padding(PhoneMetrics.Space.m)
            .padding(.bottom, PhoneMetrics.Space.xl)
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .onDisappear(perform: save)
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPickerSheet(
                fallbackNote: "不用照片时，显示首字或下面挑的符号。",
                imageKey: $profile.avatarImageKey,
                fileName: $profile.avatarFileName
            )
            .onDisappear(perform: save)
        }
    }

    // MARK: - 卡片

    private var avatarCard: some View {
        VStack(spacing: PhoneMetrics.Space.s) {
            Button {
                showAvatarPicker = true
            } label: {
                currentAvatar
            }
            .buttonStyle(.plain)

            Text(profile.name.isEmpty ? "我" : profile.name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppSurface.light.label)

            // 状态在这里回显一眼：真正编辑在下面的信息卡里。
            if !profile.statusText.isEmpty {
                HStack(spacing: 5) {
                    if let item = StickerLibrary.shared.item(named: profile.statusStickerName) {
                        StickerView(item: item, size: 18)
                    }
                    Text(profile.statusText)
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                }
            } else {
                Text("点一下换头像")
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
            }

            symbolRow
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(PhoneMetrics.Space.m)
        .background(AppSurface.light.rowSurface)
        .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.grouped, style: .continuous))
    }

    /// 符号只在没照片的时候看得见，所以有照片就把这一排收起来。
    @ViewBuilder
    private var symbolRow: some View {
        if profile.avatarPhoto == nil {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(FeedDefaultAvatar.symbols, id: \.self) { symbol in
                    Button {
                        profile.avatarSymbol = symbol
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
        } else {
            Text("想改用符号头像，就在换头像里选「不用照片」。")
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .foregroundStyle(AppSurface.light.secondaryLabel)
        }
    }

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 8
    )

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

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                Text("名字")
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(AppSurface.light.label)
                    .frame(width: 48, alignment: .leading)
                TextField("我", text: $profile.name)
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(AppSurface.light.label)
                    .tint(Theme.retroGreen)
            }
            .onChange(of: profile.name) { _, _ in save() }

            divider

            HStack(spacing: 10) {
                Text("签名")
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(AppSurface.light.label)
                    .frame(width: 48, alignment: .leading)
                TextField(
                    "一句话",
                    text: $profile.signature,
                    prompt: Text("一句话").foregroundStyle(AppSurface.light.secondaryLabel)
                )
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(AppSurface.light.label)
                .tint(Theme.retroGreen)
            }
            .onChange(of: profile.signature) { _, _ in save() }

            divider

            statusRow

            divider

            HStack(spacing: 8) {
                Text("底色")
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(AppSurface.light.label)
                    .frame(width: 48, alignment: .leading)
                ForEach(AvatarTint.allCases) { tint in
                    Button {
                        profile.avatarTintRaw = tint.rawValue
                        save()
                    } label: {
                        Circle()
                            .fill(tint.gradient)
                            .frame(width: 24, height: 24)
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
                Spacer(minLength: 0)
            }
        }
        .padding(PhoneMetrics.Space.s)
        .background(AppSurface.light.rowSurface)
        .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.grouped, style: .continuous))
    }

    /// 状态：一句话 + 一个表情。写进去的东西角色在聊天里能提。
    ///
    /// 表情条就地展开而不是弹窗：状态这种小设置犯不着盖一层 sheet，
    /// 展开收起各一次动画，比跳页轻得多。
    private var statusRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("状态")
                    .font(.system(size: PhoneMetrics.FontSize.sub))
                    .foregroundStyle(AppSurface.light.label)
                    .frame(width: 48, alignment: .leading)

                statusStickerButton

                TextField(
                    "在干嘛，一句话",
                    text: $profile.statusText,
                    prompt: Text("在干嘛，一句话").foregroundStyle(AppSurface.light.secondaryLabel)
                )
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(AppSurface.light.label)
                .tint(Theme.retroGreen)
            }
            .onChange(of: profile.statusText) { _, _ in save() }

            if showStatusStickers {
                stickerStrip
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// 状态上那个表情位。没选时是一个虚位符号，选了显示真图。
    /// 再点一次展开或收起表情条；在条里点已选中的那张等于取消。
    private var statusStickerButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                showStatusStickers.toggle()
            }
        } label: {
            if let item = StickerLibrary.shared.item(named: profile.statusStickerName) {
                StickerView(item: item, size: 30)
            } else {
                Circle()
                    .strokeBorder(AppSurface.light.secondaryLabel.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3]))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: "face.dashed")
                            .font(.system(size: 13))
                            .foregroundStyle(AppSurface.light.secondaryLabel)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private var stickerStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(stickerChoices) { item in
                    Button {
                        // 点已选中的那张就是取消：不用再补一个「清除」按钮。
                        profile.statusStickerName =
                            profile.statusStickerName == item.name ? "" : item.name
                        save()
                    } label: {
                        StickerView(item: item, size: 40)
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        profile.statusStickerName == item.name ? Theme.retroGreen : .clear,
                                        lineWidth: 2
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    private var hintCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("关于这份资料")
                .font(.system(size: PhoneMetrics.FontSize.caption, weight: .medium))
                .foregroundStyle(Theme.cream)
            Text("名字和签名会进角色的提示词。想用别的身份跟角色聊天，去桌面「设置 → 我的人设」里另建一个。")
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .foregroundStyle(Theme.cream.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PhoneMetrics.Space.s)
        .glassSurface(cornerRadius: PhoneMetrics.Radius.grouped)
    }

    private var divider: some View {
        Rectangle()
            .fill(AppSurface.light.separator.opacity(0.7))
            .frame(height: 0.5)
    }

    private func save() {
        try? context.save()
    }
}
