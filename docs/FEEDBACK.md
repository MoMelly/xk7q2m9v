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
| 「我的」页的栏改成液态玻璃，不要白底；状态、签名紧跟在头像名字下面 | 11-07 | 已落实。`GroupedSection` 加 glass 开关，行序改为状态/签名/名字，`MyProfilePage` 两个分组走玻璃面 |
| 壁纸太脏、看不清图标 | 11-06 | 已落实。日间不再蒙黑，夜间才压暗 |

## 2. 本轮（11-07）做完的

| 需求 | 落点 | 验收 |
|---|---|---|
| 西瓜皮主页背景图太大，改到约屏高 1/5 | `FeedProfilePage.swift` bannerHeight | feedProfile 截图 |
| Dock 不像液态玻璃、灰蒙蒙（深浅都一样） | `GlassSurface` 加 tint 参数，Dock 白膜垫进玻璃、去掉外叠 0.62 白 overlay | home / homeNight 截图对比 |
| 聊天输入栏默认收起，点击才进入输入态 | `ChatView.swift` restingComposer / activeComposer，失焦且无面板时自动躺回 | chat 截图（应拍到收起态） |
| 「我的」页改分组列表，编辑收次级菜单 | `MyProfilePage.swift` 重写：名字/签名/状态/符号/底色五个次级页 | chatMine 截图 |

## 2. 本轮（11-07 下午）真机实测反馈

「我的」页玻璃 + 状态/签名重排、Dock 提白、装机（iLoader 直装）之外，她上真机玩了一遍，反馈如下。

**已修（本轮提交）**：

| 需求 | 落点 |
|---|---|
| 状态栏/网络条达不到屏幕最顶端 | Home/Lock 外层 `.ignoresSafeArea(edges: .top)`，假状态栏从物理顶端画起 |
| 「我的」页不该有「搜索会话或联系人」 | 搜索栏只在 消息/通话/联系人 显示 |
| 备忘录删不掉 | 行左滑删除 + 长按菜单（置顶/删除）+ 编辑页工具栏置顶/删除按钮 |
| 笔记「分享到私聊」按钮太大 | 收成右端小胶囊 |
| 西瓜图标太大 | AppIconTile 瓜 0.84 → 0.72 |
| 小红书主页封面再拉高一点 | banner 20% → 24.5% |
| 发一句就自动回一句不像真人 | **聊天改为手动触发**：发送键只落库（表情/图片同样），输入栏最右新增「回话」键，攒了几句点它才回复；键盘回车回归换行；通话模式保持一句一答 |

**待做（按优先级排）**：

| 需求 | 说明 / 方案 |
|---|---|
| 聊天界面背景可自定义 | **已做（11-07 傍晚）**：三档——主题渐变 / 流动动效（缓慢漂移+呼吸的渐变）/ 相册图片（`PhotosPicker` 走系统相册，压暗膜保文字对比度）。入口：设置 → 外观与壁纸 → 聊天背景，聊天页和会话列表共用。她确认：从**相册**导，不是从文件 |
| 主题里自定义气泡 | 气泡样式/颜色跟主题走，主题页加气泡选择 |
| 彩色玻璃饱和度可调 | 做一个全局饱和度档位（设置 → 外观） |
| 日历按剧情来，不瞎编 | 答疑过：日历本来就是虚拟世界的（角色作息+聊天盖章），不读真机日历。要做的：事件由剧情/记忆驱动生成 + 手动加日程入口 + 日历页能读记忆摘要 |
| 信件玩法重做 | 预置一封小助手的信做示例；信件列表加分类/收藏；「让它写封信」入口（点一下角色就写一封） |
| 玩法入口理清 | ~~剧情/直播/信件从角色详情进~~ **她纠正（11-07 下午）：理解错了**，见下面两条 |
| 线下模式是独立 App，乙游式演出 | 桌面新图标（文游），**绝不是塞进短信页**。她 11-07 再定：**纯文字排版**（没有立绘/背景素材，不硬上画面），入口填故事线 → AI 起标题挑角色 → 逐轮选项/自由输入推进 → 结束三选一回写：记入剧情（角色当真事）/ 不记入 / 角色当游戏。立绘演出（需求 18/19/26）等素材再说。**已做**：`Features/StoryGame/`（存档/视图模型/列表/阅读页），桌面「文游」图标，previewState `storyGame` |
| 直播在西瓜皮里开栏 | 西瓜皮（feed）加「直播」tab：路人在播 + 角色自己开播（人名+整点哈希联动，最多两间，标题取人设开头），点进是真直播间：满屏场景图、在线人数漂移、滚动弹幕、发弹幕、礼物按钮；**角色房间发弹幕调 API 主播接话**（人设+直播口吻），路人房间纯氛围。**已做**：`Features/Scenes/LiveListPage.swift` / `LiveRoomPage.swift`，previewState `feedLive` |
| 健康照片动态看不懂 | 照片动态是世界的帖子流卡片进了健康页，语义不符——健康页删掉照片动态，只留数据 |
| 预制图片多一点 | MockPhoto 加场景；图片消息生成时先出「图片加载中」占位 |
| 应用弹出/弹入动效 | 现在的 scale+opacity 弹簧太糙，参考 iOS 真机的缩放原点（从图标位置放大） |
| 动态/信息界面切换动效 | 底部页签切换加过渡动画 |
| 小组件做起来 | 需求表 §9 挂着的：锁屏/桌面小组件（心情、心声、待办回复） |
| 图标可拖拽/建文件夹 | 桌面图标长按抖动 + 拖拽换位 + 合并成文件夹，大工程 |
| 整体内容量偏少 | 大方向：把成熟社交 App 的信息密度抄过来（列表细节、角标、分组头、空态插画） |

