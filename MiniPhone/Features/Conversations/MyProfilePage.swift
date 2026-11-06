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

            Text("点一下换头像")
                .font(.system(size: PhoneMetrics.FontSize.caption))
                .foregroundStyle(AppSurface.light.secondaryLabel)

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
