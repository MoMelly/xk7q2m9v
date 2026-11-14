import Foundation

extension PreviewSeeder {
    /// 日程半屏卡的截图底子。
    ///
    /// 要拍到「有地点、有同去」的样子；空条目只会拍出那句灰字提示，
    /// 改版后的三行详情就白截了。
    func seedScheduleCard() {
        // 日程是每天现排的，开机时可能已经有一份；只在缺这行时才补，
        // 不然每拍一次就多一条同名的。
        let existing = world.state.schedule?.items ?? []
        guard !existing.contains(where: { $0.title == "去取修好的鞋" }) else { return }
        world.upsertScheduleItem(
            ScheduleItem(
                hour: 14,
                title: "去取修好的鞋",
                mood: .calm,
                note: "顺便买点猫粮",
                place: "巷口那家店",
                companions: ["小满"]
            )
        )
        world.upsertScheduleItem(
            ScheduleItem(hour: 19, title: "跟她吃个饭", mood: .glad, place: "老地方")
        )
    }
}
