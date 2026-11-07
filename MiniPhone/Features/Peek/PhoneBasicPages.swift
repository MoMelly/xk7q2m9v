import SwiftUI

/// 备忘录。分组的写法跟系统一致：标题一行，正文两行截断，右下角改时间。
struct PhoneNotesPage: View {
    let phone: CharacterPhone

    var body: some View {
        AppPage(title: "备忘录", surface: .light) {
            ScrollView {
                if phone.notes.isEmpty {
                    empty("没有备忘录")
                } else {
                    GroupedSection("\(phone.notes.count) 条") {
                        ForEach(phone.notes) { note in
                            NavigationLink {
                                PhoneNotePage(note: note)
                            } label: {
                                row(note)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, PhoneMetrics.Space.s)
                    .padding(.bottom, PhoneMetrics.Space.xl)
                }
            }
        }
    }

    private func row(_ note: PhoneNote) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title.isEmpty ? "无标题" : note.title)
                .font(.system(size: PhoneMetrics.FontSize.body, weight: .medium))
                .foregroundStyle(AppSurface.light.label)
                .lineLimit(1)

            Text(note.body.replacingOccurrences(of: "\n", with: "  "))
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(AppSurface.light.secondaryLabel)
                .lineLimit(2)

            Text(note.editedAt)
                .font(.system(size: 10))
                .foregroundStyle(AppSurface.light.secondaryLabel.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.s)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppSurface.light.separator)
                .frame(height: 0.5)
                .padding(.leading, PhoneMetrics.Space.m)
        }
        .contentShape(Rectangle())
    }

    private func empty(_ text: String) -> some View {
        Text(text)
            .font(.system(size: PhoneMetrics.FontSize.footnote))
            .foregroundStyle(AppSurface.light.secondaryLabel)
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
    }
}

/// 一条备忘录的正文。用等宽一点的排版，像真的在记事本里看。
struct PhoneNotePage: View {
    let note: PhoneNote

    var body: some View {
        AppPage(title: "备忘录", surface: .light) {
            ScrollView {
                VStack(alignment: .leading, spacing: PhoneMetrics.Space.s) {
                    Text(note.title.isEmpty ? "无标题" : note.title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppSurface.light.label)

                    Text(note.editedAt)
                        .font(.system(size: PhoneMetrics.FontSize.caption))
                        .foregroundStyle(AppSurface.light.secondaryLabel)

                    Text(note.body)
                        .font(.system(size: PhoneMetrics.FontSize.body))
                        .lineSpacing(6)
                        .foregroundStyle(AppSurface.light.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, PhoneMetrics.Space.xs)
                }
                .padding(PhoneMetrics.Space.m)
            }
        }
    }
}

/// 通话记录。未接是红的，呼出带一个向右上的箭头，跟系统那一套一致。
struct PhoneCallsPage: View {
    let phone: CharacterPhone

    var body: some View {
        AppPage(title: "通话", surface: .light) {
            ScrollView {
                GroupedSection("\(phone.calls.count) 条记录") {
                    ForEach(phone.calls) { call in
                        row(call)
                    }
                }
                .padding(.top, PhoneMetrics.Space.s)
                .padding(.bottom, PhoneMetrics.Space.xl)
            }
        }
    }

    private func row(_ call: PhoneCall) -> some View {
        HStack(spacing: PhoneMetrics.Space.s) {
            Image(systemName: call.isMissed ? "phone.down.fill" : "phone.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(call.isMissed ? Theme.IconTint.pink : AppSurface.light.secondaryLabel)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(call.name)
                    .font(.system(size: PhoneMetrics.FontSize.body))
                    .foregroundStyle(call.isMissed ? Theme.IconTint.pink : AppSurface.light.label)

                HStack(spacing: 5) {
                    Text(call.kind)
                    if !call.duration.isEmpty {
                        Text("·")
                        Text(call.duration)
                    }
                }
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(AppSurface.light.secondaryLabel)
            }

            Spacer(minLength: 0)

            Text(call.time)
                .font(.system(size: PhoneMetrics.FontSize.footnote))
                .foregroundStyle(AppSurface.light.secondaryLabel)
        }
        .padding(.horizontal, PhoneMetrics.Space.m)
        .padding(.vertical, PhoneMetrics.Space.xs)
        .frame(minHeight: PhoneMetrics.Row.detailed)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppSurface.light.separator)
                .frame(height: 0.5)
                .padding(.leading, PhoneMetrics.Space.m)
        }
    }
}
