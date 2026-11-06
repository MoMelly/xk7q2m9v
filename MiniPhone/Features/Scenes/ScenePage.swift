import SwiftUI

/// 只读场景页的种类。
///
/// 每个 case 对应一个按系统 App 结构做的页面，不再是「一个容器 + 一排白卡」。
/// 「相册」不在列表里：桌面上的「照片」图标指向动态墙，`SceneKind` 里留一个
/// 打不开的相册页只会让人以为有两条入口。
enum SceneKind: String, Hashable, CaseIterable, Identifiable {
    case calendar
    case notes
    case calls
    case health
    case music
    case feed
    case letters

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: return "日历"
        case .notes: return "备忘录"
        case .calls: return "通话记录"
        case .health: return "健康"
        case .music: return "音乐"
        case .feed: return "西瓜皮"
        case .letters: return "信件"
        }
    }

    var symbol: String {
        switch self {
        case .calendar: return "calendar"
        case .notes: return "note.text"
        case .calls: return "phone.fill"
        case .health: return "heart.fill"
        case .music: return "music.note"
        case .feed: return "book.closed.fill"
        case .letters: return "envelope.fill"
        }
    }
}

/// 场景页入口，只做分发。
struct ScenePage: View {
    let kind: SceneKind
    @Bindable var settings: SettingsStore
    let world: WorldStore
    var onExit: () -> Void

    var body: some View {
        Group {
            switch kind {
            case .calendar:
                CalendarScene(world: world, onClose: onExit)
            case .notes:
                NotesScene(onClose: onExit)
            case .calls:
                CallScene(world: world, onClose: onExit)
            case .health:
                HealthScene(settings: settings, world: world, onClose: onExit)
            case .music:
                MusicScene(world: world, onClose: onExit)
            case .feed:
                FeedScene(world: world, settings: settings, onClose: onExit)
            case .letters:
                LetterScene(world: world, settings: settings, onClose: onExit)
            }
        }
        .onAppear { world.seedSceneContentIfNeeded() }
    }
}