**音乐**：她说了最后做，继续押后。

## 4. 还没做的

| 需求 | 说明 |
|---|---|
| 深色模式整体复查 | 她点名「深色也一样（灰蒙蒙）」，Dock 已修，其他页面没逐一查。下一轮 CI 截图把 homeNight / chatNight 过一遍 |
| 西瓜皮图标是否跟主题色 | 问过她没回，维持写死 |
| 真照片发送 | 只做了模拟图片；真相册发送没做，她没再要 |

## 5. 第二轮真机实测（11-07 晚）

**本轮已修**：

| 需求 | 落点 |
|---|---|
| 备忘录编辑页工具栏按钮黑色看不清 | `toolbarColorScheme(.light)` 压住导航栏 |
| 视频壁纸从「文件」导入 → 改相册 | `PhotosPicker(.videos)`，`loadTransferable(Data)` 直落 |
| 高清壁纸放上去发糊 | 压缩上限 1600→2560、质量 0.86→0.92 |
| 深色壁纸下图标名/状态栏黑字看不清 | 新增「桌面文字颜色」档（自动/白/黑），`HomeTextInk` 供图标名+状态栏取色 |
| 桌面顶行图标离状态栏太近 | 顶部间距 10→24 |
| 信息底栏方形的还泛绿 | 改悬浮圆角玻璃栏（iOS 26 豆壳样式），半透明 |
| 「我的」页整页墨绿底 | 摘掉自铺渐变，直接坐在聊天背景上；次级编辑页改系统浅底 |
| 聊天背景入口在设置里找不到 | 「我的」页新增「外观」组 → 聊天背景与气泡（与外观页同一组件） |
| 绿色气泡不能自定义 | `ChatBubbleStyle` 五档（薄荷/蓝/粉/紫/玻璃），设置节里选 |
| 文游「让 AI 起标题挑角色」不要 | 删掉该按钮，标题必填、角色自己挑 |
| 信件空箱像没做 | 首次进信件页种一封小助手的试用信（只种一次） |
| 「照片」App 点开全是动态，语义错 | 新建 `PhotoLibraryScene`：聊天发过的图按时间宫格+大图；照片图标改指这里 |
| 真机主屏 App 图标是默认白板 | `Assets.xcassets/AppIcon`（PIL 画的西瓜切半图标），`ASSETCATALOG_COMPILER_APPICON_NAME` 接上 |

**没做、排下一批的（都记着，不是没看见）**：

| 需求 | 说明 |
|---|---|
| 日历条目自己能改 | 手动加/删/改日程入口，事件也接剧情记忆 |
| 音乐悬浮球 + 悬浮歌词 | 播放中出悬浮球，点开歌词页；悬浮歌词模式 |
| 图标拖拽移动/建文件夹 | 桌面长按抖动、拖拽排序、拖到一起建文件夹 |
| 小组件 | 时钟/天气/心情等桌面小组件 |
| App 打开动效 | 从图标位置放大关闭，不是现在的通用缩放 |
| 每个图标自定义图片 | 主题页里逐图标上传图 + 样式 |
| 世界书/公共记忆库入口 | 现有 WorldEntry 是角色级的；要做「世界到哪一步了」的公共记忆库界面 |
| 健康页照片动态删掉 | 上轮就该删的卡片，定位到具体视图后删 |
| 锁屏玻璃时间再加强 | GlassClock 已是字形玻璃，真机上观感偏平，下一轮提对比度 |
| 信息里剩余绿色元素 | 抽屉/按钮等零散 mint 色逐个过，统一玻璃化 |

