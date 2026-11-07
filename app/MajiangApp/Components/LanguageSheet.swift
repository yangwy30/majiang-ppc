import SwiftUI

/// 「更多」里的「语言」：从底下升起的一页，样子跟「更多」一样，一种语言一行，选中的打勾。
/// 写的是本 App 自己的 AppleLanguages，跟系统「设置 → 本 App → 语言」是同一个设置，
/// 所以重新打开 App 才换。系统那一页只有手机里加过两种以上语言时才出现，大多数人看不到，所以放在 App 里。
struct LanguageSheet: View {
    /// nil 是跟随手机。语言名用各自的写法，不跟着界面翻译，换错了也认得回来。
    private static let options: [(code: String?, name: String?)] = [
        (nil, nil), ("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文"), ("en", "English"), ("ja", "日本語"),
    ]
    private static let key = "AppleLanguages"

    /// 打开这页时 App 正在用的语言；选了别的就提示重新打开。
    private let showing = Money.language
    @State private var chosen = LanguageSheet.saved

    /// 只看本 App 自己存的那份；UserDefaults.standard 直接读会读到系统的语言列表。
    private static var saved: String? {
        guard let id = Bundle.main.bundleIdentifier,
              let list = UserDefaults.standard.persistentDomain(forName: id)?[key] as? [String] else { return nil }
        return list.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("语言")
                .font(.system(size: 20, weight: .semibold))
                .padding(.top, 28)
                .padding(.bottom, 8)
            ForEach(Array(Self.options.enumerated()), id: \.offset) { index, option in
                Button { pick(option.code) } label: {
                    row(option.name, divider: index < Self.options.count - 1) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                            .opacity(isChosen(option.code) ? 1 : 0)
                    }
                }
                .buttonStyle(.plain)
            }
            Text("重新打开 App 后生效")
                .font(.system(size: 14))
                .foregroundStyle(Theme.gray)
                .padding(.top, 12)
                .opacity(pending ? 1 : 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: Theme.columnWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(Theme.ink)
        .animation(.easeOut(duration: 0.2), value: chosen)
        // 标题一截，五行各 60，底下留一句提示的地方
        .presentationDetents([.height(74 + 60 * CGFloat(Self.options.count) + 56)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Theme.paper)
    }

    private func row(_ name: String?, divider: Bool, @ViewBuilder trailing: () -> some View) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Group {
                    if let name { Text(verbatim: name) } else { Text("跟随手机") }
                }
                .font(.system(size: 17))
                Spacer(minLength: 8)
                trailing()
            }
            .frame(minHeight: 60)
            if divider { Hairline() }
        }
        .contentShape(Rectangle())
    }

    private func isChosen(_ code: String?) -> Bool { chosen == code }

    /// 界面的语言是 App 启动时定的。第一次打开这页时记下当时存的设置（这时还没改过），
    /// 之后选的跟它不一样就提示重新打开；选的正好是眼前这种语言就不用提示。
    private static let atLaunch = LanguageSheet.saved

    private var pending: Bool {
        guard chosen != Self.atLaunch else { return false }
        if let chosen { return chosen != showing }
        return true  // 改回跟随手机：不知道手机会给哪种，提示一下
    }

    private func pick(_ code: String?) {
        chosen = code
        if let code {
            UserDefaults.standard.set([code], forKey: Self.key)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.key)
        }
    }
}
