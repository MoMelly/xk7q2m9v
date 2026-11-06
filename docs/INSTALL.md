# 装机：把 ipa 装进手机

云端编译已经跑通。这篇只讲装机，不讲怎么建仓库。

---

## 当前产物

| 项 | 值 |
|---|---|
| 本地 ipa | `_artifacts/MiniPhone-unsigned.ipa`（830,923 字节，2026-11-05 构建） |
| 构建结果 | 全绿：规范检查、Xcode 26.6 编译、未签名 ipa、模拟器编译、逐页截图 |
| 截图 | `_artifacts/latest/shots/`：`fetch_artifacts.py` 按本次构建实际产出的清单拉全，会自动清掉上一轮残留的旧图 |
| 编译日志 | `_artifacts/latest/build.log`（无 error） |

ipa 已经在这台电脑上了，**不用去 GitHub 网页下载 artifact**。要更新版本时从 `artifacts` 分支取，见最后一节。

---

## 最短路径（环境已经配好）

1. 数据线连手机，确认「信任此电脑」还有效
2. 打开手机上的 LocalDevVPN，让它连着
3. SideStore → **My Apps** → 右上角 **+** → 选 `_artifacts/MiniPhone-unsigned.ipa`
4. 装完去 设置 → 通用 → VPN 与设备管理 → 点你的 Apple ID → **信任**
5. 打开小手机，上滑解锁，点桌面「设置」图标，填接口 / 模型 / 密钥，按这个模型实际是按次还是按量计费选一项，点**完成**
6. 回桌面点「信息」→ 右上角 **+** 新建角色，发第一句

第 3 步是覆盖安装还是新装，取决于 SideStore 里是否已有同 bundle id（`com.melly.miniphone`）的条目。**重装会清空 App 沙盒**，聊天记录先用设置页的导出留一份。

---

## 环境只配一次

已经装过 SideStore 的话整节跳过。

| 步骤 | 操作 |
|---|---|
| 1 | 装 iTunes：微软商店或苹果官网下，iLoader 靠它连手机 |
| 2 | 下载 iLoader：<https://github.com/nab138/iloader/releases> |
| 3 | 数据线连手机，点「信任此电脑」 |
| 4 | 打开 iLoader → 登录港区 Apple ID → **Install SideStore** |
| 5 | 手机：设置 → 隐私与安全性 → 开发者模式 → 打开 → 重启 → 再确认一次 |
| 6 | 手机：设置 → 通用 → VPN 与设备管理 → 点 Apple ID → 信任 |
| 7 | App Store 装 **LocalDevVPN**（旧名 StosVPN），点一下连接，之后一直开着 |
| 8 | 设置 → Wi-Fi → 当前网络右边的 ⓘ → 关掉**私有 Wi-Fi 地址** |

第 8 条不是可选项：这个开关会不停换设备地址，是登录和续签失败最常见的原因。

签名用港区号，不碰系统里登录 iCloud 的主号。免费签名不要求专用手机号，也不需要新号。

---

## 填 Key 发第一句

设置页的默认值：

| 项 | 默认 |
|---|---|
| 接口 | `https://api.siliconflow.cn/v1` |
| 模型 | `deepseek-ai/DeepSeek-V4-Flash` |
| 密钥 | 空，显示 `sk-...` 占位 |
| 计费方式 | 按量计费；按模型名分别记住，换模型自动带出上次选的值 |
| 允许角色查手机 | 关 |

按次计费时，心情、心声、记忆增量、动态文案会并进同一轮回复的状态块，不再单独发起后台调用；按量计费时压短上下文，压缩记忆按阈值单独调用。设置项跟着模型走，不用每次换模型重选。

密钥存在 Keychain（`whenUnlockedThisDeviceOnly`），不进备份、不导出、不打日志。模型名以硅基流动控制台里的准确 ID 为准；换别家 OpenAI 兼容服务就改接口地址。

发出去看到文字逐字上屏，链路就是通的。

通知权限不会在启动时弹框。只有两种情况会申请：在设置里打开「回复到了提醒我」，或者切到别的 App 后收到第一条回复。拒绝不影响聊天。

---

## 续签自动化

免费签名 7 天有效。

1. 手机「快捷指令」→ 新建
2. 搜 **SideStore** → 加「刷新全部应用」
3. 前面加「设定 VPN」→ 选 LocalDevVPN
4. 命名「续签」存下来
5. 自动化 → 新建 → 时间 → 每周一、周四 08:00 → 执行「续签」→ 关掉「运行前询问」

前提是手机连 Wi-Fi、LocalDevVPN 开着。自动化偶尔会失败，届时打开 SideStore 点一次 Refresh All。

---

## 出问题对照表

| 现象 | 原因 | 怎么办 |
|---|---|---|
| `device does not have pairing file` | 配对记录过期（常见于 iOS 升级后） | 删 `C:\ProgramData\Apple\Lockdown` 下旧记录，重新插线信任 |
| 安装提示 1414 | Wi-Fi 或 LocalDevVPN 没开 | 两个都开着重试 |
| 「不受信任的开发者」 | 没信任描述文件 | 设置 → VPN 与设备管理 → 信任 |
| HTTP 401 | Key 不对 | 重新填 |
| HTTP 400 | 模型名不对 | 去控制台复制准确 ID |
| App 打不开，没提示 | 签名过期 | SideStore → Refresh All |
| 装不下更多 App | 免费账号限 3 个 | SideStore 占一个，删掉别的 |

---

## 已知事项

- **SpringBoard 上的 App 图标是白的**：工程里没有 AppIcon 资源。假手机内部的 24 个图标是自绘的，不受影响。
- **最多 3 个 App**，SideStore 占一个。
- **7 天续签**，自动化不能覆盖全部情况。
- **重装清沙盒**：导出文件要留在手机之外，或者放到能拿回来的地方。
- **歌单随包**：音频放进仓库 `Assets/Music/`，命名成「歌手 - 标题.mp3」（m4a / aac / wav 也行），下次构建就随 ipa 发布，重装不丢。也可以在桌面「音乐」里多选导入；导入的那部分不进备份。
- **视频壁纸随备份**：设置里导入 mp4 / mov 后锁屏和桌面共用一层，静音循环。导出会生成一个文件夹，里面是 `data.json`、`wallpaper.mov`、`world-state.json`；恢复时选这个文件夹或里面的 `data.json` 都行。
- **角色查手机**：开关默认关。打开后角色只看到电量、机型、时区、可用空间，以及你在这台小手机里各页面的停留时长。真实健康数据和系统屏幕时间拿不到，免费签名没有这两项权限。

---

## 产物与构建通道

`main` 每次推送会触发 `.github/workflows/build.yml`：规范检查 → XcodeGen 生成工程 → `xcodebuild` 出未签名 ipa → 模拟器编译 + 逐页截图 → 把日志、ipa、截图写回 `artifacts` 孤儿分支。截图是验收材料，模拟器开机或截图服务超时不会把 ipa 拖成失败。

取最新产物不用开网页，在项目根目录跑：

```
python scripts/fetch_artifacts.py
```

脚本读 `STATUS.txt` 里的 `run_id` / `sha` / `status` / `built_at`，确认 `status=success` 后才覆盖 `_artifacts/MiniPhone-unsigned.ipa` 和 `_artifacts/latest/`；构建失败时只取回日志，不动装机文件。

**不要用 shell 的 `>` 导出 ipa**：Windows PowerShell 会把二进制重编码成 UTF-16，文件看着变大了但装不上。脚本全程按 bytes 读写。
