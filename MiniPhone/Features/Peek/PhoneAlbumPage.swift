import SwiftUI

/// 相册。
///
/// 图不是真照片：`MockPhoto` 按 seed 现画静物，包里不涨体积，也不会有别人的照片。
/// 每张下面带一句他自己写的说明 —— 说明比图更能看出他在想什么。
struct PhoneAlbumPage: View {
    let phone: CharacterPhone

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        AppPage(title: "相册", surface: .light) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(phone.album) { photo in
                        NavigationLink {
                            PhonePhotoPage(photo: photo)
                        } label: {
                            cell(photo)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, PhoneMetrics.Space.xs)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    private func cell(_ photo: PhonePhoto) -> some View {
        ZStack(alignment: .bottomLeading) {
            MockPhoto(seed: photo.seed)
                .aspectRatio(1, contentMode: .fill)

            if !photo.caption.isEmpty {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.42)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                Text(photo.caption)
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 5)
            }
        }
        .frame(height: 118)
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
    }
}

/// 单张大图。相册里点一张就是这个样子：图铺满，底下写时间和说明。
struct PhonePhotoPage: View {
    let photo: PhonePhoto

    var body: some View {
        AppPage(title: "照片", surface: .light) {
            VStack(spacing: PhoneMetrics.Space.m) {
                MockPhoto(seed: photo.seed)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous))
                    .padding(.horizontal, PhoneMetrics.Space.m)

                VStack(spacing: 6) {
                    if !photo.caption.isEmpty {
                        Text(photo.caption)
                            .font(.system(size: PhoneMetrics.FontSize.body, weight: .medium))
                            .foregroundStyle(AppSurface.light.label)
                    }
                    Text(photo.takenAt)
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                }

                Spacer(minLength: 0)
            }
            .padding(.top, PhoneMetrics.Space.m)
        }
    }
}
