# 影响面索引

> 这份表存在的唯一原因：以前每次只改"她指的那一处"，加完功能才发现别的页面歪了。
> 智能体没有"架构意识"这种品质，只有可查的表。改之前查表，比改完道歉便宜。

## 0. 三十秒用法

改任何东西之前，依次回答三个问题，答不全就先别动手：

1. **入口在哪** → §1，找到这次改动落在哪个桌面 App / 哪个页面。
2. **碰了哪个共享面** → §2，看这个共享面被多少文件引用；数字越大，越要先跑截图态。
3. **走清单** → §3，三类改动各有一份必须做的步骤。

数字来自 `python scripts/impact_map.py`（扫 Features/ 与 Shell/ 的引用关系）。改完大改之后重跑一次，把 §2 的数字更新掉。

## 1. 入口 → 页面 → 直接牵动

| 桌面/底栏入口 | 目的地 | 主文件（行数） | 直接依赖的共享面 |
|---|---|---|---|
| 信息（底栏） | `.chat` | `Features/Chat/ChatView.swift`（598）、`ChatViewModel.swift`（438）、`+Memory`、`+World` | Theme, Companion, WorldStore, UserProfile, IdentityScope, PromptBuilder, SettingsStore, PlayerService, StoredMessage |
| 西瓜皮（底栏） | `.scene(.feed)` | `FeedScene.swift`（371）+ `Feed*` 共 13 个文件 | Theme, AppSurface, Companion, WorldStore, UserProfile, IdentityScope, SettingsStore, StoredMessage |
| TA 的手机（底栏） | `.scene(.phonePeek)` | `CharacterPhoneScene.swift`（418）+ `Peek/` 4 个页面 | Theme, AppSurface, Companion, WorldStore, UserProfile, SettingsStore |
| 设置（底栏） | `.settings` | `SettingsView.swift`（233）+ `Settings/` 18 个页面 | Theme, GroupedSection, SettingsStore, WorldStore(数据页) |
| 音乐 | `.scene(.music)` | `MusicScene.swift`（396） | Theme, GroupedSection, WorldStore, PlayerService（+ 播放条、控制中心、锁屏） |
| 日历 | `.scene(.calendar)` | `CalendarScene.swift`（382）+ `ScheduleBlock/Editor`、`WeekStrip` | Theme, Companion, WorldStore |
| 备忘录 | `.scene(.notes)` | `NotesScene.swift`（378） | Theme, AppSurface |
| 信件 | `.scene(.letters)` | `LetterScene.swift`（334） | Theme, WorldStore, SettingsStore, `LetterPrompt`（信件自己的提示词） |
| 情侣空间 | `.scene(.couple)` | `CoupleScene.swift`（251） | Theme, Companion, WorldStore |
| 文游 | `.scene(.storyGame)` | `StoryGameScene`（349）、`StoryGameViewModel`（361）、`StoryReadPage`（439）、`StoryGameModels` | Companion, UserProfile, SettingsStore, WorldStore |
| 阅读 | `.scene(.reading)` | `ReadingScene`（202）、`ReaderPage`（387）、`ReaderSettings`、`BookNotesPage`、`BookPaginator`、`PageTextView` | Theme, AppSurface, GroupedSection |
| 应用商店（固定格） | `.appStore` | `Features/Store/AppStorePage.swift`（213） | AppCatalog, HomeLayout |
| 动态（商店可装） | `.moments` | `MomentsView.swift`（202） | Companion, **PromptBuilder**（动态文案也走角色口径）, SettingsStore |

外壳另外两块不在 App 里，但改动同样影响全部页面：`Shell/PhoneShellView.swift`（584，状态栏/Dock/键盘态）、`Shell/HomeBoard.swift`（511，桌面布局）。

## 2. 反向索引：改这个会波及谁

