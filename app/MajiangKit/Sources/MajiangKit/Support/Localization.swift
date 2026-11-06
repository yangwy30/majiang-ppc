import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// 给人看的字都走 `L`：在 App 里按手机语言换成繁体、英文或日文。翻译放在 App 的 Localizable.xcstrings 里，
// key 就是这里的简体原文（插进去的数字写成 %lld、文字写成 %@，跟 SwiftUI 的 Text 一个规矩）。
// 发给 Gemini 的提示词、存进账本的数据不走这里，永远是简体。
// Linux 上跑测试没有 String.LocalizationValue，原样返回简体。

#if canImport(Darwin)
@inline(__always)
func L(_ text: String.LocalizationValue) -> String {
    String(localized: text, bundle: .main)
}

/// 同一个简体字在不同地方要翻成不同的词时（风位「东」是 E，牌名「东」是 East），用单独的 key。
@inline(__always)
func L(key: StaticString, _ text: String.LocalizationValue) -> String {
    String(localized: key, defaultValue: text, bundle: .main)
}
#else
@inline(__always)
func L(_ text: String) -> String { text }

@inline(__always)
func L(key: StaticString, _ text: String) -> String { text }
#endif

extension Array where Element == String {
    /// 列举几样东西：中文「杨、阿强、莉莉」，英文「Yang, Qiang, Lily」。
    public var listText: String { joined(separator: L("、")) }
}

extension URLRequest {
    /// 告诉中转站 App 现在显示的是哪种语言（zh-Hans、zh-Hant、en、ja），它回的提示语（邀请码不对、今天次数用完了）跟着换。
    mutating func setAppLanguage() {
        setValue(Bundle.main.preferredLocalizations.first ?? "zh-Hans", forHTTPHeaderField: "Accept-Language")
    }
}