---

## 7. 第三轮真机实测（11-07 晚）

她这轮的诉求分两半：先把**所有提过的需求**整理成文档，再按文档改。

**文档**：新增 `docs/REQUIREMENTS.md`，把 PLAN / ROADMAP / DESIGN / 这份台账里的需求
按模块编号（S 外壳、C 信息、M 角色记忆、P 场景、F 西瓜皮、G 玩法、T 设置、A 动效），
逐条标 ✅ 做了 / 🟡 半成品 / ⬜ 没做 / ⛔ 不做。历史聊天只回溯到 10-31，更早的以台账为准。

**本轮已改**：

| 需求 | 落点 |
|---|---|
| 玻璃气泡要区分角色和自己，角色深一点、自己淡一点 | `MessageBubble.bubbleStack` 两侧不同底座（黑 26% / 白 14%）+ 描边，数值进 `Theme.Glass` |
| 桌面 Dock 玻璃太深，要接近信息页对话框的观感 | `HomeScreenView.dock` 改按浅色方案渲染玻璃 + 白膜降档 + 顶沿高光；信息底栏同步 |
| 消息长按：复制 / 引用 / 编辑 / 撤回 / 删除，两侧都能出 | 新增 `Features/Chat/ChatMessageMenu.swift`；`StoredMessage` 加 `isRecalled` / `quoteSpeaker` / `quoteText` / `editedAt`，备份同步 |
| 点进 App 先卡、上下先流出一道痕 | `PhoneShellView` 换掉整层缩放淡入，改成从图标位置长出来的裁剪 + 下一帧再动 |
| 信件要分类、要收藏 | `LetterScene` 三段（全部 / 未读 / 收藏）+ 行尾星标 + 读信页星标；`Letter.isFavorite` 容忍老存档缺字段 |

**这轮没做，已排下一批**：音乐悬浮球 + 悬浮歌词（她点名「听歌那些应该都没做」，确实只有资料库和播放）。



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

---

# 真机反馈补齐稿（2026-11-08 ～ 2026-11-13）

`docs/FEEDBACK.md` 的时间线停在 11-07 晚的第三轮，11-08 到 11-13 这六天的真机反馈只留在日记里，
没有进台账。这份是补齐稿：来源是 `.workbuddy/memory/` 下 `2026-11-08.md` ～ `2026-11-13.md` 六个文件，
只收她本人提的需求、抱怨、口味，工程动作（改了哪个函数、踩了什么坑）不收。

合并进 `FEEDBACK.md` 时**不必拆段**：每节 3～10 行，整节搬过去，接在现有最后一节（`## 7. 第三轮真机实测`）后面
按 8、9、10…… 顺延。顺带两处要修：现有台账有两个「## 2.」、缺 3 和 6，编号本来就连不上；
「第二轮 / 第三轮」在台账里指 11-07 晚那两轮，而 11-08 日记里又有一个「第二轮」，合并时靠日期区分。

小节名照日记自己的叫法（第三批 / 第五批 / 第六批 / 第七批）；日记没给批次的按日期分。「第四批」在六天日记里没有出现过。
「落点」全部按日记原样抄（相对 `MiniPhone/` 目录），并逐一核对过文件真实存在；找不到的写「未核实」。

## 11-08 真机反馈（看截图之后的「第二轮」）

