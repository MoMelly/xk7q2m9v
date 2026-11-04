# 小手机 · 工程规划 v2

> 单人自用 · iOS 26+ · 零服务器 · 原生 Liquid Glass · 酒馆能力内嵌
> 状态：规划稿 v2，已按你的 7 条修正重排

---

## 0. v2 相对 v1 的改动

| 项 | v1 | v2 |
|---|---|---|
| 定位 | AI 聊天 + 拟真外壳 | **带界面的酒馆**（预设/世界书/变量/角色卡） |
| 主动消息 | 本地定时推送 | **砍掉**。只在"你发了消息后切走、回复到达"时通知 |
| 语音 | 砍掉 | **离线 TTS（Kokoro）+ 模拟通话** |
| 工程文件 | 待你确认 | 已定：XcodeGen |
| 数据库 | 待你确认 | 已定：GRDB |

---

## 1. 竞品与基线

### 1.1 酒馆（SillyTavern）——不是竞品，是功能基线

你嫌它麻烦，但麻烦的不是功能，是**装配**。它的能力拆开看：

| 酒馆的东西 | 本质 | 我们的处理 |
|---|---|---|
| 角色卡 V2（PNG 内嵌 JSON） | 人设包，字段 `description` / `personality` / `scenario` / `first_mes` / `mes_example` | **直接支持导入**。你手上已有的卡不用重做 |
| 预设 Preset | 主提示词 + 采样参数 + 输出模板 | 内置成"玩法包"，只暴露 3 个开关，不给你 40 个滑条 |
| 世界书 Lorebook | 关键词触发的设定条目，命中才注入 | 支持导入 + 关键词触发，界面叫"设定集" |
| 变量 + 状态栏 | 正则抓回复里的数值，渲染成面板 | 做进"角色状态"面板（好感度、地点、时间、情绪） |
| 正则 Regex | 清洗模型输出、替换显示 | 内置常用（去 markdown、去括号旁白）+ 可编辑 |
| 宏 `{{char}}` `{{user}}` | 变量插值 | 支持 |
| 群聊 | 多角色轮流发言 | 支持 |
| 扩展 / STscript | 任意脚本 | **不做**。这是它复杂度的来源 |
| 向量记忆 RAG | 语义检索历史 | 简化成本地关键词 + 摘要，够用 |

**结论：抄它的数据格式和玩法，不抄它的装配方式。** 它能导入的，我们能导入；它要装 Node 开代理填参数的，我们做成一个开关。

### 1.2 中文「小手机」品类

| 产品 | 值得抄 | 不值得抄 |
|---|---|---|
| Shine 拾光 | Galgame 式演出（立绘+BGM 跟剧情）、角色发图发视频 | 邀请码注册、云端存记录、268MB |
| KOKO 小手机 | 证明"自带 API key"成立；账单/提醒这类生活化场景 | 功能铺太散 |
| Tatami | 桌面是第一屏而不是聊天列表 | 绑定官方 API |
| 喵呜小手机 | 锁屏输密码进入的仪式感 | — |
| mydol | **公共场合一键切普通壁纸**（隐藏模式） | 语料硬编码 |

**共性**：全都依赖注册 + 云端 + 订阅。你要的"一个人、本地存、自带 key"是空位。

### 1.3 海外陪伴类 / 影视道具类

- **Kindroid**：主动消息可调频率（我们不做）、长记忆、自拍 → 记忆设计参考它
- **PhoneGuyAi / Phonie**：不接 AI，只做"看起来像真手机"，状态栏电量信号、键盘、打字动画、按机型精确定尺寸 → **拟真度标杆**

---

## 2. 产品定义

一台只有你自己能进的假手机。点亮屏幕看到锁屏，解锁进桌面，图标里有聊天、相册、动态、备忘录。里面的角色按自己的作息生活，按你导入的卡和预设说话。

**核心抽象：玩法包（Playbook）**

酒馆麻烦在"每次都要重新配一套"。我们把它打包成一个可切换的单元：

