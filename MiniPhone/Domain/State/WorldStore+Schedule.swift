import Foundation

extension WorldStore {
    /// 今天的日程里加一条，或者改一条。
    ///
    /// 日程本来是本地排出来的，人自己改过之后就是人的：这里按 id 覆盖，
    /// 不动别的条目，也不重新生成——重排一次会把她刚写的东西冲掉。
    func upsertScheduleItem(_ item: ScheduleItem) {
        var schedule = state.schedule ?? DaySchedule(
            dateKey: DayScheduleEngine.dateKey(),
            items: [],
            generatedAt: Date()
        )

        if let index = schedule.items.firstIndex(where: { $0.id == item.id }) {
            schedule.items[index] = item
        } else {
            schedule.items.append(item)
        }
        schedule.items.sort { $0.hour < $1.hour }

        state.schedule = schedule
        save()
    }

    func deleteScheduleItem(id: UUID) {
        guard var schedule = state.schedule else { return }
        schedule.items.removeAll { $0.id == id }
        state.schedule = schedule
        save()
    }
}