| 需求（她的说法） | 落点 | 验收方式 |
|---|---|---|
| 「组件离灵动岛太近」——主屏三块组件往上顶，压着灵动岛（11-08） | `Shell/HomeScreenView.swift`，组件顶部间距 14 → 26 | `home.png` 组件顶边与灵动岛之间留白 |
| 「上下重复的 App 去掉」——Dock 只放 信息 / 西瓜皮 / TA 的手机 / 设置，桌面只留内容类（11-08） | `Shell/AppCatalog.swift` 的 `dock` 四项与 `home` 九项；`openApp` 与通知横幅改在 home+dock 里查 | `home.png` 数一遍，桌面和 Dock 不重名 |
| 「情侣空间颜色难看」——橙红渐变像宣传图，改磨砂玻璃 + 左上角玫瑰柔光 + 墨色数字 + 14 天竖条（11-08） | `Features/Couple/CoupleScene.swift`、`DesignSystem/Theme.swift` 的 `Theme.IconTint.rose` | `couple.png` 大卡是玻璃面，不是橙红渐变 |
| 「听歌界面不满意」——方方正正的音乐符号换成右上角转动的黑胶，33⅓ 转、暂停停在当前角度（11-08） | `DesignSystem/MiniPlayer.swift` 的 `CompactDisc`（118 行定义，333 行 `size: 74`、`rotatesItself: true`） | `musicLyrics.png` 右上角是黑胶而不是方块封面 |
| 「一起听体现不出来」——歌词页标题下要写「和 XX 一起在听」，当前播放进提示词【他正在听】（11-08） | `DesignSystem/MiniPlayer.swift` 的 `LyricsPage`、`Domain/State/WorldStore+Context.swift` 的 `listeningNow`（`Domain/Roleplay/PromptBuilder.swift:443` 读它） | 歌词页有那行字；没邀请时那行不出现 |
| 一起听必须先邀请——聊天顶栏电话菜单 / 输入栏「+」→「一起听」，对话上方出现状态条、可结束，全程不调 API（11-08） | `Features/Chat/ChatTogetherBar.swift`、`Features/Chat/ChatHeaderBar.swift` 的 `ChatCallMenuItems`、`Support/PlayerService.swift` 的 `invite/endTogether` | 点「一起听」后聊天页上方出状态条；截图预置里要先 `invite(companions.first)` 才拍得到 |
| 「发真照片不做」——只留模拟图片，真相册发送作废（11-08） | `docs/REQUIREMENTS.md` 的 C-16 标 ⛔ | 台账里 C-16 是 ⛔，不是「没做」 |
| 世界书和记忆必须完善到「聊天里那个本人知道这些事」——常驻档不靠关键词、记忆按话题重合度排、手机内容与正在听都进提示词（11-08） | `Domain/State/WorldBookTypes.swift` 的 `WorldEntry.alwaysOn`、`Domain/Roleplay/PromptBuilder.swift` 的 `constantEntries`、`Domain/State/WorldStore+MemoryLines.swift` 的 `relevance` / `phoneLines` | 真机上问一件世界书写过的事，回复不该是「哦你养猫啊」式反问 |

## 11-08 第四轮：健康并入「TA 的手机」

| 需求（她的说法） | 落点 | 验收方式 |
|---|---|---|
| 健康页整页不要了（11-07「照片动态看不懂」的收尾），内容并进「TA 的手机」底部：允许查手机开关 + 设备信息 + 我这边的页面停留（11-08） | `Features/Peek/MyDeviceSection.swift` 的 `MyDeviceCard` | `phonePeek.png` 底部有开关和设备信息，健康 App 已不存在 |
| 桌面「健康」图标删掉，桌面剩 8 个、4+4 排满不留空格（11-08） | `Shell/AppCatalog.swift`、`SceneKind` 去掉 `.health` | `home.png` 桌面 4+4，最后一行不空三格 |
| 一个人听歌不该让角色知道：只有「邀请的是当前角色 + 真的在放」才写歌，块名【你们在一起听】（11-08） | `Support/PlayerService.swift` 的 `isTogether(with:)`、`Features/Chat/ChatViewModel.swift:221`、`Domain/Roleplay/PromptBuilder.swift` 的 `worldBlock` | 没邀请时歌词页没有「和 XX 一起在听」，提示词里也没有这首歌 |

## 11-09 多角色：查手机 / 火花只留一份

| 需求（她的说法） | 落点 | 验收方式 |
|---|---|---|
| 实测发现「有好几个角色时，查手机只能查到最近说话的那个」（11-09）——一台手机改成人手一台 | `Domain/State/WorldTypes.swift:376` 的 `phones: [CharacterPhone]`、`Domain/State/WorldStore+Phone.swift`（按 owner upsert，老存档解码时搬进数组） | `phonePeek.png` 顶部三颗胶囊：小助手 / 沈砚 / 小满 |
| 查手机页顶要能选人：名字胶囊条，默认「最近说过话的人」，从角色详情进来是确定的（11-09） | `Features/Peek/CharacterPhoneScene.swift`、`DesignSystem/NameChipStrip.swift` | `phonePeek.png` 名字胶囊可切换，切换后内容跟着换 |
| 角色详情「TA 的」组里要有一行「XX 的手机」，带「已生成 / 还没打开」（11-09） | `Features/Conversations/CharacterDetailPage.swift` | `charDetail.png` 有「小助手 的手机」这一行 |
| 火花跟着人走，不能全班共用一份（11-09） | `Domain/State/WorldTypes.swift:380` 的 `couples[String: CoupleState]`、`Domain/State/WorldStore+Couple.swift`、`Features/Couple/CoupleScene.swift` | `couple.png` 沈砚 41 天；换角色后各算各的 |
| 「你全都改完吧，然后我们之前需求接着往下做」（11-09）——不再一条条问，剩下的连控制中心、锁屏四位密码、磨砂三档、聊天红包一起推 | `Shell/ControlCenter.swift`、`Shell/PasscodePad.swift`、`DesignSystem/ThemeStore.swift` 的 `GlassDensity`、`Features/Chat/RedPacket.swift` | `controlCenter.png` / `redPacket.png` 两张截图；磨砂三档在主题页有小样 |