```
Playbook = 主提示词 + 采样参数 + 正则组 + 变量表 + 界面皮肤 + 绑定的设定集
```

内置几套，一键切换：

| 玩法包 | 是什么 |
|---|---|
| 日常 | 普通微信式聊天，角色按作息回话 |
| 剧情 | 有场景推进，回复带旁白 |
| 直播体 | 角色在开播，界面变成直播间：在线人数、弹幕、礼物 |
| 群聊 | 多角色轮流发言，会互相接话 |
| 信箱 / 日记 | 单向书写体，异步感强 |

以后你自己也能存一套、导出、改。

**明确不做**：账号登录、云同步、实时音频流、多人房间、上架 App Store、Android、任意脚本扩展。

---

## 3. 技术选型

| 层 | 选择 | 理由 |
|---|---|---|
| UI | SwiftUI（iOS 26 起） | 液态玻璃只有原生有 |
| 工程文件 | **XcodeGen**（`project.yml`） | `.pbxproj` 是二进制式 XML，手改必炸、无法 diff。yml 描述工程，CI 生成 |
| 持久化 | **GRDB（SQLite）** | 聊天要分页/搜索/可控迁移。SwiftData 迁移是黑盒，出问题难查 |
| 网络 | URLSession + AsyncThrowingStream | 原生流式，零依赖 |
| 密钥 | Keychain（`whenUnlockedThisDeviceOnly`） | 不进 UserDefaults、不进代码、不进日志 |
| 离线 TTS | **Sherpa-ONNX + Kokoro** | 见 §4 |
| 语音识别 | iOS 原生 Speech（离线包） | 免费、无需联网 |
| 依赖 | SPM：GRDB、sherpa-onnx | 依赖越少，五年后越能跑 |
| CI | GitHub Actions macOS runner | 你没有 Mac，云端代替 |

不引入：SwiftData、Realm、Core Data、任何 UI 组件库、任何网络封装库。

---

## 4. 语音方案（实测数据）

| 方案 | 自然度 | 延迟 | 体积 | 判断 |
|---|---|---|---|---|
| AVSpeechSynthesizer（系统） | 低，机械感明显 | 几乎 0 | 0 | 只作兜底 |
| Piper / VITS（Sherpa-ONNX） | 中等 | ~120ms | 80-150MB | 做"快速模式" |
| **Kokoro-82M（Sherpa-ONNX）** | 好（TTS Arena 2026-01 Elo 1170，高于 OpenAI TTS 的 1158） | ~2.5s/句 | 量化后约 86MB | **主选** |
| 云端 TTS | 最好 | 200-500ms | 0 | 可选，要花钱 |

**怎么解决 Kokoro 的 2.5 秒**：分句流式。回复一到就按句切，第一句生成完立刻播，后面边播边生成。耳朵感知的是"停顿一下然后开口"，不是"等 2.5 秒"。

**必须说清的局限**：离线中文 TTS 的上限就是"清楚、不难听"，做不到真人的情绪起伏和气息。要那种效果只能走云端，按字收费。

**通话模式（模拟）**：不做实时音频流。点通话 → 全屏通话界面（头像/计时/挂断）→ 你说话走系统离线识别 → 文本模型生成 → TTS 念出来，中间插 0.5–1.5 秒随机停顿。观感接近真通话，延迟可控，成本为零。

---

## 5. 架构

```
Features (SwiftUI)      ← View + ViewModel
   ↓
Domain (纯 Swift)       ← Entities / UseCases / Protocols，禁止 import SwiftUI
   ↓
Data                    ← GRDB 实现 / LLM 客户端 / TTS 引擎
   ↓
Support                 ← Keychain / Clock / Notifier / Log
```

CI 检查：`Domain` 里出现 `import SwiftUI` 或 `import GRDB` 直接判失败。跨层只走协议。

### 目录

