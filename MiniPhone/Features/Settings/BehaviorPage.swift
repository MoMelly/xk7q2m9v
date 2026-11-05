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
    }
}
