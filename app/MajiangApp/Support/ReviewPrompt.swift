import StoreKit
import UIKit
import MajiangKit

/// 什么时候请用户去 App Store 打分。只在打完一场、从结算页回首页那一下问：
/// 刚算完账、正高兴，也不打断打牌。用的是苹果自己的评分框，字和样子改不了，苹果一年最多让它出现 3 次。
enum ReviewPrompt {
    private static let askedVersionKey = "reviewPromptVersion"

    /// 这场刚打完（两小时内）、至少 4 局、这个版本还没问过。第一场打完就问：大多数人只打一两场，等到第二场就问不到了。
    static func shouldAsk(game: Game, now: Date,
                          defaults: UserDefaults = .standard, version: String = AppInfo.version) -> Bool {
        guard let ended = game.endedAt, now.timeIntervalSince(ended) < 2 * 3600 else { return false }
        guard game.records.count >= 4 else { return false }
        return defaults.string(forKey: askedVersionKey) != version
    }

    /// 弹苹果的评分框。SwiftUI 的 requestReview 有时找不到窗口（"Could not get scene"），这里直接给它前台的那个窗口。
    @MainActor
    static func request() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else { return }
        AppStore.requestReview(in: scene)
    }

    static func markAsked(defaults: UserDefaults = .standard, version: String = AppInfo.version) {
        defaults.set(version, forKey: askedVersionKey)
    }

    /// App Store 上「写评论」那一页（意见页底下的「去 App Store 打个分」）。
    static let writeReviewURL = URL(string: "https://apps.apple.com/app/id6827328659?action=write-review")!
}

enum AppInfo {
    /// 「1.0.3 (8)」。
    static let version: String = {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }()

    /// 机型编号，比如「iPhone18,1」；模拟器上是 Mac 的，换成模拟的那台。
    static let deviceModel: String = {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }()
}
