# 小手机 · 接手说明（DSH / 符雪枝）

> 2026-11-13 从 WorkBuddy 接过来。这个文件给以后在这里干活的 AI 看，先读完再动手。

## 是什么

iOS 上的「本地模拟手机」：主屏幕 + 各 App（聊天 / 群聊 / 朋友圈 / 音乐 / 设置…），AI 角色住在里面，是写实向的陪伴产品，不是聊天套壳。SwiftUI 单体工程，界面全自定义。

## 在哪

| 用途 | 路径 |
|---|---|
| 源码根 | `C:\Users\melly\WorkBuddy\2026-11-04-17-35-56\miniphone` |
| 代码 | `MiniPhone\{App,DesignSystem,Domain,Data,Features,Shell,Support}` |
| 文档 | `miniphone\docs\`（DESIGN / REQUIREMENTS / ROADMAP / PLAN / STANDARDS / FEEDBACK / INSTALL / **需求总账** / **IMPACT** / EXPERIENCE / design-spec.html） |
| 产物与截图 | `_artifacts\`（unsigned ipa）、`_shots*\` |

Git：`git@github.com:MoMelly/xk7q2m9v.git`，主干 `main`……本机没有 macOS，**编译和截图都在 GitHub Actions 里跑**（`.github/workflows`），改完推送后看 `_ci*.log` / 拉 `_artifacts`、`_shots`。

## 硬规矩

1. **键盘状态只改数值，不许切视图结构**。`if keyboard { A } else { B }` 会拆掉弹窗、清 `@State`——2026-11-13 那次 8 条弯路全栽在这。
2. 改完先跑 `scripts\check_standards.py`，别让 CI 当第一道关。
3. 截图前写 `defaults` 压掉模拟器键盘教学浮层，否则截出来全是提示气泡。
4. 文档先行：新需求先落 REQUIREMENTS/ROADMAP 再写代码；这几份文档是上一任和你（用户）逐轮谈出来的，不是模板。
5. **状态只认一处**：`docs\REQUIREMENTS.md` §3 是编号、状态（✅🟡⬜⛔）、落点的唯一权威；`docs\需求总账.md` 只做「批次 × 来源 × 验收」的对照与缺口清单，不许另存一份状态。改完功能同一次提交里改 §3 那一行，别攒到"以后统一更新"。
6. **加功能先看影响面**：`docs\IMPACT.md` 有入口→页面→依赖的反向索引和三类清单（加 App 六步 / 加设置项五步 / 改聊天口径四步）；动 `Theme` / `Metrics` / `Companion` 这种被引用 90+ 次的东西，先跑 `scripts\impact_map.py` 看谁在引用。

## 当前状态（2026-11-13）

- 最新提交 `dc5678a`（fix: 短按一律打开 App；群聊可加入其它身份；提示词不再暗示多身份；补动态页入口）。
- 第五批真机反馈已处理：身份切换、应用商店、桌面拖拽、减号删除加确认。
- 历史决策在 `.workbuddy\memory\2026-11-04.md ~ 2026-11-13.md`，新的往前写。

## 维护者

符雪枝（DSH），2026-11-13 接手。
