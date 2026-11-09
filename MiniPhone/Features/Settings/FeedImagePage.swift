import SwiftUI

/// 西瓜皮配图。
///
/// 这一页只有一个开关是真的「花钱的开关」，所以做得比别的页直白：
/// 默认关、写清楚按张计费、能看见已经画了几张、能一键清空。
struct FeedImagePage: View {
    @Bindable var settings: SettingsStore

    @State private var storageBytes: Int = 0
    @State private var imageCount: Int = 0
    @State private var busy = false

    var body: some View {
        AppPage(title: "西瓜皮配图") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    GroupedSection(
                        "配图",
                        footer: "画像张数按条算：一条笔记只画一张，同一个内容不会重复调用。开着的时候每次进西瓜皮最多补两张，其余的滚到哪儿补到哪儿。"
                    ) {
                        Toggle(isOn: Binding(
                            get: { settings.feedImages },
                            set: { value in
                                settings.feedImages = value
                                settings.persist()
                            }
                        )) {
                            Text("给笔记配 AI 生成的图")
                                .font(.system(size: PhoneMetrics.FontSize.body))
                                .foregroundStyle(Theme.label)
                        }
                        .tint(Theme.tint)
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .frame(minHeight: PhoneMetrics.Row.single)
                    }

                    GroupedSection(
                        "模型",
                        footer: "填的是接口里那个 model 名。硅基流动：Kwai-Kolors/Kolors、black-forest-labs/FLUX.1-schnell；OpenAI 兼容端点填 dall-e-3 这类名字。填错了会在这里看到报错，不会静默跳过。"
                    ) {
                        HStack(spacing: PhoneMetrics.Space.s) {
                            TextField("模型名", text: $settings.imageModel)
                                .font(.system(size: PhoneMetrics.FontSize.sub))
                                .foregroundStyle(Theme.label)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .frame(minHeight: PhoneMetrics.Row.single)
                    }

                    GroupedSection(
                        "花费",
                        footer: "这里不做金额估算：各家单价不一样，换模型就换一套价，写死一个数字反而更容易误会。要控成本就关掉开关，或者只在想看的帖子上点「配一张图」。"
                    ) {
                        GroupedRow(
                            symbol: "photo.on.rectangle.angled",
                            symbolTint: Theme.IconTint.purple,
                            title: "已经配过的笔记",
                            value: "\(imageCount) 张"
                        )

                        RowDivider()

                        GroupedRow(
                            symbol: "internaldrive.fill",
                            symbolTint: Theme.IconTint.gray,
                            title: "占用的空间",
                            value: byteText
                        )

                        RowDivider()

                        Button {
                            clearAll()
                        } label: {
                            GroupedRow(
                                symbol: "trash.fill",
                                symbolTint: Theme.IconTint.pink,
                                title: "清空已生成的图",
                                value: busy ? "清理中…" : nil,
                                showsChevron: false
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(busy)
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
        .onAppear(perform: refreshStats)
        .onChange(of: settings.feedImages) { _, _ in
            // 打开之后马上补一张，用户要的「看到效果」不用等下次进西瓜皮。
            guard settings.feedImages else { return }
            Task { @MainActor in
                await FeedImageService.shared.fillMissing(settings: settings, limit: 1)
                refreshStats()
            }
        }
    }

    private var byteText: String {
        ByteCountFormatter.string(fromByteCount: Int64(storageBytes), countStyle: .file)
    }

    private func refreshStats() {
        storageBytes = FeedImageStorage.totalBytes()
        imageCount = WorldStore.shared.feedImageCount
    }

    /// 只清图，不动笔记：帖子还在，只是回到文字封面。
    private func clearAll() {
        busy = true
        FeedImageStorage.clear()
        for note in WorldStore.shared.state.feed where note.imageFile != nil {
            WorldStore.shared.clearFeedImage(noteID: note.id)
        }
        refreshStats()
        busy = false
    }
}
