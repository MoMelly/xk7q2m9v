import SwiftUI

/// 行为与隐私。
struct BehaviorPage: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        AppPage(title: "行为与隐私") {
            ScrollView {
                VStack(spacing: PhoneMetrics.Space.xl) {
                    GroupedSection(
                        "行为",
                        footer: "只在你切出去之后提醒，不是角色主动找你。用的是本地通知，不需要推送证书，也不花钱。"
                    ) {
                        Toggle(isOn: $settings.notifyReplies) {
                            Text("回复到了提醒我")
                                .font(.system(size: PhoneMetrics.FontSize.body))
                                .foregroundStyle(Theme.label)
                        }
                        .tint(Theme.tint)
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .frame(minHeight: PhoneMetrics.Row.single)
                    }

                    GroupedSection(
                        "隐私",
                        footer: "开了之后，角色能看到电量、机型、时区，以及你在这台小手机里各个页面的停留时长。真实健康数据和系统屏幕时间拿不到，免费签名没有这两项权限。默认关闭。"
                    ) {
                        Toggle(isOn: $settings.allowPhoneLookups) {
                            Text("允许角色查手机")
                                .font(.system(size: PhoneMetrics.FontSize.body))
                                .foregroundStyle(Theme.label)
                        }
                        .tint(Theme.tint)
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .frame(minHeight: PhoneMetrics.Row.single)
                    }

                    // 上面那台是「他看我」，这一台是「我看他」。
                    // 私密那一档默认锁着，打开之后才会去生成、也才会展开。
                    GroupedSection(
                        "看他的手机",
                        footer: "桌面上的「TA 的手机」就是这一台。私密那一档锁着的时候，生成时不会写出这一类内容；打开之后重新生成一次，才会出现在里面。"
                    ) {
                        Toggle(isOn: $settings.allowPrivatePeek) {
                            Text("允许看私密那一档")
                                .font(.system(size: PhoneMetrics.FontSize.body))
                                .foregroundStyle(Theme.label)
                        }
                        .tint(Theme.tint)
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .frame(minHeight: PhoneMetrics.Row.single)
                    }

                    // 这两条是「别被人看见」，跟上面「别让他看见」不是一件事。
                    GroupedSection(
                        "语音",
                        footer: "念和听都走系统自带的音色与识别器，不打包任何模型，也不花钱。同一个角色每次都是同一个嗓门——音色按名字挑，重启也不会换人。标记（[表情:…]）和括号里的旁白不念。"
                    ) {
                        Toggle(isOn: Binding(
                            get: { settings.speakReplies },
                            set: { value in
                                settings.speakReplies = value
                                settings.persist()
                            }
                        )) {
                            Text("收到回复就念出来")
                                .font(.system(size: PhoneMetrics.FontSize.body))
                                .foregroundStyle(Theme.label)
                        }
                        .tint(Theme.tint)
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .frame(minHeight: PhoneMetrics.Row.single)

                        RowDivider()

                        // 「读出来的语音是什么」这个问题，光给一个开关答不上来。
                        // 把主角色实际用的那档系统音色写出来，再给一颗试听。
                        GroupedRow(
                            symbol: "waveform",
                            symbolTint: Theme.IconTint.pink,
                            title: "当前音色",
                            subtitle: "\(voiceSampleName)用的这一档",
                            value: SpeechService.voiceName(for: voiceSampleName)
                        )

                        RowDivider()

                        Button {
                            SpeechService.shared.defaultRate = Float(settings.voiceRate)
                            SpeechService.shared.speak(voiceSampleLine, as: voiceSampleName)
                        } label: {
                            HStack(spacing: PhoneMetrics.Space.s) {
                                Image(systemName: "play.circle")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(Theme.tint)

                                Text("试听一句")
                                    .font(.system(size: PhoneMetrics.FontSize.body))
                                    .foregroundStyle(Theme.label)

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, PhoneMetrics.Space.m)
                            .frame(minHeight: PhoneMetrics.Row.single)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        RowDivider()

                        ForEach(Array(VoiceRate.allCases.enumerated()), id: \.offset) { index, rate in
                            Button {
                                settings.voiceRate = rate.rawValue
                                settings.persist()
                                SpeechService.shared.defaultRate = Float(rate.rawValue)
                            } label: {
                                HStack(spacing: PhoneMetrics.Space.s) {
                                    Text(rate.title)
                                        .font(.system(size: PhoneMetrics.FontSize.body))
                                        .foregroundStyle(Theme.label)

                                    Spacer(minLength: 0)

                                    if abs(settings.voiceRate - rate.rawValue) < 0.005 {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Theme.tint)
                                    }
                                }
                                .padding(.horizontal, PhoneMetrics.Space.m)
                                .frame(minHeight: PhoneMetrics.Row.detailed)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if index < VoiceRate.allCases.count - 1 {
                                RowDivider()
                            }
                        }
                    }

                    GroupedSection(
                        "屏幕与锁屏",
                        footer: "隐藏模式会换掉壁纸，同时收起桌面组件和锁屏上那两块——只换皮的话，一眼还是能看出这台手机里有个人。控制中心里也有一个开关，公共场合从右上角拉下来就能切。"
                    ) {
                        NavigationLink {
                            PasscodeSetupPage(settings: settings)
                        } label: {
                            GroupedRow(
                                symbol: "lock.fill",
                                symbolTint: Theme.IconTint.gray,
                                title: "锁屏密码",
                                value: settings.passcode.isEmpty ? "未设" : "四位数字",
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        RowDivider()

                        Toggle(isOn: Binding(
                            get: { settings.discreetMode },
                            set: { settings.setDiscreetMode($0) }
                        )) {
                            Text("隐藏模式")
                                .font(.system(size: PhoneMetrics.FontSize.body))
                                .foregroundStyle(Theme.label)
                        }
                        .tint(Theme.tint)
                        .padding(.horizontal, PhoneMetrics.Space.m)
                        .frame(minHeight: PhoneMetrics.Row.single)
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
        .onChange(of: settings.notifyReplies) { _, newValue in
            settings.persist()
            if newValue {
                Task { await ReplyNotifier.requestAuthorizationIfNeeded() }
            }
        }
        .onChange(of: settings.allowPhoneLookups) { _, _ in settings.persist() }
        .onChange(of: settings.allowPrivatePeek) { _, _ in settings.persist() }
    }

    // MARK: - 试听

    /// 试听用主角色的嗓子。没有角色时退回一句中性名字，
    /// `SpeechService` 会按名字哈希挑，照样有声音。
    private var voiceSampleName: String {
        let name = WorldStore.shared.primaryName
        return name.isEmpty ? "小绿" : name
    }

    /// 挑一句没有标记、没有旁白的话。带标记的样本会被 `spokenForm` 洗掉，
    /// 试听就听不出区别了。
    private var voiceSampleLine: String {
        "今天有点冷，你出门记得多穿一件。"
    }
}

/// 朗读速度三档。
///
/// 直接存 `AVSpeechUtterance` 的 rate 档位，省掉一层「档位 → 系数」的换算。
private enum VoiceRate: Double, CaseIterable {
    case slow = 0.42
    case normal = 0.48
    case fast = 0.54

    var title: String {
        switch self {
        case .slow: return "慢一点"
        case .normal: return "正常"
        case .fast: return "快一点"
        }
    }
}
