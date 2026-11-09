import Foundation
import Observation

/// 本机设置。
///
/// 接口地址、模型名、采样参数、壁纸走 UserDefaults；密钥只进 Keychain，不落 UserDefaults。
///
/// 刻意不用属性观察器：`@Observable` 宏会把存储属性改造成计算属性，
/// 叠 didSet 容易踩宏展开的坑。改成显式 `persist()`，由界面在改动时调用。
@Observable
final class SettingsStore {
    private enum DefaultsKey {
        static let baseURL = "llm.baseURL"
        static let model = "llm.model"
        static let wallpaper = "shell.wallpaper"
        static let homeWallpaperPhoto = "shell.homeWallpaperPhoto"
        static let lockSeparate = "shell.lockSeparate"
        static let lockWallpaper = "shell.lockWallpaper"
        static let lockWallpaperPhoto = "shell.lockWallpaperPhoto"
        static let chatBackground = "chat.background.mode"
        static let chatBackgroundPhoto = "chat.background.photo"
        static let chatBubble = "chat.bubble.style"
        static let homeTextInk = "shell.homeTextInk"
        static let temperature = "llm.temperature"
        static let maxTokens = "llm.maxTokens"
        static let notifyReplies = "notify.replies"
        static let billingMode = "llm.billingMode"
        static let billingByModel = "llm.billingByModel"
        static let allowPhoneLookups = "privacy.allowPhoneLookups"
        static let allowPrivatePeek = "privacy.allowPrivatePeek"
        static let videoWallpaper = "shell.videoWallpaper"
        static let refreshRules = "refresh.rules"
        static let refreshInterval = "refresh.interval"
        static let passcode = "privacy.passcode"
        static let discreetMode = "shell.discreetMode"
    }

    private static let keychainAccount = "llm.apiKey"

    var baseURL: String = LLMConfig.defaultBaseURL
    var model: String = LLMConfig.defaultModel
    var apiKey: String = ""
    var wallpaperRaw: String = WallpaperTheme.midnight.rawValue
    /// 桌面那张自选照片的文件名。空表示用内置主题。
    var homeWallpaperPhoto: String = ""
    /// 锁屏是不是自己单独设。关着就整套跟桌面走，
    /// 这样只改桌面的人不用维护两份设置。
    var lockSeparate: Bool = false
    var lockWallpaperRaw: String = WallpaperTheme.midnight.rawValue
    var lockWallpaperPhoto: String = ""
    /// 信息 App 的背景模式：主题渐变 / 流动动效 / 相册图片。
    var chatBackgroundRaw: String = ChatBackgroundMode.theme.rawValue
    /// 相册图存进 `Documents/wallpapers`（和桌面壁纸同一个池子），
    /// 这里只记文件名。
    var chatBackgroundPhoto: String = ""
    /// 用户气泡的样式档（薄荷/蓝/粉/紫/玻璃）。
    var chatBubbleRaw: String = ChatBubbleStyle.mint.rawValue
    /// 桌面/锁屏文字颜色档（自动/白/黑）。读取方（图标名、状态栏）直接读
    /// UserDefaults（见 HomeTextInk），这里存档是为了设置页的选中态。
    var homeTextInkRaw: String = HomeTextInk.auto.rawValue
    var temperature: Double = 0.9
    var maxTokens: Int = 900
    /// 回复到了但 App 不在前台时，发一条本地通知（不需要推送证书）。
    var notifyReplies: Bool = true
    /// 当前模型的计费模式。按模型名记住，换模型时自动带出对应值。
    var billingModeRaw: String = BillingMode.perToken.rawValue
    /// 关掉时，电量、机型、使用记录一律不进提示词。默认关。
    var allowPhoneLookups: Bool = false
    /// 允许看「他的手机」里私密那一档。默认关：这一档本来就该先问一句。
    var allowPrivatePeek: Bool = false
    var videoWallpaperEnabled: Bool = false
    /// 锁屏密码，四位数字。空串表示不设。
    ///
    /// 存在 UserDefaults 里，没有走钥匙串：它挡的是「别人拿起这台手机」，
    /// 不是「别人拿到这台手机的文件」。真落到取证那一层，四位数字怎么存都挡不住。
    var passcode: String = ""
    /// 隐藏模式：公共场合一键把壁纸换成普通的、把情侣内容收起来。
    var discreetMode: Bool = false

