import SwiftUI

/// 改一首歌的名字和歌手。
///
/// 文件名不动——见 `MusicMeta` 的说明，改文件名会把 id 一起改掉，
/// 歌词和封面配色都得跟着重挂。这一页改的只是显示的那一层。
struct TrackRenameSheet: View {
    let track: Track
    var onSave: (String, String) -> Void
    var onReset: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    @State private var title: String
    @State private var artist: String

    init(
        track: Track,
        onSave: @escaping (String, String) -> Void,
        onReset: @escaping () -> Void
    ) {
        self.track = track
        self.onSave = onSave
        self.onReset = onReset
        _title = State(initialValue: track.title)
        _artist = State(initialValue: track.artist)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedArtist: String {
        artist.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 现在显示的名字和文件名里的一致，就不用给「改回原名」这颗按钮。
    private var edited: Bool {
        MusicMeta.info(for: track.id) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.l) {
                    field("歌名", placeholder: "这首歌叫什么", text: $title)
                    field("歌手", placeholder: "未知", text: $artist)

                    if edited {
                        Button {
                            onReset()
                            dismiss()
                        } label: {
                            Text("改回文件名里的原名")
                                .font(.system(size: PhoneMetrics.FontSize.sub))
                                .foregroundStyle(Theme.tint)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background {
                                    RoundedRectangle(
                                        cornerRadius: PhoneMetrics.Radius.card,
                                        style: .continuous
                                    )
                                    .fill(AppSurface.light.rowSurface)
                                }
                        }
                        .buttonStyle(.plain)
                    }

                    Text("改名只影响列表和播放条上显示的字，音频文件本身不动。")
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
                .padding(PhoneMetrics.Space.m)
            }
            .background(AppSurface.light.background)
            .navigationTitle("重命名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(trimmedTitle, trimmedArtist.isEmpty ? "未知" : trimmedArtist)
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .environment(\.colorScheme, AppSurface.light.colorScheme)
        .presentationDetents([.height(340), .medium])
        .onAppear { focused = true }
    }

    private func field(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: PhoneMetrics.FontSize.caption, weight: .medium))
                .foregroundStyle(AppSurface.light.secondaryLabel)
                .padding(.leading, 4)

            ZStack(alignment: .leading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .foregroundStyle(AppSurface.light.secondaryLabel)
                        .padding(.horizontal, PhoneMetrics.Space.s)
                        .allowsHitTesting(false)
                }

                TextField("", text: text)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(AppSurface.light.label)
                    .tint(Theme.tint)
                    .padding(.horizontal, PhoneMetrics.Space.s)
            }
            .frame(height: 44)
            .background {
                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                    .fill(AppSurface.light.rowSurface)
            }
        }
    }
}
