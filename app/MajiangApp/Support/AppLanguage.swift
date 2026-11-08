import Foundation
import Observation

/// App 用哪种语言：默认跟随手机，也可以在「更多 › 语言」里单独选。
///
/// 选了以后写进 App 自己的 `AppleLanguages`，跟 iPhone「设置 › 拍照算番 › 语言」是同一个设置（两边改哪边都行，互相看得到），
/// 下次打开 App 时系统直接用它。这次打开的 App 里也马上换：见 `LiveLanguage`。
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

    /// 选一种语言：存下来，界面马上换过去。
    @MainActor
    static func choose(_ language: AppLanguage) {
        if language == .system {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: key)
        }
        LiveLanguage.shared.switchTo(language.localization)
    }

    /// 界面实际用哪一份翻译（zh-Hans、zh-Hant、en、ja）。跟随手机时按手机的语言顺序找第一个有的，都没有就是英文，跟系统一样。
    private var localization: String {
        guard self == .system else { return rawValue }
        // 上面刚把 App 自己的设置删掉，这里读到的就是手机的语言顺序
        let phone = UserDefaults.standard.stringArray(forKey: Self.key) ?? Locale.preferredLanguages
        return phone.lazy.compactMap(Self.matching).first?.rawValue ?? AppLanguage.en.rawValue
    }

    /// 系统设置里选的可能带地区（zh-Hant-TW、en-GB），按开头认。
    private static func matching(_ identifier: String) -> AppLanguage? {
        if identifier.hasPrefix("zh-Hant") || identifier.hasPrefix("zh-TW") || identifier.hasPrefix("zh-HK")
            || identifier.hasPrefix("zh-MO") { return .zhHant }
        if identifier.hasPrefix("zh") { return .zhHans }
        if identifier.hasPrefix("en") { return .en }
        if identifier.hasPrefix("ja") { return .ja }
        return nil
    }
}

/// 界面现在显示的语言，换了马上生效，不用关掉 App 再打开。
///
/// 系统只在 App 启动时挑一次翻译，之后 `String(localized:)`、`Text("…")` 一直用那一份。换语言时这里做三件事：
/// 1. 把 `Bundle.main` 换成会转去新语言那份翻译的样子（`LiveBundle`），代码里取的字都变成新语言；
/// 2. 根视图的 `locale` 换掉，`Text` 和日期、数字跟着换；
/// 3. 根视图按语言重建一遍（`RootView` 里的 `.id`），已经画好的字全部重算。语言页本身挂在重建范围外面，不会被关掉。
@Observable
final class LiveLanguage {
    static let shared = LiveLanguage()

    /// zh-Hans、zh-Hant、en、ja。
    private(set) var localization: String
    /// 日期、数字跟界面同一种语言，地区还是手机的地区。
    @ObservationIgnored private(set) var locale: Locale
    /// 「更多 › 语言」那一页开着没有。放在这里而不是首页里：换语言时首页会重建，页子要留着。
    var showingSheet = false

    private init() {
        let launched = Bundle.main.preferredLocalizations.first ?? "zh-Hans"
        localization = launched
        locale = Self.locale(for: launched)
    }

    @MainActor
    func switchTo(_ new: String) {
        guard new != localization,
              let path = Bundle.main.path(forResource: new, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return }
        LiveBundle.install(bundle, localization: new)
        locale = Self.locale(for: new)
        localization = new
    }

    private static func locale(for language: String) -> Locale {
        // 地区在 languageComponents 里（en_GB 的 GB），换语言时要留着，不然英国的手机日期会按美国的顺序排
        var components = Locale.Components(locale: .current)
        var lang = Locale.Language.Components(identifier: language)
        lang.region = components.languageComponents.region ?? Locale.current.region
        components.languageComponents = lang
        return Locale(components: components)
    }
}

/// 换过语言以后 `Bundle.main` 的样子：取翻译时转去选中那种语言的 .lproj，`preferredLocalizations` 也报那种语言
/// （发给中转站的语言头用它）。一次都没换过时不装，App 跟以前完全一样。
private final class LiveBundle: Bundle {
    private static let lock = NSLock()
    private static var target: (bundle: Bundle, localization: String)?

    static func install(_ bundle: Bundle, localization: String) {
        lock.withLock { target = (bundle, localization) }
        if !(Bundle.main is LiveBundle) { object_setClass(Bundle.main, LiveBundle.self) }
    }

    private static var current: (bundle: Bundle, localization: String)? { lock.withLock { target } }

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = Self.current?.bundle else { return super.localizedString(forKey: key, value: value, table: tableName) }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }

    override var preferredLocalizations: [String] {
        guard let localization = Self.current?.localization else { return super.preferredLocalizations }
        return [localization]
    }
}
