import SwiftUI
import SwiftData

/// 「照片」App。
///
/// 之前这个图标指向角色动态墙，她实测直接问「照片里为什么全是动态」——
/// 语义就是错的。现在改成真的照片页：聊天里发过的模拟图片按时间排成宫格，
/// 点开看大图。没有相册权限，收的只有这台手机「拍过」的图。
struct PhotoLibraryScene: View {
    var onClose: () -> Void

    @Query private var photoMessages: [StoredMessage]

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        _photoMessages = Query(
            filter: #Predicate<StoredMessage> { $0.imageSeed > 0 },
            sort: [SortDescriptor(\StoredMessage.createdAt, order: .reverse)]
        )
    }

    /// 同一张图可能被发过多次，按种子去重，保留最新一条的时间。
    private var photos: [(seed: Int, date: Date)] {
        var seen: Set<Int> = []
        var result: [(Int, Date)] = []
        for message in photoMessages where seen.insert(message.imageSeed).inserted {
            result.append((message.imageSeed, message.createdAt))
        }
        return result
    }

    var body: some View {
        AppScreen(title: "照片", surface: .light, onClose: onClose) {
            if photos.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3),
                        spacing: 2
                    ) {
                        ForEach(photos, id: \.seed) { photo in
                            NavigationLink {
                                PhotoDetailPage(seed: photo.seed, date: photo.date)
                            } label: {
                                MockPhoto(seed: photo.seed)
                                    .aspectRatio(1, contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: PhoneMetrics.Space.s) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppSurface.light.secondaryLabel.opacity(0.7))
            Text("还没有照片")
                .font(.system(size: PhoneMetrics.FontSize.body, weight: .medium))
                .foregroundStyle(AppSurface.light.label)
            Text("在聊天里发过的图片会收在这里")
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(AppSurface.light.secondaryLabel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }
}

/// 单张大图。MockPhoto 是现画的，参数只有种子；带上日期像个相册的样子。
private struct PhotoDetailPage: View {
    let seed: Int
    let date: Date

    var body: some View {
        VStack(spacing: PhoneMetrics.Space.m) {
            MockPhoto(seed: seed)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous))
                .padding(.horizontal, PhoneMetrics.Space.m)

            Text(TimeFormat.lockDate(date))
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(AppSurface.light.secondaryLabel)

            Spacer(minLength: 0)
        }
        .padding(.top, PhoneMetrics.Space.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppSurface.light.background.ignoresSafeArea())
    }
}
