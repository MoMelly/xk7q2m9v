import Foundation

/// 书上的一句批注。
///
/// 存的是原句，不是字符位置：字号、行距、页边距一改就会重新分页，
/// 位置全变，句子不会。判断一条批注落在哪一页，只需要看这页正文里有没有这句。
struct BookNote: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    /// 被标出来的那句原文。
    var sentence: String
    /// 我写的想法。
    var text: String
    var createdAt: Date = Date()
}

extension ReadingBook {
    /// 批注列表。存成 JSON 一列，避免为一段文字再开一张表。
    var notes: [BookNote] {
        get {
            guard let data = notesRaw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([BookNote].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let text = String(data: data, encoding: .utf8)
            else { return }
            notesRaw = text
        }
    }

    /// 同一句再写一次就替换原文，不叠两条。
    func addNote(_ note: BookNote) {
        var all = notes
        if let index = all.firstIndex(where: { $0.sentence == note.sentence }) {
            all[index].text = note.text
        } else {
            all.append(note)
        }
        notes = all
    }

    func removeNote(id: UUID) {
        notes = notes.filter { $0.id != id }
    }

    func note(for sentence: String) -> BookNote? {
        notes.first { $0.sentence == sentence }
    }
}
