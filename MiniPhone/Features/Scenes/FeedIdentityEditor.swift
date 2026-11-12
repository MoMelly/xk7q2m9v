import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// 改「我的主页」：封面、头像、名字、简介。
///
/// 之前这一页四个字段全是字面量，一个都改不了——她的原话是「简介改不了，
/// 名字也改不了」。现在四个都接在 `UserProfile` 上（封面除外，那项
/// `UserProfile` 里没有，存在文件里）。
struct FeedIdentityEditor: View {
    @Bindable var profile: UserProfile
    /// 关了之后让主页重新读一次封面。
    var onChange: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var showAvatarPicker = false
    @State private var pickedCover: PhotosPickerItem?
    @State private var cover: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.m) {
                    coverSection
                    avatarSection
                    nameSection
                    bioSection
                }
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
            .background(AppSurface.light.background.ignoresSafeArea())
            .navigationTitle("编辑我的主页")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { save() }
                }
            }
            .sheet(isPresented: $showAvatarPicker) {
                AvatarPickerSheet(
                    fallbackNote: "不用照片时，显示首字或符号头像。",
                    imageKey: $profile.avatarImageKey,
                    fileName: $profile.avatarFileName
                )
            }
            .onChange(of: pickedCover) { _, item in loadCover(item) }
        }
        .onAppear { cover = FeedProfileStore.loadCover() }
        // 这一页是浅色的，外壳是强制深色。不声明配色的话，三个输入框里的字、
        // 占位符和光标全按深色算，白字压在浅底上看不见——日历编辑页之前就是这个毛病。
        .environment(\.colorScheme, AppSurface.light.colorScheme)
    }

    // MARK: - 封面

    private var coverSection: some View {
        GroupedSection("封面") {
            VStack(spacing: 0) {
                ZStack {
                    if let cover {
                        Image(uiImage: cover)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ProfileBackdrop(variant: 0, height: 132)
                    }
                }
                .frame(height: 132)
                .frame(maxWidth: .infinity)
                .clipped()

                RowDivider()

                PhotosPicker(selection: $pickedCover, matching: .images) {
                    row("从相册选一张", systemImage: "photo.on.rectangle")
                }

                RowDivider()

                Button {
                    FeedProfileStore.clearCover()
                    cover = nil
                } label: {
                    row("用内置渐变", systemImage: "circle.lefthalf.filled")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, PhoneMetrics.Space.s)
    }

    // MARK: - 头像

    private var avatarSection: some View {
        GroupedSection("头像") {
            Button {
                showAvatarPicker = true
            } label: {
                HStack(spacing: PhoneMetrics.Space.s) {
                    avatarPreview
                        .frame(width: 44, height: 44)

                    Text("换一个头像")
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(AppSurface.light.label)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.detailed)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var avatarPreview: some View {
        ZStack {
            Circle().fill(Theme.Watermelon.pith)

            if !profile.avatarFileName.isEmpty,
               let image = AvatarPhoto.load(fileName: profile.avatarFileName) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if !profile.avatarImageKey.isEmpty,
                      let image = UIImage(named: profile.avatarImageKey) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                WatermelonMark(size: 26)
            }
        }
        .clipShape(Circle())
    }

    // MARK: - 名字与简介

    private var nameSection: some View {
        GroupedSection("名字") {
            TextField("我", text: $profile.name)
                .textFieldStyle(.plain)
                .font(.system(size: PhoneMetrics.FontSize.body))
                .foregroundStyle(AppSurface.light.label)
                .tint(Theme.retroGreen)
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.detailed)
        }
    }

    private var bioSection: some View {
        GroupedSection("简介") {
            TextField(
                "写一句介绍，角色在提示词里能看到这一句。",
                text: $profile.bio,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.system(size: PhoneMetrics.FontSize.body))
            .foregroundStyle(AppSurface.light.label)
            .tint(Theme.retroGreen)
            .lineLimit(3...8)
            .padding(.horizontal, PhoneMetrics.Space.m)
            .padding(.vertical, PhoneMetrics.Space.s)
        }
    }

    // MARK: - 小件

    private func row(_ title: String, systemImage: String) -> some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            Image(systemName: systemImage)
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(Theme.tint)
                .frame(width: 22)

            Text(title)
                .font(.system(size: PhoneMetrics.FontSize.body))
                .foregroundStyle(AppSurface.light.label)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .frame(minHeight: PhoneMetrics.Row.detailed)
        .contentShape(Rectangle())
    }

    private func loadCover(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else { return }
            FeedProfileStore.saveCover(image)
            await MainActor.run {
                cover = FeedProfileStore.loadCover()
            }
        }
    }

    private func save() {
        if profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profile.name = "我"
        }
        try? context.save()
        onChange()
        dismiss()
    }
}
