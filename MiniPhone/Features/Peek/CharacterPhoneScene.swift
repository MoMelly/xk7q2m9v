import SwiftUI
import SwiftData

/// 他的手机。
///
/// 玩家视角：这是「他」的那台手机，不是我的。所以整页按 iOS 桌面来做 ——
/// 一排 App 图标，点进去各看各的。内容由模型按固定模板生成，写在世界状态里，
/// 不是每次进来现生成；换角色会去读那个人的那一份。
struct CharacterPhoneScene: View {
    let world: WorldStore
    @Bindable var settings: SettingsStore
    var onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Companion.sortIndex) private var companions: [Companion]

    @State private var errorText: String?

    private var service: CharacterPhoneService { .shared }

    /// 最近说过话的那个角色。查手机查的是「此刻在我旁边的那个人」，
    /// 所以按最后一条消息时间挑，没说过话的排后面。
    private var owner: Companion? {
        companions
            .filter { !$0.isFeedOnly }
            .sorted { lhs, rhs in
                (lhs.lastMessageAt ?? .distantPast) > (rhs.lastMessageAt ?? .distantPast)
            }
            .first
    }

    private var phone: CharacterPhone? {
        guard let owner else { return nil }
        return world.phone(for: owner.name)
    }

    /// 右上角的按钮：有内容才给「更新」，没有就不放（空态里有一整颗按钮）。
    /// 拆成两个计算属性而不是写三元表达式，闭包和 nil 混在一起推断会打架。
    private var trailingTitle: String? {
        guard phone != nil else { return nil }
        return service.isGenerating ? "生成中" : "更新"
    }

    private var trailingAction: (() -> Void)? {
        guard phone != nil else { return nil }
        return { regenerate() }
    }

    var body: some View {
        AppScreen(
            title: owner.map { "\($0.name) 的手机" } ?? "手机",
            surface: .light,
            onClose: onClose,
            trailingTitle: trailingTitle,
            trailingAction: trailingAction
        ) {
            if let owner {
                content(owner)
            } else {
                noCharacterState
            }
        }
        .alert(
            "没看成",
            isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })
        ) {
            Button("知道了", role: .cancel) { errorText = nil }
        } message: {
            Text(errorText ?? "")
        }
    }

    @ViewBuilder
    private func content(_ owner: Companion) -> some View {
        if let phone, !phone.isEmpty {
            filled(owner, phone)
        } else {
            generateState(owner)
        }
    }

    // MARK: - 有内容

    private func filled(_ owner: Companion, _ phone: CharacterPhone) -> some View {
        ScrollView {
            VStack(spacing: PhoneMetrics.Space.m) {
                note

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: PhoneMetrics.Space.s), count: 4),
                    spacing: PhoneMetrics.Space.m
                ) {
                    ForEach(PeekApp.allCases) { app in
                        NavigationLink {
                            destination(app, phone)
                        } label: {
                            tile(app, phone)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(PhoneMetrics.Space.m)
                .frostedCard(cornerRadius: PhoneMetrics.Radius.widget, shadow: .none)

                footer(phone)
            }
            .padding(.horizontal, PhoneMetrics.Space.m)
            .padding(.bottom, PhoneMetrics.Space.xl)
        }
        .overlay {
            if service.isGenerating {
                generatingOverlay
            }
        }
    }

    private var note: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.open")
                .font(.system(size: 11, weight: .semibold))
            Text("他不在旁边。看完记得放下。")
                .font(.system(size: PhoneMetrics.FontSize.footnote))
            Spacer(minLength: 0)
        }
        .foregroundStyle(AppSurface.light.secondaryLabel)
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.top, PhoneMetrics.Space.s)
    }

    private func tile(_ app: PeekApp, _ phone: CharacterPhone) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(app.tint)
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: app.symbol)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .opacity(app.needsPrivate && !settings.allowPrivatePeek ? 0.45 : 1)

                if let badge = app.badge(in: phone) {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Theme.IconTint.pink))
                        .offset(x: 7, y: -5)
                }
            }

            Text(app.title)
                .font(.system(size: 11))
                .foregroundStyle(AppSurface.light.label)
                .lineLimit(1)
        }
    }

    private func footer(_ phone: CharacterPhone) -> some View {
        VStack(spacing: 4) {
            if let generatedAt = phone.generatedAt {
                Text("上次翻是 \(TimeFormat.monthDayTime(generatedAt))")
            }
            Text("内容由 \(phone.owner) 这两天的状态生成，不是随机填的。")
        }
        .font(.system(size: PhoneMetrics.FontSize.caption))
        .foregroundStyle(AppSurface.light.secondaryLabel)
        .multilineTextAlignment(.center)
        .padding(.top, PhoneMetrics.Space.xs)
    }

    @ViewBuilder
    private func destination(_ app: PeekApp, _ phone: CharacterPhone) -> some View {
        switch app {
        case .chats:
            PhoneChatListPage(phone: phone, owner: phone.owner)
        case .album:
            PhoneAlbumPage(phone: phone)
        case .notes:
            PhoneNotesPage(phone: phone)
        case .calls:
            PhoneCallsPage(phone: phone)
        case .shopping:
            PhoneShoppingPage(phone: phone)
        case .web:
            PhoneBrowsePage(phone: phone)
        case .usage:
            PhoneUsagePage(phone: phone)
        case .secrets:
            PhoneSecretsPage(phone: phone, unlocked: settings.allowPrivatePeek)
        }
    }

    // MARK: - 空与生成

    private func generateState(_ owner: Companion) -> some View {
        VStack(spacing: PhoneMetrics.Space.m) {
            Spacer(minLength: 0)

            Image(systemName: "iphone.gen3")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(AppSurface.light.secondaryLabel)

            VStack(spacing: 6) {
                Text("\(owner.name) 的手机还没打开过")
                    .font(.system(size: PhoneMetrics.FontSize.sub, weight: .medium))
                    .foregroundStyle(AppSurface.light.label)

                Text("生成一次，会有他的微信、相册、备忘录、通话、购物清单、浏览记录、屏幕时间，还有他没讲出口的事。")
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(AppSurface.light.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, PhoneMetrics.Space.l)
            }

            Button {
                regenerate()
            } label: {
                HStack(spacing: 6) {
                    if service.isGenerating {
                        ProgressView().tint(.white)
                    }
                    Text(service.isGenerating ? "正在翻…" : "生成他的手机")
                        .font(.system(size: PhoneMetrics.FontSize.body, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, PhoneMetrics.Space.l)
                .frame(height: 44)
                .background(Capsule().fill(Theme.tint))
            }
            .disabled(service.isGenerating)
            .padding(.top, PhoneMetrics.Space.xs)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noCharacterState: some View {
        VStack(spacing: PhoneMetrics.Space.xs) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 30, weight: .light))
            Text("还没有角色")
                .font(.system(size: PhoneMetrics.FontSize.sub))
            Text("先在信息里建一个角色，再来看他的手机。")
                .font(.system(size: PhoneMetrics.FontSize.caption))
        }
        .foregroundStyle(AppSurface.light.secondaryLabel)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var generatingOverlay: some View {
        ZStack {
            Color.black.opacity(0.06)
            HStack(spacing: 10) {
                ProgressView()
                Text("正在翻他的手机…")
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
            }
            .padding(.horizontal, PhoneMetrics.Space.l)
            .padding(.vertical, PhoneMetrics.Space.s)
            .frostedCard(cornerRadius: PhoneMetrics.Radius.card)
        }
    }

    private func regenerate() {
        guard let owner else { return }
        let userName = UserProfileBook.resolve(uid: owner.personaUID, in: context)?.name
        Task {
            let outcome = await service.generate(
                character: owner,
                settings: settings,
                userName: userName,
                allowPrivate: settings.allowPrivatePeek
            )
            switch outcome {
            case .success:
                break
            case .failure(let message):
                errorText = message
            }
        }
    }
}

/// 手机上的八个 App。图标、名字、角标都从这里出，加一个只要加一个 case。
enum PeekApp: String, CaseIterable, Identifiable {
    case chats
    case album
    case notes
    case calls
    case shopping
    case web
    case usage
    case secrets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chats: return "微信"
        case .album: return "相册"
        case .notes: return "备忘录"
        case .calls: return "通话"
        case .shopping: return "购物"
        case .web: return "浏览器"
        case .usage: return "屏幕时间"
        case .secrets: return "私密"
        }
    }

    var symbol: String {
        switch self {
        case .chats: return "message.fill"
        case .album: return "photo.fill"
        case .notes: return "note.text"
        case .calls: return "phone.fill"
        case .shopping: return "cart.fill"
        case .web: return "safari.fill"
        case .usage: return "hourglass"
        case .secrets: return "lock.fill"
        }
    }

    var tint: Color {
        switch self {
        case .chats: return Theme.IconTint.green
        case .album: return Theme.IconTint.orange
        case .notes: return Theme.IconTint.orange
        case .calls: return Theme.IconTint.green
        case .shopping: return Theme.IconTint.pink
        case .web: return Theme.IconTint.indigo
        case .usage: return Theme.IconTint.gray
        case .secrets: return Theme.IconTint.purple
        }
    }

    var needsPrivate: Bool { self == .secrets }

    func badge(in phone: CharacterPhone) -> Int? {
        switch self {
        case .chats:
            let count = phone.chats.reduce(0) { $0 + $1.unread }
            return count > 0 ? count : nil
        case .secrets:
            return phone.secrets.isEmpty ? nil : phone.secrets.count
        default:
            return nil
        }
    }
}