```
miniphone/
├── docs/                     PLAN.md、DECISIONS.md
├── project.yml               XcodeGen
├── .github/workflows/build.yml
├── MiniPhone/
│   ├── App/                  入口 + 依赖装配（唯一知道所有实现的地方）
│   ├── Domain/
│   │   ├── Entities/         Character / Message / Card / Playbook / Lorebook / ChatState
│   │   ├── UseCases/         SendMessage / ImportCard / AssemblePrompt / Summarize / AdvanceClock
│   │   └── Protocols/
│   ├── Data/
│   │   ├── Database/         GRDB schema + migrations（v1、v2…一版一文件）
│   │   ├── Repositories/
│   │   ├── Remote/           OpenAI 兼容客户端
│   │   └── Voice/            Sherpa-ONNX 封装、Kokoro 声线管理
│   ├── Features/
│   │   ├── LockScreen/ Home/ Chat/ Contacts/
│   │   ├── Album/ Moments/ Notes/ Settings/
│   │   ├── Call/             模拟通话
│   │   └── Live/             直播体皮肤
│   ├── DesignSystem/         Glass 组件、色板、字体、图标
│   └── Support/
└── MiniPhoneTests/
```

垂直切分。禁止 `Views/` `Models/` `Helpers/` 这种大杂烩目录。

---

## 6. 数据模型

| 实体 | 关键字段 |
|---|---|
| CharacterCard | id, name, avatar, description, personality, scenario, firstMes, mesExample, 原始 V2 JSON |
| Character | id, cardId, 覆盖字段（你可以改卡不改源）, 作息表 |
| Conversation | id, characterId, playbookId, lastActivityAt, unreadCount |
| Message | id, conversationId, role, text, virtualSentAt, status, 语音条附件 |
| Playbook | id, name, mainPrompt, 采样参数, regex 组, 变量表, 皮肤 |
| Lorebook | id, entries[{keys, content, constant, depth}] |
| ChatState | conversationId, 变量快照（好感度/地点/情绪/剧情进度） |
| Memory | id, characterId, kind(fact/summary), content, weight |
| Moment | id, characterId, text, image, virtualPostedAt |
| Settings | baseURL, model, 默认 playbook, 语音引擎 |

所有业务时间走 `VirtualClock.now()`，不直接调 `Date()`。

**提示词装配（AssemblePrompt）** 是核心用例，顺序固定：主提示词 → 用户人设 → 角色卡 → 设定集命中条目 → 变量 → 摘要 → 最近 N 条原文 → 作者注释。每一段可单独开关，出问题能定位是哪段注入坏了。

---

## 7. 安全

| 项 | 做法 |
|---|---|
| API Key | Keychain，`whenUnlockedThisDeviceOnly`，不打印不导出 |
| 聊天记录 | 沙盒内，显式 `NSFileProtectionComplete` |
| 网络 | 强制 HTTPS，不放宽 ATS |
| 日志 | `os.Logger` 分级，prompt 全文只在 debug 打 |
| 导出 | 加密 zip（可选密码） |
| 隐藏手势 | 沿 mydol：一键把锁屏换成普通壁纸 |

---

## 8. 分期计划

每期都是能装到手机上跑的产出。

| 期 | 目标 | 验收标准 |
|---|---|---|
| **P0** | 打通链路 | 手机上打开显示一句话，内容是你要的模型生成的。CI 能出 ipa |
| **P1** | 小手机外壳 | 点亮→解锁→翻页→开图标，液态玻璃生效，观感像真机 |
| **P2** | 聊天核心 | 建角色→聊 50 条→杀进程重开→记录不丢；**能一键导出全部数据** |
| **P3** | 酒馆内核 | 导入一张 V2 PNG 卡能直接用；切预设出话风格明显不同；世界书命中生效 |
| **P4** | 记忆与时间 | 连聊 3 天能引用第一天的事；时间调到凌晨，角色说睡了 |
| **P5** | 玩法包 + 相册动态 | 切到直播体，界面变成直播间；角色发动态，桌面出红点 |
| **P6** | 语音 | 点语音条能出声；点通话进入通话界面双向对话 |
| **P7** | 打磨与自维护 | 一键导出全部数据，重装能完整恢复；迁移脚本带自动备份 |

