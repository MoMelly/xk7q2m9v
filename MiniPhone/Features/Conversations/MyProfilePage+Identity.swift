import SwiftUI

/// 「我的」页顶部那一格：现在是哪个身份，点进去换。
///
/// 单独放一个文件是因为 `MyProfilePage` 已经贴着 600 行上限。
extension MyProfilePage {
    var identitySection: some View {
        GroupedSection(
            surface: .glass,
            glass: true
        ) {
            Button {
                showIdentitySwitch = true
            } label: {
                GroupedRow(
                    symbol: "arrow.triangle.2.circlepath",
                    symbolTint: Theme.IconTint.teal,
                    title: "切换身份",
                    value: profile.name,
                    showsChevron: true,
                    surface: .glass
                )
            }
            .buttonStyle(.plain)
        }
    }
}
