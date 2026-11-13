import Foundation

/// 主屏上的一格。
///
/// 一格要么是一个 App，要么是一个文件夹。用枚举而不是「文件夹里套 App 列表」，
/// 是因为拖动、删除、排序都是以「一格」为单位——分成两种类型之后，
/// 每一处循环都得写两遍。
enum HomeSlot: Codable, Identifiable, Hashable {
    case app(String)
    case folder(Folder)

    struct Folder: Codable, Identifiable, Hashable {
        var id: String
        /// 文件夹名。建的时候自动取，之后可以改。
        var title: String
        var appIDs: [String]
    }

    var id: String {
        switch self {
        case .app(let appID): return "app:\(appID)"
        case .folder(let folder): return "folder:\(folder.id)"
        }
    }

    /// 这一格里装着哪些 App。文件夹装多个，普通图标装一个。
    var appIDs: [String] {
        switch self {
        case .app(let appID): return [appID]
        case .folder(let folder): return folder.appIDs
        }
    }

    var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }
}

/// 主屏的排布：分页，每页若干格。
///
/// 存在 UserDefaults 里而不是世界状态里：它是这台手机的桌面长什么样，
/// 不是「故事走到哪一步」。换世界不该把桌面重置，备份里也不该多一坨布局数据。
struct HomeLayout: Codable {
    var pages: [[HomeSlot]]

    /// 一页放几格。四列两行——上面还有三块组件，再多就顶到 Dock 了。
    static let perPage = 8

    private static let storageKey = "shell.homeLayout"

    init(pages: [[HomeSlot]]) {
        self.pages = pages.isEmpty ? [[]] : pages
    }

    /// 默认布局：按 `AppCatalog.home` 的顺序铺，铺满一页换下一页。
    static func standard() -> HomeLayout {
        let slots = AppCatalog.home.map { HomeSlot.app($0.id) }
        return HomeLayout(pages: stride(from: 0, to: max(slots.count, 1), by: perPage).map { start in
            Array(slots.dropFirst(start).prefix(perPage))
        })
    }

    /// 去掉已经不存在的 App。
    ///
    /// 图标清单是会变的：这一版撤掉了「照片」，而旧布局里还留着那一格。
    /// 不做这一步，桌面上就多一个永远点不开的空白格子。
    func pruned() -> HomeLayout {
        let known = Set(AppCatalog.all.map(\.id))
        var next = self
        for index in next.pages.indices {
            next.pages[index] = next.pages[index].filter { slot in
                !slot.appIDs.isEmpty && slot.appIDs.allSatisfy { known.contains($0) }
            }
        }
        next.pages = next.pages.filter { !$0.isEmpty }
        if next.pages.isEmpty { next.pages = [[]] }

        // 固定入口补回桌面。应用商店原来在 Dock 第五格，那一格撤掉之后
        // 老布局里根本没有它；不补的话升级完就找不到装回图标的地方了。
        // 追加到末尾，不插队，免得顶掉用户已经排好的位置。
        for appID in AppCatalog.pinnedIDs where !next.contains(appID) {
            var last = next.pages.count - 1
            if next.pages[last].count >= perPage {
                next.pages.append([])
                last += 1
            }
            next.pages[last].append(.app(appID))
        }
        return HomeLayout(pages: next.pages)
    }

