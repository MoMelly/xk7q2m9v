# 装机：从零到手机上的图标

P0 的目标只有一个：证明这条链路走得通。
走完这篇，你手机上会多一个叫「小手机」的图标，点开能和你配置的模型聊一句。

---

## 需要准备的四样

| 东西 | 说明 |
|---|---|
| iPhone | iOS 26 或更新 |
| Windows 电脑 + 数据线 | 一次装机用，之后不用 |
| Apple ID | 用那个港区号，别用主号 |
| GitHub 账号 | 借它的 Mac 编译 |

---

## 第一步：把代码放上 GitHub

这台电脑上没有 Xcode，iOS 的包编不出来。所以借 GitHub 免费的 macOS 机器来编。

1. 打开 <https://github.com/new>
2. 仓库名填 `miniphone`
3. **选 Public**（私有仓库每月只有 200 分钟 macOS 编译额度，公有无限制）
4. 不要勾 "Add a README"
5. 点 Create repository

然后在 Windows 的终端里，进到这个文件夹：

```
cd C:\Users\melly\WorkBuddy\2026-11-04-17-35-56\miniphone
```

跑这两行（把 `你的用户名` 换成你的 GitHub 用户名）：

```
git remote add origin https://github.com/你的用户名/miniphone.git
git push -u origin main
```

第一次会弹窗让你登录 GitHub，点授权就行。

---

## 第二步：等云端编译

1. 打开 `https://github.com/你的用户名/miniphone/actions`
2. 看到一条 **Build unsigned IPA** 正在跑，等 5–8 分钟
3. 变成绿色对勾后点进去，页面最下面有个 **Artifacts**
4. 下载 `MiniPhone-unsigned-ipa`，解压得到 `MiniPhone-unsigned.ipa`

**如果变成红色叉**：点进去，展开报错的那一步，把最后 30 行发我。这一步大概率会失败一次，正常。

---

## 第三步：Windows 上装 SideStore

SideStore 是那个负责给 App 签名的壳子，装一次能用很久。

1. 装 iTunes。微软商店搜 iTunes，或者苹果官网下载。**必须装**，iLoader 要用它连手机。
2. 下载 iLoader：<https://github.com/nab138/iloader/releases>
3. 数据线连手机，手机上点「信任此电脑」
4. 打开 iLoader，登录你的港区 Apple ID
5. 点 **Install SideStore**

手机上接下来三步：

6. 设置 → 隐私与安全性 → **开发者模式** → 打开 → 重启手机 → 重启后再确认一次
7. 设置 → 通用 → VPN 与设备管理 → 点你的 Apple ID → **信任**
8. App Store 搜 **LocalDevVPN**（旧名 StosVPN），装上，点一下连接 → **让它一直开着**

> 顺手关一个坑：设置 → Wi-Fi → 点当前网络右边的 ⓘ → **私有 Wi-Fi 地址关掉**。
> 这个开关会不停换设备地址，是登录和续签失败最常见的原因。

---

## 第四步：把小手机装进去

1. 打开 SideStore → **My Apps** → 右上角 **+**
2. 选刚才那个 `MiniPhone-unsigned.ipa`
3. 等它签名、安装
4. 装完同样去 设置 → VPN 与设备管理 → 信任一次

图标现在是空白的，正常。P1 才做图标。

---

## 第五步：填 Key，发第一句

1. 打开小手机，点右上角齿轮
2. **接口**：`https://api.siliconflow.cn/v1`
3. **模型名**：填你硅基流动账号里能用的那个，去控制台复制准确的 ID
4. **密钥**：`sk-...`
5. 点完成，回主界面发一句

看到文字一个一个蹦出来，P0 就成了。

---

## 第六步：让它自己续签

免费签名只有 7 天。这一步配好了，之后基本不用管。

1. 打开「快捷指令」App → 新建
2. 搜索 **SideStore** → 添加动作「刷新全部应用」
3. 在它前面再加一个「设定 VPN」→ 选 LocalDevVPN
4. 存下来，命名「续签」
5. 切到「自动化」→ 新建 → 时间 → 每周一、周四 08:00 → 执行「续签」→ **关掉「运行前询问」**

前提只有两条：手机连着 Wi-Fi、LocalDevVPN 开着。

---

## 出问题对照表

| 现象 | 原因 | 怎么办 |
|---|---|---|
| Actions 红色叉 | 代码编译不过 | 把报错最后 30 行发我 |
| 装的时候提示 1414 | Wi-Fi 或 LocalDevVPN 没开 | 两个都开着重试 |
| 打开提示「不受信任的开发者」 | 没信任 | 设置 → VPN 与设备管理 → 信任 |
| 发消息报 HTTP 401 | Key 不对 | 重新填一次 |
| 发消息报 HTTP 400 | 模型名不对 | 去控制台复制准确 ID |
| App 打不开，没提示 | 签名过期了 | 打开 SideStore 点 Refresh All |
| 提示装不下更多 App | 免费账号限 3 个 | SideStore 自己算一个，删掉别的 |

---

## 已知的三件事

- **图标是白的**：P1 做图标。
- **最多 3 个 App**，SideStore 占一个。
- **7 天要续签**：配了第六步就基本无感，偶尔失败点一下 Refresh All。
