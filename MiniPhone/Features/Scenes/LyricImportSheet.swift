import SwiftUI
import UniformTypeIdentifiers

/// 导入歌词：贴文本，或者从「文件」里挑一个 `.lrc` / `.txt`。
///
/// 两种格式都收：
/// - 带 `[00:12.34]` 时间轴的 LRC，播到哪儿高亮到哪儿；
/// - 不带时间轴的纯文本，按整首歌的进度平均摊到每一行。
struct LyricImportSheet: View {
    let track: Track
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var showImporter = false
    @State private var notice: String?
    @State private var loadedOnce = false

    private var hasCustomLyrics: Bool {
        LyricStore.hasLyrics(for: track)
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PhoneMetrics.Space.m) {
                    GroupedSection(
                        "这首歌",
                        footer: "带时间轴的会逐行高亮；不带时间轴的按播放进度往下走。"
                    ) {
                        HStack(spacing: PhoneMetrics.Space.s) {
                            Image(systemName: "music.note")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.IconTint.rose)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.system(size: PhoneMetrics.FontSize.body))
                                    .foregroundStyle(AppSurface.light.label)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.system(size: PhoneMetrics.FontSize.caption))
                                    .foregroundStyle(AppSurface.light.secondaryLabel)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .frame(minHeight: PhoneMetrics.Row.detailed)
                    }

                    Button {
                        showImporter = true
                    } label: {
                        HStack(spacing: PhoneMetrics.Space.s) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 14, weight: .medium))
                            Text("从文件里选一个 .lrc / .txt")
                                .font(.system(size: PhoneMetrics.FontSize.body))
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppSurface.light.secondaryLabel.opacity(0.5))
                        }
                        .foregroundStyle(AppSurface.light.label)
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .frame(minHeight: PhoneMetrics.Row.detailed)
                        .background(
                            RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                                .fill(AppSurface.light.rowSurface)
                        )
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("或者直接贴进来")
                            .font(.system(size: PhoneMetrics.FontSize.caption))
                            .foregroundStyle(AppSurface.light.secondaryLabel)

                        TextEditor(text: $text)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(AppSurface.light.label)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 260)
                            .padding(PhoneMetrics.Space.s)
                            .background(
                                RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                                    .fill(AppSurface.light.rowSurface)
                            )
                    }

                    if hasCustomLyrics {
                        Button(role: .destructive) {
                            LyricStore.delete(for: track)
                            text = ""
                            notice = "这份歌词已经移除了。"
                            onDone()
                        } label: {
                            Text("移除这份歌词")
                                .font(.system(size: PhoneMetrics.FontSize.body))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.IconTint.rose)
                        .background(
                            RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                                .fill(AppSurface.light.rowSurface)
                        )
                    }
                }
                .padding(PhoneMetrics.Space.m)
            }
            .background(AppSurface.light.background)
            .navigationTitle("导入歌词")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
        }
        .environment(\.colorScheme, AppSurface.light.colorScheme)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            handleFile(result)
        }
        .onAppear(perform: loadExisting)
        .alert("提示", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button("好") { notice = nil }
        } message: {
            Text(notice ?? "")
        }
    }

    private func loadExisting() {
        guard !loadedOnce else { return }
        loadedOnce = true
        text = LyricStore.text(for: track) ?? ""
    }

    private func save() {
        do {
            try LyricStore.save(text, for: track)
            onDone()
            dismiss()
        } catch {
            notice = error.localizedDescription
        }
    }

    private func handleFile(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            notice = "没选到文件：\(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let loaded = try LyricStore.read(from: url)
                text = loaded
                notice = "读取了 \(loaded.split(separator: "\n").count) 行，确认后点保存。"
            } catch {
                notice = error.localizedDescription
            }
        }
    }
}
