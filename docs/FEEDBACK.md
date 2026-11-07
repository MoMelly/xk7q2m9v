# 口头需求台账

来源是 melly 在对话里的零散反馈。她说话不成条，这里负责把话落成条目、
标好状态；每一条写清楚「原话的意思」和「落在哪个文件」，做完不删，改状态。
文档五月一起就有的：`PLAN.md` 管工程，`ROADMAP.md` 管功能对照，这份管**她本人的规矩**。

---

## 1. 硬规矩（不许违反）

| 规矩 | 日期 | 现状 |
|---|---|---|
| 头像一律不准真人。猫、狗、卡通、二次元、风景都行，真人脸一张不许有 | 11-06 | 已落实。包里 30 张：猫狗 8 / 卡通 6 / 二次元 6 / 风景 10 |
| 页面不要看上去就是「等待输入」的状态，点击之后才进入输入状态 | 11-07 | 已落实。聊天输入栏默认收成一条「点这里说话」，点了才展开 |
| 不要透明的、花哨的排版，按系统分组页的样子排；有些东西收进次级菜单 | 11-07 | 已落实。「我的资料」改成 GroupedSection 列表，编辑项全部收次级 |
| 壁纸太脏、看不清图标 | 11-06 | 已落实。日间不再蒙黑，夜间才压暗 |

## 2. 本轮（11-07）做完的

| 需求 | 落点 | 验收 |
|---|---|---|
| 西瓜皮主页背景图太大，改到约屏高 1/5 | `FeedProfilePage.swift` bannerHeight | feedProfile 截图 |
| Dock 不像液态玻璃、灰蒙蒙（深浅都一样） | `GlassSurface` 加 tint 参数，Dock 白膜垫进玻璃、去掉外叠 0.62 白 overlay | home / homeNight 截图对比 |
| 聊天输入栏默认收起，点击才进入输入态 | `ChatView.swift` restingComposer / activeComposer，失焦且无面板时自动躺回 | chat 截图（应拍到收起态） |
| 「我的」页改分组列表，编辑收次级菜单 | `MyProfilePage.swift` 重写：名字/签名/状态/符号/底色五个次级页 | chatMine 截图 |

## 3. 之前做完、有据可查的

| 需求 | 落点 |
|---|---|
| 表情进提示词、输入栏固定按钮、气泡渲染表情图 | `PromptBuilder` / `ChatView` / `MessageBubble` |
| 角色维度「能用哪些表情」开关 | `CharacterStickerPage`，行入口在 `CharacterDetailPage` |
| 头像自己上传（我和角色） | `AvatarPickerSheet`（相册 + 内置 + 不用照片） |
| 发图片（模拟图片，不走真相册） | `MockPhoto` 八场景现画，`StoredMessage.imageSeed` |
| 我的状态（一句话 + 表情，进提示词） | `UserProfile.statusText`，`UserIdentity` 搬运，`ProfileStatusPage` 编辑 |
| 桌面 / 锁屏壁纸分开设，可挑相册照片 | `WallpaperSelection` / `AppearancePage` |
| 通话页表情入口 | `CallOverlay` 输入栏表情按钮 |
| 分享帖子改小红书式弹层 | `FeedSharePicker` 半屏九宫格 |
| 莓果红换掉 | `#D93A3F`（原 `#E83A56` 发品红） |
| 二次元、泰迪头像保留 | 11-07 明确：插画不算真人，留着 |

## 4. 还没做的

| 需求 | 说明 |
|---|---|
| 深色模式整体复查 | 她点名「深色也一样（灰蒙蒙）」，Dock 已修，其他页面没逐一查。下一轮 CI 截图把 homeNight / chatNight 过一遍 |
| 西瓜皮图标是否跟主题色 | 问过她没回，维持写死 |
| 真照片发送 | 只做了模拟图片；真相册发送没做，她没再要 |
