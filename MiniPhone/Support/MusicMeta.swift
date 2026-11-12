import Foundation

/// 自己改过的歌名和歌手。
///
/// 歌名本来是从文件名拆的（`歌手 - 歌名.mp3`），要改就得改文件名。
/// 但改名会让 `Track.id`（带文件名）跟着变：歌词、封面配色、播放队列
/// 全是按 id 记的，一改全对不上。所以改的只是显示的那一层，
/// 按 id 记在本地，文件一动不动。
enum MusicMeta {
    private static let key = "music.meta.v1"

    struct Info: Codable {
        var title: String
        var artist: String
    }

    static func all() -> [String: Info] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Info].self, from: data)
        else { return [:] }
        return decoded
    }

    static func info(for id: String) -> Info? {
        all()[id]
    }

    /// 把改过的名字套到曲目上。没改过的原样返回。
    static func apply(to tracks: [Track]) -> [Track] {
        let table = all()
        guard !table.isEmpty else { return tracks }

        return tracks.map { track in
            guard let info = table[track.id] else { return track }
            var copy = track
            copy.title = info.title
            copy.artist = info.artist
            return copy
        }
    }

    static func rename(_ id: String, title: String, artist: String) {
        var table = all()
        table[id] = Info(title: title, artist: artist)
        write(table)
    }

    /// 改回文件名里的原名。
    static func reset(_ id: String) {
        var table = all()
        table.removeValue(forKey: id)
        write(table)
    }

    private static func write(_ table: [String: Info]) {
        guard let data = try? JSONEncoder().encode(table) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