## 11-10 收口与群聊（第七～十一轮）

| 需求（她的说法） | 落点 | 验收方式 |
|---|---|---|
| 「不要管限制，现在直接把全部方向补完；在此之前不要停下」（11-10）——台账剩 15 条一次做完，只砍 G-11 真 Live2D | `docs/REQUIREMENTS.md`（S-14/15、S-20、M-13/14/15/20、F-12、T-11、S-02、G-09/10/12/13） | 台账 124 条里只剩 G-11 是 ⛔ |
| 「群聊只有一个人」（11-10）——三个独立成因：`asChatMessage` 丢 `speaker`、`relatedNames` 用 `Array(Set(...))` 再取 `names.first` 决定读谁的日程、`【角色】` 只写群主 | `Data/Persistence/Models.swift:264`、`Domain/State/WorldStore+Context.swift`、`Domain/Roleplay/WorldBookResolver.swift` | `chatGroup.png` 五条消息带两个不同署名（沈砚 / 林渡） |
| 西瓜皮不要 AI 配图，要封面随机（11-10）——F-13 整套撤掉，回 `NoteCover` 按 seed 排文字卡 | 删掉 `ImageGenClient.swift` / `FeedImageService.swift` / `FeedImageStorage.swift` / `FeedCover.swift` / `FeedImagePage.swift`；保留 `DesignSystem/NoteCover.swift` | 动态封面是文字卡；设置里没有配图开关和按张计费入口 |
| 群聊里不收「对人」的功能：日程、通话菜单、拍一拍、作息（群永远醒着）、私信池、直播、查手机、情侣页、文游花名册、锁屏小组件、记忆库统计全部排除，详情页只留群记忆 + 群成员（11-10） | `Features/Conversations/CharacterDetailPage.swift` | `groupDetail.png` 只有「群里的记忆」「群成员 2 人」两行 |

## 11-11 定调：群记忆分栏 / 备份 / 群聊口径

| 需求（她的说法） | 落点 | 验收方式 |
|---|---|---|
| 群记忆页按成员分栏（三个方案里她选的这个）：共同一块 + 每人一块，没笔记的成员给可点的空占位（11-11） | `Features/Conversations/CharacterMemoryPage.swift`、`Features/Conversations/MemoryItem.swift` 的 `Kind.groupNote`、`MemoryItemEditor.swift` | `groupMemory.png`「群里共同的事 / 林渡 记住的 / 沈砚 记住的」，底部 2 人 / 2 份 / 1 条 |
| 「你自己弄，我还没开始玩」（11-11）——备份格式与版本号放权给我们，但恢复前要二次确认，别一键覆盖 | `Data/Persistence/DataBackup+Library.swift`、`DataBackup.swift` 的 `currentVersion` 3 → 11、`Features/Settings/DataPage.swift` 的 `pendingRestore` + `confirmationDialog` | 选完备份文件先弹确认（写清会被替换的内容），点确认才恢复 |
| 「哪个对功能更好就改哪个」（11-11，B-1/B-3/B-4 她没逐个选）——群成员「此刻」进提示词、设定条件按人判、压缩阈值 10000 → 60 | `Features/Chat/ChatViewModel+World.swift` 的 `groupMates`、`Domain/Roleplay/WorldBookResolver.swift` 的 `memberConditions`、`Domain/State/GenerationPlan.swift` 的 `compressionThreshold` | 群里每个人设后面多一行「此刻：心情…，人在…，今天：…，跟你…」；群摘要约 30 轮生成一次 |
| 群聊不该出现「你们现在的关系」这句——群名永远查不到好感度，`affinity` 传 `nil`（11-11） | `Domain/State/WorldStore+Context.swift` | 群聊提示词里不再有那段关系块 |

## 11-12 第二轮反馈的尾巴：批注 / 分组 / 小助手