    static func load() -> HomeLayout {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(HomeLayout.self, from: data),
              !decoded.pages.isEmpty
        else { return .standard() }
        // 读的时候就补固定入口：桌面、应用商店、装/卸各读各的，
        // 只靠某一个调用点记得 .pruned() 迟早会漏一处。
        return decoded.pruned()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    // MARK: - 装 / 卸

    /// 桌面上有没有这个 App（文件夹里也算）。
    func contains(_ appID: String) -> Bool {
        pages.contains { page in page.contains { $0.appIDs.contains(appID) } }
    }

    /// 装到桌面：追加到最后一页，满 8 个就另起一页。
    ///
    /// 不插队到第一页：用户的排布是有习惯的，新装的 App 顶掉别人的位置
    /// 比「多翻一页」更烦。App 本身来自清单，这里只写桌面这一格。
    static func install(_ appID: String) {
        var layout = load().pruned()
        guard !layout.contains(appID) else { return }
        guard !layout.pages.isEmpty else {
            HomeLayout(pages: [[.app(appID)]]).save()
            return
        }
        var last = layout.pages.count - 1
        if layout.pages[last].count >= perPage {
            layout.pages.append([])
            last += 1
        }
        layout.pages[last].append(.app(appID))
        layout.save()
    }

    /// 从桌面卸掉。只动桌面这一格，App 本身和它的数据都不受影响。
    static func remove(_ appID: String) {
        // 固定入口不给卸：它自己是唯一能把别的图标装回来的地方。
        guard !AppCatalog.pinnedIDs.contains(appID) else { return }
        var layout = load().pruned()
        for pageIndex in layout.pages.indices {
            if let index = layout.pages[pageIndex].firstIndex(where: { $0.appIDs == [appID] }) {
                layout.pages[pageIndex].remove(at: index)
                break
            }
        }
        HomeLayout(pages: layout.pages.filter { !$0.isEmpty }).save()
    }

    /// 恢复默认桌面：清单里的 App 全部装回来，按默认顺序排。
    static func restoreStandard() {
        standard().save()
    }

    // MARK: - 位置

    /// 找出某一格在哪一页第几个。
    func locate(_ slotID: String) -> (page: Int, index: Int)? {
        for (pageIndex, page) in pages.enumerated() {
            if let index = page.firstIndex(where: { $0.id == slotID }) {
                return (pageIndex, index)
            }
        }
        return nil
    }

    /// 把一格挪到某一页的某个位置。位置传 nil 表示追加到末尾。
    ///
    /// 挪走之后原页如果空了就把这页删掉——空页翻过去是一整屏白，
    /// 用户以为是 bug 而不是「这一页没东西」。
    mutating func move(_ slotID: String, toPage target: Int, at index: Int?) {
        guard let from = locate(slotID) else { return }
        let slot = pages[from.page].remove(at: from.index)
        let pageIndex = min(max(0, target), pages.count)
        if pageIndex == pages.count { pages.append([]) }
        let insertAt = min(index ?? pages[pageIndex].count, pages[pageIndex].count)
        pages[pageIndex].insert(slot, at: insertAt)
        prune()
    }

    /// 把一格放到另一格上：两格合成一个文件夹。
    ///
    /// 合成之后两边的 App 都进新文件夹，顺序是「被盖住的那个在前」——
    /// 用户想的是「把 B 拖进 A」，不是「A 跑到 B 后面」。
    mutating func merge(_ movingID: String, into targetID: String) {
        guard movingID != targetID,
              let movingAt = locate(movingID),
              let targetAt = locate(targetID)
        else { return }

        let moving = pages[movingAt.page][movingAt.index]
        let target = pages[targetAt.page][targetAt.index]

        // 两个文件夹合并：App 全都并进去。
        var appIDs = target.appIDs
        for appID in moving.appIDs where !appIDs.contains(appID) {
            appIDs.append(appID)
        }
        guard appIDs.count > 1 else { return }

        let folder = HomeSlot.folder(
            HomeSlot.Folder(
                id: UUID().uuidString,
                title: folderTitle(for: appIDs),
                appIDs: appIDs
            )
        )
        pages[targetAt.page][targetAt.index] = folder
        // 再定位一次：上面那次赋值可能没改变下标，但 moving 那一格要单独删。
        if let fresh = locate(movingID) {
            pages[fresh.page].remove(at: fresh.index)
        }
        prune()
    }

    /// 把文件夹里最后一个 App 带走之后，文件夹自己应该消失。
    mutating func removeApp(_ appID: String, fromFolder folderID: String) {
        for pageIndex in pages.indices {
            for index in pages[pageIndex].indices {
                guard case .folder(var folder) = pages[pageIndex][index],
                      folder.id == folderID
                else { continue }
                folder.appIDs.removeAll { $0 == appID }
                if folder.appIDs.count <= 1 {
                    // 只剩一个就不叫文件夹了，摊回成普通图标。
                    if let last = folder.appIDs.first {
                        pages[pageIndex][index] = .app(last)
                    } else {
                        pages[pageIndex].remove(at: index)
                    }
                } else {
                    pages[pageIndex][index] = .folder(folder)
                }
                prune()
                return
            }
        }
    }

    /// 改文件夹名。
    mutating func rename(folderID: String, to title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        for pageIndex in pages.indices {
            for index in pages[pageIndex].indices {
                guard case .folder(var folder) = pages[pageIndex][index],
                      folder.id == folderID
                else { continue }
                folder.title = clean
                pages[pageIndex][index] = .folder(folder)
                return
            }
        }
    }

    /// 拆开文件夹：里面的 App 一个接一个铺到同一页。
    mutating func ungroup(folderID: String) {
        guard let at = pages.indices.first(where: { page in
            pages[page].contains { if case .folder(let f) = $0 { return f.id == folderID }; return false }
        }) else { return }

        guard let index = pages[at].firstIndex(where: {
            if case .folder(let f) = $0 { return f.id == folderID }
            return false
        }) else { return }

        guard case .folder(let folder) = pages[at][index] else { return }
        pages[at].remove(at: index)
        let slots = folder.appIDs.map { HomeSlot.app($0) }
        pages[at].insert(contentsOf: slots, at: min(index, pages[at].count))
        prune()
    }

    /// 页数变了之后重新收一遍：删掉空页，溢出的往后推。
    private mutating func prune() {
        pages = pages.filter { !$0.isEmpty }
        if pages.isEmpty { pages = [[]] }

        var index = 0
        while index < pages.count {
            if pages[index].count > HomeLayout.perPage {
                let overflow = Array(pages[index][HomeLayout.perPage...])
                pages[index] = Array(pages[index].prefix(HomeLayout.perPage))
                if index + 1 < pages.count {
                    pages[index + 1].insert(contentsOf: overflow, at: 0)
                } else {
                    pages.append(overflow)
                }
            }
            index += 1
        }
    }

    /// 文件夹名取前两个 App 的名字。
    ///
    /// 不用「文件夹」「新建文件夹」这种泛称：真机的文件夹名就是这么来的，
    /// 而且用户一眼能看出里面大概是什么，不用点开。
    private func folderTitle(for appIDs: [String]) -> String {
        let names = appIDs.prefix(2).compactMap { id in
            AppCatalog.home.first { $0.id == id }?.name
        }
        return names.isEmpty ? "文件夹" : names.joined(separator: "·")
    }
}