    /// 每个会自己更新的页面各自的开关与概率。
    var refreshRules: [RefreshRule] = RefreshRule.default
    /// 两个页面共用同一个间隔：攒够这么多轮才开始掷骰子。
    var refreshInterval: Int = 6

    /// model → BillingMode.rawValue。
    private var billingByModel: [String: String] = [:]

    init() {
        let defaults = UserDefaults.standard
        if let storedBaseURL = defaults.string(forKey: DefaultsKey.baseURL) {
            baseURL = storedBaseURL
        }
        if let storedModel = defaults.string(forKey: DefaultsKey.model) {
            model = storedModel
        }
        if let storedWallpaper = defaults.string(forKey: DefaultsKey.wallpaper) {
            wallpaperRaw = storedWallpaper
        }
        homeWallpaperPhoto = defaults.string(forKey: DefaultsKey.homeWallpaperPhoto) ?? ""
        lockSeparate = defaults.bool(forKey: DefaultsKey.lockSeparate)
        if let storedLock = defaults.string(forKey: DefaultsKey.lockWallpaper) {
            lockWallpaperRaw = storedLock
        }
        lockWallpaperPhoto = defaults.string(forKey: DefaultsKey.lockWallpaperPhoto) ?? ""
        if let storedChatBackground = defaults.string(forKey: DefaultsKey.chatBackground) {
            chatBackgroundRaw = storedChatBackground
        }
        chatBackgroundPhoto = defaults.string(forKey: DefaultsKey.chatBackgroundPhoto) ?? ""
        if let storedBubble = defaults.string(forKey: DefaultsKey.chatBubble) {
            chatBubbleRaw = storedBubble
        }
        if let storedInk = defaults.string(forKey: DefaultsKey.homeTextInk) {
            homeTextInkRaw = storedInk
        }
        if defaults.object(forKey: DefaultsKey.temperature) != nil {
            temperature = defaults.double(forKey: DefaultsKey.temperature)
        }
        if defaults.object(forKey: DefaultsKey.maxTokens) != nil {
            maxTokens = defaults.integer(forKey: DefaultsKey.maxTokens)
        }
        if defaults.object(forKey: DefaultsKey.notifyReplies) != nil {
            notifyReplies = defaults.bool(forKey: DefaultsKey.notifyReplies)
        }
        billingByModel = defaults.dictionary(forKey: DefaultsKey.billingByModel) as? [String: String] ?? [:]
        billingModeRaw = billingByModel[model]
            ?? defaults.string(forKey: DefaultsKey.billingMode)
            ?? BillingMode.perToken.rawValue
        allowPhoneLookups = defaults.bool(forKey: DefaultsKey.allowPhoneLookups)
        allowPrivatePeek = defaults.bool(forKey: DefaultsKey.allowPrivatePeek)
        videoWallpaperEnabled = defaults.bool(forKey: DefaultsKey.videoWallpaper)
        passcode = defaults.string(forKey: DefaultsKey.passcode) ?? ""
        discreetMode = defaults.bool(forKey: DefaultsKey.discreetMode)
        if let data = defaults.data(forKey: DefaultsKey.refreshRules),
           let decoded = try? JSONDecoder().decode([RefreshRule].self, from: data) {
            refreshRules = merged(decoded)
        }
        if defaults.object(forKey: DefaultsKey.refreshInterval) != nil {
            refreshInterval = min(30, max(2, defaults.integer(forKey: DefaultsKey.refreshInterval)))
        }
        if let storedKey = KeychainStore.string(for: Self.keychainAccount) {
            apiKey = storedKey
        }
    }

