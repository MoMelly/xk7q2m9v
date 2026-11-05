import SwiftUI

/// 通话记录。
///
/// 结构照系统电话的「最近通话」：顶部 全部 / 未接 分段控件，下面一整条列表，
/// 行内是名字、类型与时间，右侧 ⓘ 点开看详情。之前是四张独立白卡，
/// 也没有未接筛选。
///
/// 数据仍是界面记录，不拨号。名字取自角色，未接取「有未了结心声」的那几个人——
/// 他打过来、话没说完，这件事在通话记录里就该留着。
struct CallScene: View {
    let world: WorldStore
    var onClose: () -> Void

    @State private var filter: Filter = .all
    @State private var detail: CallEntry?

    enum Filter: String, CaseIterable, Identifiable {
        case all = "全部"
        case missed = "未接"

        var id: String { rawValue }
    }

    struct CallEntry: Identifiable {
        let id: String
        let name: String
        let detail: String
        let isMissed: Bool
        let date: Date
    }

    private var entries: [CallEntry] {
        let people = world.state.people
        var result: [CallEntry] = []

        for person in people {
            let openVoices = person.voices.filter { !$0.isResolved }
            let lastVoice = person.voices.map(\.createdAt).max()
            let lastFact = person.facts.map(\.createdAt).max()
            let date = [lastVoice, lastFact].compactMap { $0 }.max() ?? world.state.updatedAt

            if let latest = openVoices.max(by: { $0.createdAt < $1.createdAt }) {
                result.append(
                    CallEntry(
                        id: person.name,
                        name: person.name,
                        detail: latest.text,
                        isMissed: true,
                        date: latest.createdAt
                    )
                )
            } else {
                result.append(
                    CallEntry(
                        id: person.name,
                        name: person.name,
                        detail: "已接通",
                        isMissed: false,
                        date: date
                    )
                )
            }
        }

        // 陌生号码那条是本地模板：现实里的通话记录不会全是认识的人。
        result.append(
            CallEntry(
                id: "unknown",
                name: "未知号码",
                detail: "呼入 0 秒",
                isMissed: true,
                date: world.state.updatedAt.addingTimeInterval(-5_400)
            )
        )

        let filtered = filter == .all ? result : result.filter(\.isMissed)
        return filtered.sorted { $0.date > $1.date }
    }

    var body: some View {
        AppScreen(title: "通话记录", onClose: onClose) {
            VStack(spacing: 0) {
                Picker("筛选", selection: $filter) {
                    ForEach(Filter.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, PhoneMetrics.Space.m)
                .padding(.vertical, PhoneMetrics.Space.s)

                if entries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(entries) { entry in
                                entryRow(entry)
                                RowDivider()
                            }
                        }
                        .background(Theme.rowSurface)
                    }
                }
            }
            .alert("通话详情", isPresented: Binding(
                get: { detail != nil },
                set: { if !$0 { detail = nil } }
            )) {
                Button("好") { detail = nil }
            } message: {
                if let detail {
                    Text("\(detail.name)\n\(TimeFormat.callTime(detail.date))\n\(detail.detail)")
                }
            }
        }
    }

    private func entryRow(_ entry: CallEntry) -> some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            Image(systemName: entry.isMissed ? "phone.arrow.down.left" : "phone.arrow.up.right")
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(entry.isMissed ? Theme.IconTint.pink : Theme.secondaryLabel)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: PhoneMetrics.FontSize.body, weight: entry.isMissed ? .semibold : .regular))
                    .foregroundStyle(entry.isMissed ? Theme.IconTint.pink : Theme.label)
                    .lineLimit(1)

                Text("\(TimeFormat.callTime(entry.date)) · \(entry.detail)")
                    .font(.system(size: PhoneMetrics.FontSize.footnote))
                    .foregroundStyle(Theme.secondaryLabel)
                    .lineLimit(1)
            }

            Spacer(minLength: PhoneMetrics.Space.xs)

            Button {
                detail = entry
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(Theme.tint)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, PhoneMetrics.Space.m)
        .padding(.trailing, PhoneMetrics.Space.xs)
        .frame(minHeight: PhoneMetrics.Row.detailed)
    }

    private var emptyState: some View {
        VStack(spacing: PhoneMetrics.Space.xs) {
            Image(systemName: "phone.badge.checkmark")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.secondaryLabel.opacity(0.6))
            Text(filter == .missed ? "没有未接来电" : "还没有通话记录")
                .font(.system(size: PhoneMetrics.FontSize.sub))
                .foregroundStyle(Theme.secondaryLabel)
            Text("这里只作界面记录，不会真的拨号。")
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(Theme.secondaryLabel.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
