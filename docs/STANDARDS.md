# 工程规范

这份规范的每一条都来自已经发生的问题，不是先写一套理想再套上去。
能机器检查的，`scripts/check_standards.py` 会查，构建时自动跑；查不了的靠自觉，但下面写了原因。

违反规范的代码会被构建挡下来，所以不看这份文档也躲不过去。文档的作用是在动手前就知道该怎么写。

---

## 1. 分层与依赖方向

```
Domain       实体、规则、提示词拼装、世界状态。只依赖 Foundation / Observation
Data         网络、持久化、导入导出。可以依赖 Domain
DesignSystem 颜色、间距、可复用组件。可以依赖 Domain
Shell        假手机外壳（锁屏、桌面、状态栏）
Features     真正的功能页（聊天、会话、动态、设置）
Support      日志、Keychain、通知、时间格式化等基础设施
App          组装入口
```

规则：

| 规则 | 原因 |
|---|---|
| `Domain/` 下只允许 `import Foundation` / `import Observation` | 一旦 Domain 引了 SwiftUI，业务规则就绑死在界面框架上，改界面等于改规则 |
| `Features/` 不允许直接拼提示词，一律走 `PromptBuilder` | 提示词散到各页面后，想统一调语气只能全局搜索，必漏 |
| `Features/` 不允许直接建 `DateFormatter`，一律走 `TimeFormat` | 之前四处各建一份，其中两处每调用一次 new 一个，列表滚动时白花开销 |
| 视图不允许直接 new `URLSession` / 自己拼 HTTP 请求 | 只在 `Data/Remote` 里做，否则超时、错误映射会出现第 N 套实现 |

---

## 2. 复用，不重造

下面这些能力已经有唯一入口，新页面直接用：

| 要做什么 | 用哪个 | 别再写 |
|---|---|---|
| 玻璃质感背景 | `.glassSurface(cornerRadius:)` | `.background(shape.fill(.ultraThinMaterial))` |
| 顶部圆形图标按钮 | `GlassIconButton(symbol:isBusy:action:)` | 手写 34×34 + glassSurface(17) |
| 页面标题 + 副标题 | `ScreenTitle(title:detail:)` | 自己拼 VStack + serif(22) |
| 圆形头像 | `AvatarCircle(initial:tint:size:)` / `AvatarBubble(character:size:)` | 自己画 Circle + 首字 |
| 时间字符串 | `TimeFormat.*` 或 `CharacterClock.*` | 新建 `DateFormatter`、手写 `"HH:mm"` |
| 时间自动刷新 | `TimelineView(.everyMinute)` | `Timer.publish` + `onReceive` + `@State now` |
| 主题色 | `Theme.*` | 视图里写 `Color(red:green:blue:)` 表示主题色 |
| 尺寸、圆角 | `PhoneMetrics.*` | 各处写魔法数字 |
| 角色头像配色 | `AvatarTint` | 另造一套色板 |
| 壁纸 | `WallpaperTheme` + `WallpaperView` | 新建渐变枚举 |
| 系统提示词 | `PromptBuilder` | 视图里写 `"""你在扮演…"""` |
| 浅色页面卡片 | `.whiteCard(cornerRadius:)` | 各自写一遍白底 + 白描边 + 阴影 |
| 跨会话状态 | `WorldStore.shared` | 页面里另存一份心情 / 日程 / 记忆 |
| 场景类只读页 | `ScenePage(kind:)` | 每个假 App 单写一套列表布局 |
| 歌单文件 | `MusicLibrary` | 视图里直接翻 Bundle / Documents |
| 视频壁纸 | `VideoWallpaperStore` + `WallpaperBackdrop` | 锁屏和桌面各接一份 AVPlayer |
| 回复状态块 | `ReplyEnvelope.parse(_:)` | 视图里手写字符串切分 |
| 真机数据 | `DeviceSnapshot.lines(allowPhoneLookups:)` | 页面里直接读 `UIDevice` |
| 取回 CI 产物 | `scripts/fetch_artifacts.py` | 手写 `git show ... > xxx.ipa`；PowerShell 会把二进制写成 UTF-16 |

`Color(red:...)` 允许出现在三处：`Theme`、`AvatarTint`、`AppCatalog`（图标底色本身就是要一堆具体颜色，抽成主题色反而更难读）。

---

## 3. 数据层