| 需求（她的说法） | 落点 | 验收方式 |
|---|---|---|
| 阅读要能长按写批注：存原句不存字符位置（改字号、行距、页边距会重新分页），批注过的句子要留痕，还要有批注总览（11-12） | `Features/Reading/BookNote.swift`、`PageTextView.swift`、`ReaderNoteSheet.swift`、`BookNotesPage.swift`（工具栏第三颗图标） | 长按 0.35s 出编辑框；改完字号批注仍挂在原句上 |
| 信息 App 要按名字分组：A–Z 分节 + 右侧胶囊索引、只画有人的字母；消息列表加「按时间 / 按名字」胶囊切换（11-12） | `Features/Conversations/ContactGrouping.swift`、`ContactDirectoryPage.swift`、`ConversationListView.swift` | `chat.png` 顶部两格正常，会话行不错位 |
| 小助手人设要按现在真有的功能重写（`revision = 2`），她删掉的旧样例不许再塞回来（11-12） | `Support/DefaultAssistant.swift` | 小助手不再介绍已经不存在的功能；`ensure` 按名字找而不是「库里非空」 |

## 11-12 第三批真机反馈（八条）

| 需求（她的说法） | 落点 | 验收方式 |
|---|---|---|
| 主屏长按进不了编辑态、拖不动——图标外层包了 `Button`，手势收不到事件；长按松手又被判成轻点，编辑态刚抖就退（11-12） | `Shell/HomeBoard.swift`、`Shell/HomeScreenView.swift`（`simultaneousGesture(LongPressGesture)` 兜底 + 0.45s 轻点闸门） | 真机长按图标抖起来、能拖；松手 0.45s 内的轻点不退出编辑态 |
| 主屏音乐组件是黑的——`glassEffect` 认外壳配色，外壳锁 dark 就按深色材质渲染（11-12） | `Shell/HomeWidgets.swift` 改 `frostedBar` | `home.png` 音乐组件跟「今天」同一质感，不发黑 |
| 群聊头像全一样——`row(for:)` 固定用群本身当头像（11-12） | `Features/Chat/ChatView+Row.swift` 按 `message.speaker` 回 roster 找，`ChatView` 加 `@Query roster` | `chatGroup.png` 两条消息头像是沈砚、林渡两个人 |
| 音乐页底部条名字不跟重命名——读的是 `world.state.currentTrack` 快照（11-12） | `Features/Scenes/MusicScene.swift` / `DesignSystem/MiniPlayer.swift` 按 `track.id` 回 `tracks` 取（那份套过 `MusicMeta`） | 改名后立刻反映到底部条，重启也还是新名字 |
| 底部条要液态玻璃——自拼 `ultraThinMaterial` + 压黑 0.28 在深色外壳下是黑砖（11-12） | `DesignSystem/MiniPlayer.swift` 改 `frostedBar` + `Theme.separator/tint`，行高 56 → 64 | `musicLyrics.png` 底部条是玻璃，不是黑条 |
| 悬浮球：能拖、位置记得住、设置里能关（11-12） | `DesignSystem/MiniPlayer.swift`（`@AppStorage("player.ballX/Y")` 存比例 + `DragGesture(min 6)`）、`Features/Settings/AppearancePage.swift`、`Support/SettingsStore.swift` 的 `showMusicBall` | 拖到哪里就停在哪里；设置里关掉球就消失 |
| 看板照片被切脸——`scaledToFill` + 固定高 + `clipped` 把头切了（11-12） | `Features/Conversations/CharacterBoardPage.swift` 改 `scaledToFit` + 模糊副本垫底；底部墨绿渐变改黑 | `board.png` 人物完整不切头 |
| 语音要能选音色、试听一句、调语速（11-12） | `Support/SpeechService.swift`、`Features/Settings/BehaviorPage.swift`（「当前音色」名 + 试听 + 语速三档 `settings.voiceRate`）；当晚又改成按角色，见下一节 | 设置里能试听；语速三档真的改到 `defaultRate` |

## 11-12 第三批（19:55）：群聊功能缺失 / 键盘顶飞 / 语音按角色

| 需求（她的说法） | 落点 | 验收方式 |
|---|---|---|
| 群聊根本没有「新建群」「加人/移人」的入口——原来群只是角色编辑器里一个开关 + 一串手打的名字（11-12） | `Features/Conversations/GroupEditorView.swift`、`GroupMembersPage.swift`；`ConversationListView` 加号改 `GlassMenuButton`（新建角色 / 新建群聊） | 会话列表加号能建群；群详情能改群名、移出/加进成员 |
| 点聊天框后输入框消失、键盘弹起标题和返回键被顶出屏幕（11-12 报，当天的 `KeyboardInset` 方案 11-13 被证明是错的） | `Support/KeyboardInset.swift`、`Shell/PhoneShellView.swift` | `chatKeyboard.png`（假键盘高度 336）标题和返回键都在屏内——当天没验成，见 11-13 |
| 语音应该挂到每个角色上（各人不同嗓子），不是全局一项（11-12） | `Data/Persistence/Models.swift` 的 `Companion.voiceID/voiceRate`、`Support/SpeechService.swift`、`Features/Conversations/CharacterVoicePage.swift` | 角色详情「TA 的声音」能给每个角色配不同音色；群里按 `speaker` 换嗓子 |

