import Foundation

/// App 用哪种语言：默认跟随手机，也可以在「更多 › 语言」里单独选。
///
/// 选了以后写进 App 自己的 `AppleLanguages`，跟 iPhone「设置 › 拍照算番 › 语言」是同一个设置（两边改哪边都行，互相看得到）。
/// 系统只在 App 启动时读它，所以要关掉 App 再打开才换过来；不在运行中硬换，免得一半字换了、一半没换。
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, zhHans = "zh-Hans", zhHant = "zh-Hant", en, ja

    var id: String { rawValue }

    /// 每种语言用它自己的文字写：界面是看不懂的语言时，也认得出自己要的那一行。
    var nativeName: String {
        switch self {
        case .system: String(localized: "language.system", defaultValue: "跟随手机", comment: "语言页：跟手机的语言走")
        case .zhHans: "简体中文"
        case .zhHant: "繁體中文"
        case .en: "English"
        case .ja: "日本語"
        }
    }

    private static let key = "AppleLanguages"

    /// 现在存着的选择。只看 App 自己的设置，不看手机的（`UserDefaults.standard` 读出来的是两者合在一起的）。
    static var chosen: AppLanguage {
        guard let id = Bundle.main.bundleIdentifier,
              let languages = UserDefaults.standard.persistentDomain(forName: id)?[key] as? [String],
              let first = languages.first else { return .system }
        return matching(first) ?? .system
    }

    /// 这次打开 App 时的选择：选了别的、还没重开时，用来判断要不要提示「关掉再打开」。
    static let launched = chosen

    static func choose(_ language: AppLanguage) {
        if language == .system {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: key)
        }
    }

    /// 系统设置里选的可能带地区（zh-Hant-TW、en-GB），按开头认。
    private static func matching(_ identifier: String) -> AppLanguage? {
        if identifier.hasPrefix("zh-Hant") || identifier == "zh-TW" || identifier == "zh-HK" { return .zhHant }
        if identifier.hasPrefix("zh") { return .zhHans }
        if identifier.hasPrefix("en") { return .en }
        if identifier.hasPrefix("ja") { return .ja }
        return nil
    }

    /// 「关掉 App 再打开」这句用选中的那种语言写：刚选了日文的人，要看得懂这句。
    var relaunchNote: String {
        let wanted = self == .system ? Locale.preferredLanguages : [rawValue]
        let bundle = Bundle.preferredLocalizations(from: Bundle.main.localizations, forPreferences: wanted).first
            .flatMap { Bundle.main.path(forResource: $0, ofType: "lproj") }
            .flatMap(Bundle.init(path:)) ?? .main
        return String(localized: "language.relaunch", defaultValue: "从后台划掉 App 再打开，就换好了",
                      bundle: bundle, comment: "语言页：选了别的语言以后的提示")
    }
}
