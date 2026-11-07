import SwiftUI

/// 西瓜皮「直播」栏：直播列表。
///
/// 房间分两类：角色开播（跟人名 + 小时块稳定哈希联动，不是常驻也不是纯随机）
/// 和路人在播（纯氛围）。房间数与观众数每个整点变一次，同一段时间里刷新列表不跳变。
struct LiveRoom: Identifiable, Hashable {
    /// 路人房间用 name + hour 生成，角色房间用 uid。
    let id: String
    let anchorName: String
    let title: String
    var viewers: Int
    let seed: Int
    /// 角色房间才有；路人房间为 nil。
    let characterUID: UUID?

    var isCharacter: Bool { characterUID != nil }
}

enum LiveCatalog {
    private static let passerbyNames = [
        "晚风电台", "芝士圈圈", "线上冲浪选手", "奶糖罐头", "阿茶不打烊",
        "月亮邮递员", "不吃香菜", "kiwi家", "半糖去冰", "晚安玛卡巴卡",
        "打工魂", "白噪音房间"
    ]

    private static let titles = [
        "深夜聊天室", "一起听歌写作业", "开麦点歌", "画一只你家猫",
        "吃播·今晚吃面", "游戏上分中", "手账拼贴实况", "白噪音陪伴",
        "宿舍开麦闲聊", "考完放松一下"
    ]

    /// 当前整点块。房间构成按它稳定，整点切换。
    private static var hourBlock: Int {
        Calendar.current.component(.hour, from: Date())
    }

    /// 生成当前时刻的房间清单。角色排前面。
    static func rooms(companions: [Companion]) -> [LiveRoom] {
        let hour = hourBlock
        var rooms: [LiveRoom] = []

        // 角色开播：人名 + 整点做哈希，命中才播，最多两个。
        // 不是全部角色同时开播，也不是每次进来换一批。
        var characterRooms: [LiveRoom] = []
        for companion in companions where !companion.isFeedOnly {
            let seed = StableSeed.of(companion.name + "#live\(hour)")
            guard StableSeed.index(seed, count: 3) == 0 else { continue }
            let titleSeed = StableSeed.index(seed, count: titles.count)
            characterRooms.append(
                LiveRoom(
                    id: companion.uid.uuidString,
                    anchorName: companion.name,
                    title: liveTitle(for: companion, fallback: titles[titleSeed]),
                    viewers: 400 + StableSeed.index(seed, count: 4600),
                    seed: seed,
                    characterUID: companion.uid
                )
            )
            if characterRooms.count == 2 { break }
        }
        rooms.append(contentsOf: characterRooms)

        // 路人房间固定六间，名字从池子里按整点偏移取，避免和角色房间重名。
        let characterNames = Set(characterRooms.map(\.anchorName))
        var offset = StableSeed.index(StableSeed.of("passerby\(hour)"), count: passerbyNames.count)
        for index in 0..<6 {
            let name = passerbyNames[(offset + index) % passerbyNames.count]
            guard !characterNames.contains(name) else { continue }
            let seed = StableSeed.of(name + "#\(hour)")
            rooms.append(
                LiveRoom(
                    id: name,
                    anchorName: name,
                    title: titles[StableSeed.index(seed, count: titles.count)],
                    viewers: 80 + StableSeed.index(seed, count: 2200),
                    seed: seed,
                    characterUID: nil
                )
            )
        }

        return rooms
    }

    /// 角色的直播标题跟着人设走：拿人设开头一句话，取短一点当标题；
    /// 人设太空就退回通用标题池。
    private static func liveTitle(for companion: Companion, fallback: String) -> String {
        let firstLine = companion.persona
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard firstLine.count >= 6 else { return fallback }
        return String(firstLine.prefix(14))
    }
}

/// 直播列表页：角色开播一节 + 路人在播一节。
struct LiveListPage: View {
    let companions: [Companion]
    let settings: SettingsStore

    private var rooms: [LiveRoom] { LiveCatalog.rooms(companions: companions) }

    var body: some View {
        let characterRooms = rooms.filter(\.isCharacter)
        let passerbyRooms = rooms.filter { !$0.isCharacter }

        ScrollView {
            VStack(alignment: .leading, spacing: PhoneMetrics.Space.m) {
                if !characterRooms.isEmpty {
                    sectionHeader("关注在播")
                    ForEach(characterRooms) { room in
                        NavigationLink {
                            LiveRoomPage(room: room, companions: companions, settings: settings)
                        } label: {
                            row(room, highlighted: true)
                        }
                        .buttonStyle(.plain)
                    }
                }

                sectionHeader("路人在播")
                ForEach(passerbyRooms) { room in
                    NavigationLink {
                        LiveRoomPage(room: room, companions: companions, settings: settings)
                    } label: {
                        row(room, highlighted: false)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .padding(.top, PhoneMetrics.Space.s)
            .padding(.bottom, PhoneMetrics.Space.xl)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: PhoneMetrics.FontSize.footnote, weight: .semibold))
            .foregroundStyle(AppSurface.light.secondaryLabel)
    }

    private func row(_ room: LiveRoom, highlighted: Bool) -> some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            ZStack(alignment: .bottomLeading) {
                MockPhoto(seed: room.seed)
                    .frame(width: 96, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: PhoneMetrics.Radius.block, style: .continuous))

                Text("LIVE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.brand))
                    .padding(4)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: PhoneMetrics.Space.xs) {
                    FeedAvatar(name: room.anchorName, isCharacter: room.isCharacter, size: 18)
                    Text(room.anchorName)
                        .font(.system(size: PhoneMetrics.FontSize.sub, weight: .medium))
                        .foregroundStyle(AppSurface.light.label)
                        .lineLimit(1)
                }

                Text(room.title)
                    .font(.system(size: PhoneMetrics.FontSize.footnote, weight: highlighted ? .semibold : .regular))
                    .foregroundStyle(highlighted ? Theme.brand : AppSurface.light.secondaryLabel)
                    .lineLimit(1)

                Label("\(room.viewers)", systemImage: "eye")
                    .font(.system(size: PhoneMetrics.FontSize.caption))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
            }

            Spacer(minLength: 0)
        }
        .padding(PhoneMetrics.Space.s)
        .background(
            RoundedRectangle(cornerRadius: PhoneMetrics.Radius.card, style: .continuous)
                .fill(AppSurface.light.rowSurface)
        )
        .contentShape(Rectangle())
    }
}