## 11-13 第五批真机反馈

| 需求（她的说法） | 落点 | 验收方式 |
|---|---|---|
| 键盘弹起标题飞出屏幕、点聊天框输入框消失，是同一个根因：系统只给 215 的底部安全区和键盘 335 差 120pt，顶部安全区还从 62 掉成 0（11-13） | `Shell/PhoneShellView.swift` 的 `appLayerBox`：键盘在时钉死高度 `UIScreen.height − topSafeArea − keyboardHeight`，再按实测顶边 `offset` 挪回状态栏下沿 | `chatKeyboard` 读数 `y62 h477 sTop62 sBot335`，标题完整、输入条贴键盘 |
| 新建身份一碰输入框就退出（不是闪退，是弹窗被拆）：`if keyboardUp { GeometryReader { app } } else { app }` 换掉视图结构，整棵子树重建（11-13） | `Shell/PhoneShellView.swift` 的 `appLayerBox` 改 `GeometryReader` 常驻、键盘只改数值 | 新建身份时点输入框，弹窗不消失、不弹回列表 |
| 身份要能切，且记忆按人分开（她提了两遍）（11-13） | `Support/IdentityScope.swift`（`shell.activeIdentity`）、`Data/Persistence/Models.swift` 的 `StoredMessage.personaUID`、`Features/Conversations/IdentitySwitchSheet.swift` | 我的 → 切换身份；切完聊天记录、记忆、滑动摘要、好感度各一套 |
| 要有应用商店，App 能卸也能装回来（11-13） | `Features/Store/AppStorePage.swift`、`Shell/HomeLayout.swift` 的 `install/remove/restoreStandard`、`PhoneShellView.deskRevision` | 卸掉再装回来，主屏立刻重读布局、图标回到原位 |
| 桌面拖拽与误删：图标拖出两行被切半截、第一排减号被裁、删图标不确认、编辑态退不出（11-13） | `Shell/HomeBoard.swift`（`BoardWindow`、`slotIndex(at:)` 取最近一格）、减号改 `confirmationDialog` | `homeEdit.png` 减号是整圆；删图标先问「只是拿走图标，数据不动」 |

## 11-13 第六批：底栏 / 减号 / 身份状态

| 需求（她的说法） | 落点 | 验收方式 |
|---|---|---|
| 底栏固定四个是硬约束，应用商店不许占第五格——商店改桌面第一屏第 8 格并标成不可卸，它是唯一的恢复入口（11-13） | `Shell/AppCatalog.swift`（`isPinned` / `pinnedIDs`、`home` 末尾）、`Shell/HomeLayout.swift` 的 `pruned()` | `home.png` 底栏 4 格 + 桌面第 8 格是应用商店 |
| 减号被左边裁（她给的真机截图为证）——第五批只修了上下裁切，横向仍裁到板子边缘（11-13） | `Shell/HomeBoard.swift` 的 `BoardWindow(horizontalInset:)`，编辑态左右各放宽 18pt | `homeEdit.png` 首列两个减号是整圆 |
| 认识天数不对——`Companion.createdAt` 是建库时间，跟谁在聊无关（11-13） | `Support/IdentityScope.swift:82` 新增 `Companion.knownSince`；四个消费点 `CharacterHomePage.swift`、`MemoryLibraryPage.swift`、`PromptBuilder.swift`、`ChatViewModel+World.swift` | 新角色的「认识 X 天」从第一次说话算，不是装 App 那天 |
| 切身份后状态要归零（世界状态按身份分文件，不是逐字段打标签）（11-13） | `Domain/State/WorldStore.swift:13` 的 `WorldStateFile.url(for:)`、`identity-states/<世界>/<身份>/world-state.json`、`DataBackup+Files.swift:19` | `statePanelIdentity.png` / `coupleIdentity.png` 对照：默认身份好感 62 / 第二身份 30；火花 41 天 / 全 0 |

## 11-13 第七批：点不进去 / 群聊身份 / 提示词口径