---

## 9. 工程纪律（防屎山）

1. 一个文件一个类型，文件名 = 类型名
2. 垂直切分目录，禁止垃圾桶目录
3. Domain 层禁止 import UI 与数据库框架，CI 强制
4. 对外依赖走协议，实现只在 `App/` 装配
5. 状态唯一来源（`@Observable` Store），View 不改数据
6. 数据库迁移显式编号，禁止删库重装
7. 每次改动附一行验收步骤，没验收不算完成
8. 架构决策进 `DECISIONS.md`，包括"为什么不选 SwiftData"

---

## 10. 签名与续签（你最担心的部分）

### 免费签名到底有多麻烦

| 事项 | 频率 | 需要你动手吗 |
|---|---|---|
| 证书续签 | 每 7 天 | 配好 SideStore 快捷指令自动化后，理论上不用。**失败时要手动点一次 Refresh All** |
| 前置条件 | 一直 | 手机连 Wi-Fi、LocalDevVPN 常开（状态栏会有 VPN 图标） |
| 配对文件失效 | iOS 大版本更新后 | 需要连一次电脑重新生成 |
| 开发者模式 | 重启手机后 | 需要在设置里再确认一次 |
| App 数量 | — | 最多 3 个（含 SideStore 自己），够用 |

**实话说**：自动化能覆盖大部分情况，但它不是零维护。一年里你大概会遇到三五次"App 打不开，得打开 SideStore 点一下"。

### 摆在你面前的两条路

| | 免费自签 | 开发者账号 |
|---|---|---|
| 花钱 | 0 | 约 700 元/年 |
| 续签 | 7 天一次（自动化） | 一年一次 |
| App 上限 | 3 个 | 无 |
| 真推送 | 没有 | 有（我们不需要） |
| 出问题 | 你自己修 | 你自己修 |

**建议：先走免费，P2 之后再评估。** 你不用现在就决定——代码一行都不用改，只是签名方式换一下。等真正用两周，你就知道那点麻烦能不能忍。如果嫌烦，随时换。

### 关于 Apple ID：不需要新手机号

你手上本来就有两个号：系统里登录的主号（存照片、备份、iCloud 那个），和下载国外软件用的港区号。

**用港区号签名，别碰主号。** 理由不是港区号更安全，是风险不对等：主号出事要连带照片和备份，港区号出事只是少一个下载渠道。

SideStore 只在 App 内登录这个账号，不碰你系统里的 iCloud 和 App Store。就算苹果触发风控要求改密码，你的 App Store 也不会掉线，影响的只是 SideStore 自己。

**也不需要新手机号。** 免费签名从来不要求"专用的号"，一个号码通常能验证 2-3 个 Apple ID，超过才被拒。真有一天要换号，你现在这个号码就够用。

代价只有一个：换号重签等于重装，App 沙盒被清空，聊天记录会没。所以 §8 里把"导出"从 P7 提到了 P2 —— 自签 App 的数据随时可能因为重装消失，这不是保险，是常态。

---

## 11. 风险清单

| 风险 | 影响 | 对策 |
|---|---|---|
| 免费签名 7 天 | App 打不开 | SideStore + 快捷指令每周两次 |
| 3 个 App 上限 | 装不下别的 | 只留 App + SideStore |
| 无推送 entitlement | 无真推送 | 我们本来就不要主动消息 |
| 云编译失败排查慢 | 每次等 10 分钟 | P0 先跑通 CI，日志可读 |
| Kokoro 中文不够自然 | 语音不如真人 | 分句流式 + 可换云端 TTS |
| 语音模型撑大包体 | 约 +110MB | 免费签名不限包体 |
| 数据丢失 | 聊天记录没了 | 迁移前自动备份；P2 起就能手动导出，不等到 P7 |
| 酒馆卡格式变种多 | 导入失败 | 先做 V2 规范，异常字段宽容处理 |
