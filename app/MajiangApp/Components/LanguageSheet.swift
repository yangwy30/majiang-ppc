import SwiftUI

/// 「更多 › 语言」：从底下升起一页，跟「更多」同一个样子。点一行就选上，右边一个对勾，
/// 整个 App（连这一页）马上换成那种语言，不用关掉再打开。
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
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: Theme.columnWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(Theme.ink)
        // 标题一截加每行 72，再留一点底，跟「更多」一样
        .presentationDetents([.height(74 + 74 * CGFloat(AppLanguage.allCases.count))])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Theme.paper)
    }
}
