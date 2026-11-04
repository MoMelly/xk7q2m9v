import Foundation
import UIKit
import UserNotifications

/// 回复到达提醒。
///
/// 免费签名拿不到 APNs 推送权限，但**本地通知**不需要任何证书，
/// 只要用户授权就能用。所以这里只解决一件事：你在别的 App 里、
/// 它回完了，锁屏上冒一条「它回你了」。不是角色主动找你。
enum ReplyNotifier {
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            AppLog.ui.error("通知授权失败: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// App 在前台时不发——你正看着屏幕，再弹一条没意义。
    @MainActor
    static func notifyReply(characterName: String, text: String) {
        guard UIApplication.shared.applicationState != .active else { return }

        let content = UNMutableNotificationContent()
        content.title = characterName
        content.body = String(text.prefix(120))
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                AppLog.ui.error("通知投递失败: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