| 共享面 | 引用文件数 | 波及面与注意 |
|---|---|---|
| Theme | 91 | 颜色、字体、圆角。改一处等于改半个 App，改完必须跑截图态 |
| Metrics | 90 | 间距、尺寸、图标格。和 Theme 一样是全局的 |
| AppSurface | 39 | 页面外壳（毛玻璃底、导航条）。改它会动所有二级页面 |
| Companion | 47 | 角色模型。加字段 → 会话列表/详情/编辑/群聊/文游/动态/通话全部要过一眼 |
| WorldStore / WorldState | 39 | 世界数据。加字段 → 迁移 + 备份版本 + 所有场景页 |
| SettingsStore | 37 | 设置项。加字段 → 默认值 + 所有读取方 + `DataBackup` 的版本号 |
| GroupedSection | 45 | 设置/详情页的行样式，统一改一次全变 |
| UserProfile | 20 | 我的身份。牵动群聊身份、动态作者、Peek、人设页、备份 |
| StoredMessage | 14 | 消息模型。牵动聊天、转发到动态、Peek 聊天页、备份 |
| IdentityScope | 9 | 以谁的身份说话。牵动群聊、动态、Peek、人设 |
| AppCatalog | 8 | 桌面清单。加图标必须同时进 `home`/`optional`，否则商店装不回来、截图退回主屏 |
| ChatViewModel | 7 | 会话状态机。改它会动聊天、通话浮层、Peek |
| PlayerService | 6 | 播放器。动它要看音乐页、聊天里的播放条、控制中心、锁屏 |
| HomeLayout | 4 | 桌面布局与文件夹。动它要看 HomeBoard、HomeFolderViews、商店、截图 |
| PreviewSeed | 4 | 截图/预览数据。数据模型一变它就得跟着变，否则截图是假图或退回主屏 |
| PromptBuilder | 3 | 角色口径。改它要同步 RoleplayPreset（分模式）、CharacterClock（时间块）、`check_standards.py` 的闸 |
| DataBackup | 1 | 备份格式的唯一出口。任何持久化字段变更都必须走这里加版本 |

## 3. 三类改动的清单

**A. 加一个 App 或页面**

1. `AppCatalog`：进 `home`（默认在桌面）还是 `optional`（商店可装）。
2. `HomeLayout`：老布局要能补上这一格，不能只在全新安装时出现。
3. `HomeBoard` / `HomeFolderViews`：图标渲染、长按编辑、拖拽落点。
4. `AppStorePage`：可装卸的要出现在商店里；固定格不加减号。
5. `PreviewSeed`：加一个截图态，否则 `_shots` 里没有它。
6. `docs/DESIGN.md` 的页面清单表：加一行，写清"这个页面解决什么"。

**B. 加一个设置项**

1. `SettingsView` 的分组表里挂上去（或复用已有 `GroupedSection`）。
2. `SettingsStore` 加字段 + 默认值 + 迁移（老用户的档里没有这个键）。
3. `DataBackup`：`currentVersion` +1，写明这一版加了什么。
4. 所有读取方过一眼（`impact_map.py` 里 `SettingsStore` 那 37 个文件）。
5. 如果影响布局或外观 → 跑截图态。

**C. 改聊天口径 / 提示词**

1. `PromptBuilder` 的【输出要求】（全模式生效）。
2. `RoleplayPreset.promptRules`（daily / story / live / letter 各自的语气）。
3. `CharacterClock`（时间块：只写事实，不写"该怎么反应"）。
4. `check_standards.py` 的 `CHAT_TONE_MARKERS`（闸），并同步 `docs/EXPERIENCE.md`。

## 4. 不变量（任何改动都不许破）

1. 聊天不追问、不指责、不拿间隔当话头（`docs/EXPERIENCE.md` §3）。
2. Dock 固定四格；应用商店不可卸——它是误删后的唯一恢复入口。
3. 桌面图标与 Dock 不重复出现同一个 App。
4. 键盘态只改数值，不切视图结构（`if keyboard { A } else { B }` 会拆掉弹窗、清空 `@State`）。
5. 持久化字段变更必须进 `DataBackup` 并升版本，旧档要能读。
6. 任何 App 都必须存在于 `AppCatalog.all`，否则截图态和商店都会走不通。

## 5. 维护

- 数字过时了就跑 `python scripts/impact_map.py --top 20`，把 §2 的表更新掉。
- 新增共享面（新的全局 store、新的基础组件）要补进 `scripts/impact_map.py` 的 `SHARED`，否则这份表看不见它。
- 改了 §3 的步骤就改这里，别只在聊天里说一遍。
