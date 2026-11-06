import SwiftUI
import UIKit

/// 角色头像的底色。
///
/// 头像不用图片，用「渐变圆 + 首字」——免素材、不发虚、也不占包体。
/// 用户只需要从几个色里挑一个，不需要调色盘。
enum AvatarTint: String, CaseIterable, Identifiable {
    case mint
    case amber
    case rose
    case sky
    case violet
    case slate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mint: return "薄荷"
        case .amber: return "焦糖"
        case .rose: return "玫瑰"
        case .sky: return "天青"
        case .violet: return "紫藤"
        case .slate: return "石墨"
        }
    }

    var colors: [Color] {
        switch self {
        case .mint:
            return [Color(red: 0.53, green: 0.82, blue: 0.70), Color(red: 0.20, green: 0.48, blue: 0.38)]
        case .amber:
            return [Color(red: 0.94, green: 0.72, blue: 0.42), Color(red: 0.68, green: 0.40, blue: 0.18)]
        case .rose:
            return [Color(red: 0.93, green: 0.60, blue: 0.64), Color(red: 0.66, green: 0.26, blue: 0.36)]
        case .sky:
            return [Color(red: 0.55, green: 0.76, blue: 0.95), Color(red: 0.20, green: 0.42, blue: 0.72)]
        case .violet:
            return [Color(red: 0.72, green: 0.64, blue: 0.94), Color(red: 0.40, green: 0.32, blue: 0.70)]
        case .slate:
            return [Color(red: 0.58, green: 0.60, blue: 0.64), Color(red: 0.26, green: 0.28, blue: 0.32)]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Companion {
    var avatarTint: AvatarTint {
        AvatarTint(rawValue: avatarTintRaw) ?? .mint
    }

    /// 头像上显示的字：名字第一个字符。
    var avatarInitial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first)
    }
}

/// 圆形头像的绘制。
///
/// 单独拆出来是因为它有两个来源：会话列表里拿的是角色对象，
/// 动态墙里拿的是作者名字（那条动态的角色可能已经被删了）。
/// 两边要长得一模一样，所以颜色和首字由调用方给，这里只管画。
///
/// 有照片就画照片，没有才回落到「渐变圆 + 首字」。
/// 回落不是兜底而是默认：很多人就是不想放照片。
struct AvatarCircle: View {
    let initial: String
    let tint: AvatarTint
    var size: CGFloat = 46
    var photo: UIImage? = nil

    var body: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
            } else {
                Circle().fill(tint.gradient)

                Text(initial)
                    .font(.system(size: size * 0.42, weight: .semibold, design: .serif))
                    .foregroundStyle(.white.opacity(0.95))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(.white.opacity(photo == nil ? 0.18 : 0.28), lineWidth: 0.5)
        }
    }
}

/// 角色头像。
struct AvatarBubble: View {
    let character: Companion
    var size: CGFloat = 46

    var body: some View {
        AvatarCircle(
            initial: character.avatarInitial,
            tint: character.avatarTint,
            size: size,
            photo: character.avatarPhoto
        )
    }
}

extension Companion {
    /// 内置优先，其次上传的。两边都空就返回 nil，交给渐变圆。
    var avatarPhoto: UIImage? {
        if !avatarImageKey.isEmpty {
            return AvatarPhoto.builtIn(key: avatarImageKey)
        }
        return AvatarPhoto.load(fileName: avatarFileName)
    }
}

extension UserProfile {
    /// 上传的照片优先，其次内置照片，都没有才回落到符号或首字。
    var avatarPhoto: UIImage? {
        if !avatarFileName.isEmpty, let uploaded = AvatarPhoto.load(fileName: avatarFileName) {
            return uploaded
        }
        if !avatarImageKey.isEmpty {
            return AvatarPhoto.builtIn(key: avatarImageKey)
        }
        return nil
    }
}
