import SwiftUI

/// 「更多 › 语言」：从底下升起一页，跟「更多」同一个样子。点一行就选上，右边一个对勾；
/// 选了跟这次打开时不一样的，底下用那种语言提示「关掉 App 再打开」。
struct LanguageSheet: View {
    @State private var selected = AppLanguage.chosen

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("语言")
                .font(.system(size: 20, weight: .semibold))
                .padding(.top, 28)
                .padding(.bottom, 8)
            ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element) { index, language in
                Button {
                    selected = language
                    AppLanguage.choose(language)
                } label: {
                    MenuRow(title: "\(language.nativeName)", divider: index < AppLanguage.allCases.count - 1) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .opacity(selected == language ? 1 : 0)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected == language ? .isSelected : [])
            }
            Text(verbatim: selected.relaunchNote)
                .font(.system(size: 14))
                .foregroundStyle(Theme.gray)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .opacity(selected == AppLanguage.launched ? 0 : 1)
                .animation(.easeOut(duration: 0.2), value: selected)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: Theme.columnWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(Theme.ink)
        // 标题一截、每行 72，再给底下那句提示留两行
        .presentationDetents([.height(74 + 74 * CGFloat(AppLanguage.allCases.count) + 52)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Theme.paper)
    }
}