    var config: LLMConfig {
        LLMConfig(
            baseURL: baseURL,
            model: model,
            apiKey: apiKey,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var wallpaperTheme: WallpaperTheme {
        WallpaperTheme(rawValue: wallpaperRaw) ?? .midnight
    }

    /// 桌面壁纸。
    var homeSelection: WallpaperSelection {
        // 隐藏模式：壁纸换成最普通的一套。
        // 只换皮不够——一屏情侣组件和名字照样能被人看见，所以主屏那边也跟着收。
        if discreetMode { return WallpaperSelection(theme: .graphite) }
        return WallpaperSelection(theme: wallpaperTheme, photoFileName: homeWallpaperPhoto)
    }

    /// 锁屏壁纸。没单独设就复用桌面那份——不是复制一份值，
    /// 而是每次现取，这样桌面换了锁屏跟着换。
    var lockSelection: WallpaperSelection {
        if discreetMode { return WallpaperSelection(theme: .graphite) }
        guard lockSeparate else { return homeSelection }
        return WallpaperSelection(
            theme: WallpaperTheme(rawValue: lockWallpaperRaw) ?? .midnight,
            photoFileName: lockWallpaperPhoto
        )
    }

    var billingMode: BillingMode {
        BillingMode(rawValue: billingModeRaw) ?? .perToken
    }

    var chatBackgroundMode: ChatBackgroundMode {
        ChatBackgroundMode(rawValue: chatBackgroundRaw) ?? .theme
    }

    /// 切聊天背景模式。离开照片档就把照片文件清掉——跟壁纸同一原则：
    /// 留着的话界面显示选的是渐变、实际却还压着一张图，谁也说不清。
    func setChatBackground(_ mode: ChatBackgroundMode) {
        guard mode.rawValue != chatBackgroundRaw else { return }
        chatBackgroundRaw = mode.rawValue
        if mode != .photo {
            let old = chatBackgroundPhoto
            chatBackgroundPhoto = ""
            WallpaperPhoto.delete(fileName: old)
        }
        persist()
    }

    func setChatBackgroundPhoto(_ fileName: String) {
        chatBackgroundRaw = ChatBackgroundMode.photo.rawValue
        chatBackgroundPhoto = fileName
        persist()
    }

    var chatBubbleStyle: ChatBubbleStyle {
        ChatBubbleStyle(rawValue: chatBubbleRaw) ?? .mint
    }

    func setChatBubble(_ style: ChatBubbleStyle) {
        chatBubbleRaw = style.rawValue
        persist()
    }

    var homeTextInk: HomeTextInk {
        HomeTextInk(rawValue: homeTextInkRaw) ?? .auto
    }

    func setHomeTextInk(_ ink: HomeTextInk) {
        homeTextInkRaw = ink.rawValue
        persist()
    }

    var generationPlan: GenerationPlan {
        GenerationPlan(mode: billingMode)
    }

    func setBillingMode(_ mode: BillingMode) {
        billingModeRaw = mode.rawValue
        billingByModel[model] = mode.rawValue
        persist()
    }

    /// 换模型后把该模型上次选的计费模式带出来。
    func syncBillingModeForModel() {
        let expected = billingByModel[model] ?? BillingMode.perToken.rawValue
        if billingModeRaw != expected {
            billingModeRaw = expected
        }
    }

    func setWallpaper(_ theme: WallpaperTheme) {
        guard wallpaperRaw != theme.rawValue else { return }
        wallpaperRaw = theme.rawValue
        // 换内置主题就把照片清掉：留着的话界面显示选中的是主题、
        // 实际铺的还是那张照片，谁也说不清到底哪个在生效。
        homeWallpaperPhoto = ""
        persist()
    }

    /// `lock == true` 时写锁屏那一套，否则写桌面那一套。
    func setWallpaper(_ theme: WallpaperTheme, lock: Bool) {
        if lock {
            lockWallpaperRaw = theme.rawValue
            lockWallpaperPhoto = ""
        } else {
            wallpaperRaw = theme.rawValue
            homeWallpaperPhoto = ""
        }
        persist()
    }

    func setWallpaperPhoto(_ fileName: String, lock: Bool) {
        if lock {
            lockWallpaperPhoto = fileName
        } else {
            homeWallpaperPhoto = fileName
        }
        persist()
    }

    // MARK: - 刷新配置

    /// 存档里少一个页面（版本升级新加的）就补默认值，多的丢掉。
    private func merged(_ stored: [RefreshRule]) -> [RefreshRule] {
        RefreshPage.allCases.map { page in
            stored.first { $0.page == page }
                ?? RefreshRule.default.first { $0.page == page }
                ?? RefreshRule(page: page, enabled: true, probability: 0.2)
        }
    }

    func rule(for page: RefreshPage) -> RefreshRule {
        refreshRules.first { $0.page == page }
            ?? RefreshRule(page: page, enabled: true, probability: 0.2)
    }

    func updateRule(_ rule: RefreshRule) {
        if let index = refreshRules.firstIndex(where: { $0.page == rule.page }) {
            refreshRules[index] = rule
        } else {
            refreshRules.append(rule)
        }
        persist()
    }

    /// 设锁屏密码。只收数字，四位；传空串就是关掉。
    func setPasscode(_ code: String) {
        let digits = String(code.filter(\.isNumber).prefix(4))
        guard digits != passcode else { return }
        passcode = digits
        persist()
    }

    func setDiscreetMode(_ on: Bool) {
        guard discreetMode != on else { return }
        discreetMode = on
        persist()
    }

    func persist() {
        let defaults = UserDefaults.standard
        defaults.set(baseURL, forKey: DefaultsKey.baseURL)
        defaults.set(model, forKey: DefaultsKey.model)
        defaults.set(wallpaperRaw, forKey: DefaultsKey.wallpaper)
        defaults.set(homeWallpaperPhoto, forKey: DefaultsKey.homeWallpaperPhoto)
        defaults.set(lockSeparate, forKey: DefaultsKey.lockSeparate)
        defaults.set(lockWallpaperRaw, forKey: DefaultsKey.lockWallpaper)
        defaults.set(lockWallpaperPhoto, forKey: DefaultsKey.lockWallpaperPhoto)
        defaults.set(chatBackgroundRaw, forKey: DefaultsKey.chatBackground)
        defaults.set(chatBackgroundPhoto, forKey: DefaultsKey.chatBackgroundPhoto)
        defaults.set(chatBubbleRaw, forKey: DefaultsKey.chatBubble)
        defaults.set(homeTextInkRaw, forKey: DefaultsKey.homeTextInk)
        defaults.set(temperature, forKey: DefaultsKey.temperature)
        defaults.set(maxTokens, forKey: DefaultsKey.maxTokens)
        defaults.set(notifyReplies, forKey: DefaultsKey.notifyReplies)
        defaults.set(billingModeRaw, forKey: DefaultsKey.billingMode)
        defaults.set(billingByModel, forKey: DefaultsKey.billingByModel)
        defaults.set(allowPhoneLookups, forKey: DefaultsKey.allowPhoneLookups)
        defaults.set(allowPrivatePeek, forKey: DefaultsKey.allowPrivatePeek)
        defaults.set(videoWallpaperEnabled, forKey: DefaultsKey.videoWallpaper)
        defaults.set(passcode, forKey: DefaultsKey.passcode)
        defaults.set(discreetMode, forKey: DefaultsKey.discreetMode)
        if let data = try? JSONEncoder().encode(refreshRules) {
            defaults.set(data, forKey: DefaultsKey.refreshRules)
        }
        defaults.set(refreshInterval, forKey: DefaultsKey.refreshInterval)
        KeychainStore.set(apiKey, for: Self.keychainAccount)
    }
}