| 需求（她的说法） | 落点 | 验收方式 |
|---|---|---|
| 「一点图标就进编辑态，之后怎么点都进不去」——长按 0.28s 和板子 0.3s 阈值太低，编辑态里 `guard !editing` 直接 return，点空白退出又被图标层吃掉（11-13） | `Shell/HomeTapPolicy.swift`（长按 0.5s、拖动起点 8pt、长按松手 0.45s 闸门）、`HomeScreenView.openApp()` 打开时清编辑态 | 编辑态里点图标会打开并退出编辑；从 App 回来主屏不再抖 |
| 群聊要能把我别的人设拉进来，且不许标成「身份 / 小号 / 用户」（11-13） | `Features/Conversations/GroupPeople.swift`、`GroupEditorView.swift`、`GroupMembersPage.swift`、`GroupAddMemberSheet` | 群名单里人设和角色混排，只给名字、简介、设定卡、头像；当前身份不在候选里 |
| 提示词里不许再声明「这部手机里还有别人用别的身份」——隔离在数据层做，写一句等于告诉模型那边还有一个人（11-13） | `Domain/Roleplay/PromptBuilder.swift` | 单聊和群聊提示词里都没有「多个身份」那段，只留 `【对方是谁】` 和 `【这是群聊】` |
| 「动态」点不到——`AppCatalog` 里没有任何图标指向 `MomentsView`，`moments.png` 拍的其实是主屏（11-13 顺手查出的假入口） | `Features/Moments/MomentsView.swift`、`Shell/AppCatalog.swift` 的 `optional`（默认不占桌面、商店可装） | `moments.png` 是真正的动态页；默认桌面仍是 8 格 |

## 与现有台账的冲突

| 条目 | FEEDBACK.md 的说法 | 日记的说法与判断 |
|---|---|---|
| 健康页与「照片动态」 | §2 待做「照片动态是世界的帖子流卡片进了健康页……健康页删掉照片动态」；§5 又列「健康页照片动态删掉 · 上轮就该删的卡片」（11-07） | 11-08 日记：「P-06（已确认健康页没有照片动态，台账过时）」，同日第四轮把健康整页取消、并进「TA 的手机」。台账把一张 FeedCard 写成了「健康页的照片动态」，实际没有这张卡 |
| 音乐悬浮球 / 悬浮歌词 | §5「没做、排下一批」，§7「她点名『听歌那些应该都没做』」（11-07 晚） | 11-08 日记 P-09 悬浮球 + P-10 整页歌词当天就做完；11-12 她又列了黑胶、底部条黑砖、名字不跟重命名、悬浮球不能拖四条。台账停在「没做」，实际是「做了但不达标」 |
| 桌面顶部间距 | §5 已修「桌面顶行图标离状态栏太近 10→24」（11-07 晚） | 11-08 她又说「组件离灵动岛太近」，这次改的是主屏组件 14→26；11-12 再出「主屏音乐组件是黑的」。台账只覆盖图标，组件这块没查过 |
| 液态玻璃的适用范围 | §1「我的」页栏、§2 Dock、§5 信息底栏、§7 玻璃气泡，四处都记「已落实」（11-07） | 11-12 日记：「这台机器上不要用 glassSurface 做浅色面」——`glassEffect` 认外壳配色，外壳锁 dark 就把音乐组件整块渲染成黑的，改回 `frostedBar`。四处本身没错，但「玻璃」不能当通用解，这条要进硬规矩 |
| 图标拖拽 / 建文件夹 / 分页 | §2「大工程」待做，§5「排下一批」（11-07） | 11-10 日记 S-14/S-15 做完；11-12 她报「长按进不了编辑态、拖不动」；11-13 又报「拖出两行被切半截、减号被裁、点图标就进编辑态」。功能做了，11-12 到 11-13 之间坏了三轮 |
| 深色模式复查 | §4「Dock 已修，其他页面没逐一查。下一轮 CI 截图把 homeNight / chatNight 过一遍」（11-07） | 11-08 ～ 11-13 六个日记文件里，homeNight / chatNight 一次都没再出现；11-12 反而发现深色外壳把浅色面渲染成黑。承诺的「下一轮」跨了六天没兑现 |
| 发真照片 | §4「只做了模拟图片；真相册发送没做，她没再要」（11-07） | 11-08 日记 C-16 直接标「发真照片作废 ⛔」。不是矛盾，是口径收紧——「她没再要」留着像还能再问，应改成「已作废」 |
| 聊天输入栏「默认收起」 | §1 硬规矩「页面不要看上去就是等待输入的状态」记「已落实」（11-07） | 11-13 日记：「同一个原因也解释了『点聊天框输入框消失』」，真因是键盘安全区少 120pt、顶部安全区掉成 0。收起逻辑没坏，是键盘布局把输入条压到键盘后面——合并时别当成回归又重写一遍 |