- **新增字段必须带默认值。** SwiftData 的轻量迁移能处理「加一个有默认值的属性」，处理不了「改类型、去默认值」。加字段前先想清楚默认值是什么。
- **改结构之前先加 `VersionedSchema`。** 现在只有 4 个模型、数据结构还在动，所以用轻量迁移；等到真正重命名字段或拆表时，必须在 `AppStore` 里落版本化 schema，不能直接改属性。
- **关系上显式写删除规则。** `@Relationship(deleteRule: .cascade, inverse:)`，别靠默认值。
- **写操作后必须 `save`，失败必须记日志。** 直接 `try?` 吞掉会让「保存失败」表现成「数据莫名丢了」。
- **查询在视图用 `@Query`，在 Service 用 `FetchDescriptor`。** 不要在视图里手搓 predicate 字符串。
- **跨会话状态不放 SwiftData。** 人物记忆、心声、日程、心情、使用记录走 `WorldStore` 的那一份 JSON；加字段不用迁移，备份直接拷文件。会话级摘要仍留在 `Companion.memorySummary`，两者职责不同：一个是原文压缩，一个是跨会话索引。
- **备份是一个文件夹，不是一个 json。** `data.json` 之外还要带 `wallpaper.mov` 和 `world-state.json`；二进制不进 JSON，避免 base64 把体积和解码内存一起放大。
- **恢复后要刷新两套存储。** SwiftData 由 `DataBackup.restore` 写入，世界状态文件写回后必须调 `WorldStore.shared.reload()`，否则页面还显示旧状态。

---

## 4. 并发与状态

- 视图模型统一 `@MainActor @Observable final class`，不要 `ObservableObject`（项目里只有一种写法）。
- **视图不发起网络请求。** 请求在 ViewModel 或 Data 层，视图只读结果。
- 长生命周期 `Task` 捕获 `self` 用 `weak`，避免 ViewModel 被任务吊住。
- 流式输出期间不允许重入：`isStreaming` 为真时直接返回。
- **一次回复产生几个后台调用，由 `GenerationPlan` 决定，不散在各处判断。** 按次计费时心情、心声、记忆增量、动态文案都并进正文后的状态块，不再单独发压缩调用；按量计费时才走独立压缩。
- **状态块解析失败要降级成普通回复。** 模型偶尔写坏 JSON，不能让「解析失败」表现成「这条消息丢了」。

---

## 5. 视图初始化

- **`@State` 属性用默认值或内联初始化表达式，不要为了读启动参数写自定义 `init`。** 自定义 init 里给 `_state = State(initialValue:)` 这种写法最容易写出编译错误，而且错误信息指向不清。要读启动参数就写成 `private static var` 计算属性，让 `@State` 的默认值去引用它。
- 需要 Apple 私有/半公开行为的调试开关，一律用启动参数 `-key value`（走 `UserDefaults` 的 NSArgumentDomain），不要编译期 `#if DEBUG` 分支污染正式路径。

---

## 6. 构建系统

| 规则 | 说明 |
|---|---|
| 工程文件只由 `project.yml` 生成 | `.xcodeproj` 进 `.gitignore`，永远不手改、不提交。手改必炸，且 Windows 上根本改不了 |
| 每次推 `main` 必须产出 ipa 和模拟器截图 | 截图是为了在没有真机的情况下看界面，不要靠「我觉得应该长这样」 |
| 截图必须无遮挡 | 系统权限框画在 App 之上，SwiftUI 关不掉；启动阶段申请权限会让 5 张截图全部作废。见第 8 节 |
| 产物写回 `artifacts` 分支 | 构建日志、ipa、`shots/*.png`、`STATUS.txt`。这条通道不依赖任何网页操作 |
| `main` 永远可编译 | 编译不过就在分支上修，不要把 main 当草稿本 |
| 密钥永不进仓库 | API Key 只存 Keychain；提交前脚本会扫 `sk-` 前缀的字符串 |
| 版本号 | `MARKETING_VERSION` 手动改（0.1.0 → 0.2.0），`CURRENT_PROJECT_VERSION` 用构建号 |
| 文件编码与换行 | 全部 UTF-8 + LF。Windows 上 CRLF 进了 shell 脚本会变成 `\r` 报错（已经踩过） |

### 提交约定

一次提交只做一件事。前缀固定：

```
feat:     新功能
fix:      修 bug
refactor: 不改行为的重构
ci:       流水线、构建配置
docs:     文档
chore:    杂项（忽略规则、格式化）
```

### 单文件规模

单文件超过 400 行要拆分，超过 600 行构建报警。不是硬性美学，是因为超过这个量级后
改一处要读十分钟才能确认没影响别处。目前最大的是聊天页，拆分点在「气泡」「输入条」「头部」。

---

## 7. 命名与语言

- 类型、方法、变量用英文；注释和界面文案用中文。
- **注释只写机制、坑和原因，不写情绪。** 「这里不能省，因为 Xcode 会……」

- 模型类名避开 Swift 标准库已占用的名字。已经踩过：`Character`（与 `Swift.Character` 冲突）→ 改名 `Companion`。同类风险：`Task`、`Result`、`Error`、`Index`。
- 主键统一叫 `uid`，不叫 `id`。`PersistentModel` 已经提供了 `id`，重名会让 `Identifiable` 解析产生歧义。

---

## 8. 已知的坑（踩过，别再踩）

