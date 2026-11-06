import PhotosUI
import SwiftUI
import UIKit

/// 换头像。
///
/// 角色和「我」共用这一个面板：两边的字段同名同类型，
/// 分成两份只会让「为什么他这边能传我不能传」变成一个没道理的区别。
///
/// 只回写两个字符串（内置资源名、上传文件名），不碰 SwiftData，
/// 由调用方决定怎么存——角色和我存在不同表里。
struct AvatarPickerSheet: View {
    var title: String = "换头像"
    /// 不用照片时显示什么。角色是「名字首字」，我是「当前符号」。
    var fallbackNote: String = "不用照片时，头像显示名字第一个字。"

    @Binding var imageKey: String
    @Binding var fileName: String

    @Environment(\.dismiss) private var dismiss

    @State private var picked: PhotosPickerItem?
    @State private var isWorking = false
    @State private var errorText = ""
    /// 默认给大半屏：四组头像加相册入口，半屏得滚很久才看得完。
    @State private var detent: PresentationDetent = .large

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: PhoneMetrics.Space.xs),
        count: 4
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.l) {
                    preview
                    uploadSection
                    ForEach(AvatarGroup.allCases) { group in
                        builtInSection(group)
                    }
                    if !errorText.isEmpty {
                        Text(errorText)
                            .font(.system(size: PhoneMetrics.FontSize.footnote))
                            .foregroundStyle(Theme.warning)
                            .padding(.horizontal, PhoneMetrics.Space.m)
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
            .background(Theme.groupedBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.brand)
                }
            }
        }
        .environment(\.colorScheme, ThemeStore.shared.isNight ? .dark : .light)
        .presentationDetents([.medium, .large], selection: $detent)
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
    }

    // MARK: - 当前头像

    private var currentPhoto: UIImage? {
        if !fileName.isEmpty, let uploaded = AvatarPhoto.load(fileName: fileName) {
            return uploaded
        }
        if !imageKey.isEmpty {
            return AvatarPhoto.builtIn(key: imageKey)
        }
        return nil
    }

    private var preview: some View {
        GroupedSection {
            HStack(spacing: PhoneMetrics.Space.m) {
                Group {
                    if let photo = currentPhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Circle().fill(Theme.separator.opacity(0.35))
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Theme.secondaryLabel)
                            }
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1)
                }

                Text(currentPhoto == nil ? fallbackNote : "现在用的是这张")
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(Theme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .frame(minHeight: PhoneMetrics.Row.detailed)
        }
    }

    // MARK: - 内置

    private func builtInSection(_ group: AvatarGroup) -> some View {
        let keys = AvatarPhoto.keys(in: group)

        return Group {
            if !keys.isEmpty {
                GroupedSection(group.title) {
                    LazyVGrid(columns: columns, spacing: PhoneMetrics.Space.xs) {
                        ForEach(keys, id: \.self) { key in
                            Button {
                                imageKey = key
                                fileName = ""
                                errorText = ""
                            } label: {
                                builtInCell(key)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(PhoneMetrics.Space.s)
                }
            }
        }
    }

    private func builtInCell(_ key: String) -> some View {
        Group {
            if let photo = AvatarPhoto.builtIn(key: key) {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(Theme.separator.opacity(0.35))
            }
        }
        .frame(height: 62)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(
                    imageKey == key && fileName.isEmpty ? Theme.brand : .clear,
                    lineWidth: 2.5
                )
        }
    }

    // MARK: - 上传

    private var uploadSection: some View {
        GroupedSection(footer: "上传的照片压到 512 像素存在本机，不会传到任何服务器。") {
            PhotosPicker(
                selection: $picked,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack(spacing: PhoneMetrics.Space.s) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.brand)
                        .frame(width: 24)

                    Text("从相册选一张")
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(Theme.label)

                    Spacer(minLength: 0)

                    if isWorking {
                        ProgressView().tint(Theme.secondaryLabel)
                    }
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.single)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Theme.separator)
                .frame(height: 0.5)
                .padding(.leading, PhoneMetrics.Space.m)

            Button {
                imageKey = ""
                fileName = ""
                errorText = ""
            } label: {
                HStack(spacing: PhoneMetrics.Space.s) {
                    Image(systemName: "textformat")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.secondaryLabel)
                        .frame(width: 24)

                    Text("不用照片")
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(Theme.label)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, PhoneMetrics.Space.m)
                .frame(minHeight: PhoneMetrics.Row.single)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 导入

    private func importPhoto(_ item: PhotosPickerItem) async {
        isWorking = true
        errorText = ""
        defer {
            isWorking = false
            picked = nil
        }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorText = "这张图读不出来，换一张试试。"
            return
        }

        do {
            let saved = try AvatarPhoto.save(image: image)
            fileName = saved
            imageKey = ""
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "存不下这张图。"
        }
    }
}
