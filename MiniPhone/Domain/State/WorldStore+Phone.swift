import Foundation

extension WorldStore {
    /// 取当前角色的那台手机。
    ///
    /// 世界状态里只存一台，`owner` 对不上就当没有 —— 换了角色不会串台，
    /// 也不会因为换人就把上一个人的内容删掉（换回去还能接着看）。
    func phone(for characterName: String) -> CharacterPhone? {
        guard let phone = state.phone, !phone.owner.isEmpty, phone.owner == characterName else {
            return nil
        }
        return phone
    }

    func savePhone(_ phone: CharacterPhone) {
        state.phone = phone
        state.updatedAt = Date()
        save()
    }

    /// 截图流水线用：垫一台已经生成好的手机，省掉一次真的模型调用。
    /// 只在带 `-previewState` 启动时写，正常启动读不到这个键。
    func seedPreviewPhone(owner: String) {
        guard state.phone == nil else { return }
        guard var phone = CharacterPhoneParser.parse(Self.previewPhoneJSON, owner: owner) else { return }
        // 预备好的那份内容是写死的名字，截图里要跟当前角色对上，这里直接改归属。
        phone.owner = owner
        state.phone = phone
        save()
    }

    private static let previewPhoneJSON = """
    {
      "owner": "沈砚",
      "chats": [
        {"name": "妈", "relation": "家人", "time": "20:51", "unread": 2, "pinned": true,
         "lines": [
           {"fromMe": false, "text": "周末回来吃饭吗", "time": "20:41"},
           {"fromMe": true, "text": "看情况，可能要加班", "time": "20:44"},
           {"fromMe": false, "text": "你上次带的那个姑娘呢", "time": "20:49"},
           {"fromMe": true, "text": "妈", "time": "20:50"},
           {"fromMe": false, "text": "问问而已，你急什么", "time": "20:51"}
         ]},
        {"name": "陈叙", "relation": "朋友", "time": "19:30", "unread": 0, "pinned": false,
         "lines": [
           {"fromMe": false, "text": "那事儿你别跟她说", "time": "19:12"},
           {"fromMe": true, "text": "我知道", "time": "19:14"},
           {"fromMe": false, "text": "钱我下个月还你", "time": "19:15"},
           {"fromMe": true, "text": "不急", "time": "19:30"}
         ]},
        {"name": "我", "relation": "置顶", "time": "21:06", "unread": 0, "pinned": true,
         "lines": [
           {"fromMe": false, "text": "带伞了吗", "time": "21:04"},
           {"fromMe": true, "text": "没。淋一点没事", "time": "21:06"}
         ]},
        {"name": "周舟", "relation": "组里", "time": "18:22", "unread": 0, "pinned": false,
         "lines": [
           {"fromMe": false, "text": "第二版我看了，节奏没问题", "time": "18:20"},
           {"fromMe": true, "text": "嗯", "time": "18:22"}
         ]},
        {"name": "顺丰速运", "relation": "", "time": "17:12", "unread": 0, "pinned": false,
         "lines": [
           {"fromMe": false, "text": "您的包裹已放至丰巢，取件码 8821", "time": "17:12"}
         ]},
        {"name": "房东", "relation": "", "time": "昨天", "unread": 0, "pinned": false,
         "lines": [
           {"fromMe": false, "text": "下个月水费涨了二十", "time": "昨天 10:02"},
           {"fromMe": true, "text": "知道了", "time": "昨天 10:40"}
         ]}
      ],
      "album": [
        {"seed": 4, "caption": "楼下那只", "takenAt": "昨天 18:20"},
        {"seed": 1, "caption": "今天下了一天", "takenAt": "今天 08:12"},
        {"seed": 6, "caption": "下班路上", "takenAt": "昨天 17:40"},
        {"seed": 3, "caption": "第三杯", "takenAt": "周三 15:02"},
        {"seed": 7, "caption": "她说过这条街好看", "takenAt": "周三 21:11"},
        {"seed": 2, "caption": "", "takenAt": "周二 23:48"},
        {"seed": 0, "caption": "从公司窗户拍的", "takenAt": "周二 18:30"},
        {"seed": 5, "caption": "上次去的那片", "takenAt": "上周"}
      ],
      "notes": [
        {"title": "要买的", "body": "洗衣液\\n垃圾袋\\n她说的那个牌子的护手霜（无香的那款）", "editedAt": "周三 23:10"},
        {"title": "周五", "body": "九点半评审，带第二版。\\n下午去银行。", "editedAt": "周四 08:02"},
        {"title": "她说过的", "body": "不吃香菜。\\n怕吵。\\n喜欢靠窗。", "editedAt": "上周"},
        {"title": "报销", "body": "打车 62\\n打印 18\\n发票在包里", "editedAt": "周二"}
      ],
      "calls": [
        {"name": "妈", "kind": "呼入", "duration": "12 分 40 秒", "time": "20:30"},
        {"name": "陈叙", "kind": "呼出", "duration": "3 分 12 秒", "time": "19:05"},
        {"name": "未知号码", "kind": "未接", "duration": "", "time": "17:22"},
        {"name": "公司前台", "kind": "呼入", "duration": "48 秒", "time": "15:10"},
        {"name": "房东", "kind": "呼出", "duration": "2 分 03 秒", "time": "昨天"},
        {"name": "我", "kind": "呼入", "duration": "26 分 18 秒", "time": "昨天 22:40"},
        {"name": "快递", "kind": "未接", "duration": "", "time": "昨天 16:02"}
      ],
      "shopping": [
        {"title": "给猫买的猫抓板", "price": "¥49", "status": "已下单", "addedAt": "昨夜 00:12"},
        {"title": "无香护手霜", "price": "¥68", "status": "购物车", "addedAt": "周三 23:20"},
        {"title": "袜子五双", "price": "¥39", "status": "已签收", "addedAt": "周一"},
        {"title": "台灯（暖光）", "price": "¥129", "status": "购物车", "addedAt": "周三 23:22"},
        {"title": "洗衣液", "price": "¥45", "status": "已签收", "addedAt": "上周"}
      ],
      "history": [
        {"title": "护手霜哪个牌子不油腻", "site": "小红书", "time": "23:41"},
        {"title": "暖光台灯 卧室 推荐", "site": "小红书", "time": "23:22"},
        {"title": "怎么跟家里人说不想相亲", "site": "知乎", "time": "22:10"},
        {"title": "杭州 十一月 还热吗", "site": "百度", "time": "20:15"},
        {"title": "猫抓板 味道大不大", "site": "淘宝", "time": "00:11"},
        {"title": "借钱给朋友 要不要写借条", "site": "知乎", "time": "19:40"},
        {"title": "加班到几点 地铁还有吗", "site": "高德", "time": "18:50"}
      ],
      "usage": [
        {"app": "微信", "minutes": 96, "note": "跟妈说了两句，剩下都在组里"},
        {"app": "小红书", "minutes": 41, "note": "搜了两样东西"},
        {"app": "视频", "minutes": 88, "note": "放着没怎么看"},
        {"app": "游戏", "minutes": 34, "note": "两把就关了"},
        {"app": "地图", "minutes": 12, "note": ""},
        {"app": "备忘录", "minutes": 9, "note": ""}
      ],
      "secrets": [
        {"kind": "secret", "title": "周五那笔钱", "text": "借给陈叙了，没跟她说。本来这个月要带她去看展。", "time": "周四"},
        {"kind": "secret", "title": "藏起来的东西", "text": "护手霜已经在购物车里放了三天，等发了钱就下单。", "time": "周三 23:20"},
        {"kind": "secret", "title": "没讲的麻烦", "text": "妈今天又提相亲。他说了「不急」，其实回了很长一段又删了。", "time": "20:52"},
        {"kind": "private", "title": "那天她靠在肩上", "text": "地铁上她睡着了，我没敢动，坐过了两站。", "time": "上周"}
      ]
    }
    """
}