| 坑 | 现象 | 处理 |
|---|---|---|
| 类名撞标准库 | 编译报一堆看不懂的错 | 换名 |
| `@State` 自定义 init | 编译错误指向不清 | 用静态默认值 |
| Windows CRLF 进脚本 | `bash: $'\r': command not found` | `.gitattributes` 强制 LF |
| 私有仓库 Actions 额度 | macOS 机器按 10 倍折算，2000 分钟额度实际只有 200 分钟 | 单次构建控制在 10 分钟内；模拟器截图与真机打包放在同一个 job，不额外起机器 |
| 免费签名重装即清库 | 聊天记录、API Key 全丢 | 设置页必须能一键导出，且导出要早于任何结构改动 |
| 配对文件随系统升级失效 | iLoader 报 `device does not have pairing file`，实际是记录过期 | 删掉 `C:\ProgramData\Apple\Lockdown` 下旧记录，重新插线信任 |
| 启动即申请通知权限 | 2026-11-05 首轮全绿构建，5 张截图全被「Would Like to Send You Notifications」盖住，界面等于没验收 | 删掉 App 入口的 `.task`；权限绑定到设置开关与第一条回复投递前，后者成功即补发 |
| 深色模式里用 `Form` | 外壳 `.preferredColorScheme(.dark)` 会把 grouped 单元格染黑，叠深色渐变后是一层脏灰框，白色背景也救不回来 | 设置页改自绘 `whiteCard` 分组；`check_standards.py` 拦住 `Features/Settings/` 里的 `Form` |
| `Text` 拼接里调 `lineSpacing` | `lineSpacing` 返回 `some View`，`base + Text(...)` 立刻失效 | 行距移到下游视图，拼接只在 `Text` 之间做 |
| 心情每轮都变 | 模型每回一句就换个状态，角色像没有脾气 | `DayScheduleEngine.shouldUpdateMood` 卡三道：同状态不变、无起因不变、30 分钟冷却内不变 |
| 模拟器截图张冠李戴 | 开机没完成就截图会拍到 Apple logo / 系统主屏；app 没退干净时 `-previewState` 不生效，会拍到上一个状态的界面 | 开机与安装单独放宽超时；每次截图前先 `terminate` 再冷启动；launch 失败直接跳过，不拍假图；`fetch_artifacts.py` 按分支实际清单拉图并先清旧图 |

---

## 9. 构建卡住时怎么排查

云端 CI 出问题时的排查顺序，按「先排除什么」排，别一上来就改 workflow。

### 9.1 先分清「没触发」和「触发了但没机器」

```
gh run list --repo MoMelly/miniphone --limit 5
gh api repos/MoMelly/miniphone/actions/runs/<id>/jobs
```

看 job 的 `runner_name` 字段：

| 现象 | 含义 |
|---|---|
| 没有 run 记录 | workflow 没触发：检查 `on.push.branches`、YAML 能否被解析、Actions 是否被禁用 |
| `status=queued`、`runner_name=null` | 触发了，但**没分到机器**。问题在 GitHub 侧，不在代码 |
| `runner_name` 有值、steps 为空 | 分到机器了但启动失败，通常是镜像或启动脚本问题 |
| steps 停在某一步 | 正常的构建失败，看该步日志 |

### 9.2 「没机器」怎么定位到账户还是镜像

**做对照，不要猜。** 建一个临时公开仓库，只放一个 `ubuntu-latest` 的空壳 job，触发一次：

- 公开仓库的 ubuntu job 都排队 → **账户级限制**，跟 macOS、跟私有仓库、跟本项目代码都无关
- ubuntu 跑了、macOS 排队 → macOS 镜像容量问题，换 `macos-15` 或等
- 都正常 → 本项目 workflow 配置问题

这一步能省掉大量瞎改。2026-11-04 那次就是靠它确认的：公开仓库的 ubuntu 空壳也拿不到 runner，最终判定为账户侧限制，而不是「是不是我 YAML 写坏了」。

### 9.3 几个会误导人的现象

- **`gh run cancel` 对 `queued` 状态的 run 返回 `{}` 但状态不变。** 取消只对 `in_progress` 真正生效，别以为清空队列就能解开堵塞。
- **`gh run list` 有缓存。** 怀疑状态时用 `gh api .../runs/<id>` 查单个，返回的 `updated_at` 才是真的。
- **`Cannot cancel a workflow run that is completed`**：说明那个 run 其实已经结束了，只是列表还没刷新。
- **git 的 `ls-remote` 看不到 `artifacts` 分支更新，不代表构建没跑。** 构建失败时不写产物分支（或写了但步骤没到），要看 Actions 的 run 记录，别只看分支。

### 9.4 权限前提

`gh` 默认令牌可能没有私有仓库读权限，表现为所有 Actions API 返回 **404**（不是 403）。补权限：

```
gh auth refresh -h github.com -s repo -s workflow
```

不补的话，会误判成「仓库不存在」或「构建没跑过」。

---

## 10. 怎么执行

```
python scripts/check_standards.py
```

本地随时可跑；构建时会在生成工程之前跑一次，不通过就直接失败。

脚本能查的是机械规则（分层 import、重复造轮子的特征字符串、启动路径的系统权限申请、设置页的 `Form`、世界状态只有一个实例、状态块标记的落点、文件行数、密钥泄漏、换行符、括号平衡）。
查不出的部分——比如「这个组件该不该抽」——靠第 2 节的表和评审时的一句话：
**这段代码，项目里是不是已经有一份了？**
