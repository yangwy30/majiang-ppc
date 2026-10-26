import SwiftUI
import MajiangKit

/// 只有一条主线：首页 → 开局 → 牌桌（也是账本）→ 结算。记一局是从牌桌全屏弹出的。
enum Route: Hashable {
    case newGame
    case table(UUID)
    case settle(UUID)
}

/// 识别用哪一路。默认演示数据，填了 Key 之后可以切到 Gemini。只在开发版的设置里能改。
enum RecognitionMode: String, CaseIterable, Identifiable {
    case demo, gemini, dual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .demo: "演示数据"
        case .gemini: "Gemini"
        case .dual: "端侧 + Gemini 双读"
        }
    }
}

@MainActor
@Observable
final class AppModel {
    var archive: GameArchive
    var path: [Route] = []
    var loadError: String?

    var recognitionMode: RecognitionMode {
        didSet { UserDefaults.standard.set(recognitionMode.rawValue, forKey: "recognitionMode") }
    }

    /// 上架后改成后端代理地址；为空时直接调 Google（开发用）。
    var proxyURL: String {
        didSet { UserDefaults.standard.set(proxyURL, forKey: "proxyURL") }
    }

    private let archiveURL: URL
    /// 演示识别只建一次，这样每次拍照会轮到下一手示例牌。
    private let demoRecognizer = MockRecognizer()

    init(archiveURL: URL? = nil) {
        let url = archiveURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("majiang", isDirectory: true)
            .appendingPathComponent("archive.json")
        // 读不出来时原文件会被改名备份，之后保存不会覆盖掉旧记录
        let (loaded, backup, failure) = GameArchive.loadOrRecover(from: url)
        var error: String?
        if let failure {
            error = "读取牌局记录失败：\(failure.localizedDescription)"
            if let backup { error! += "。原文件已备份为 \(backup.lastPathComponent)" }
        }
        self.archiveURL = url
        self.archive = loaded
        self.recognitionMode = RecognitionMode(rawValue: UserDefaults.standard.string(forKey: "recognitionMode") ?? "") ?? .demo
        self.proxyURL = UserDefaults.standard.string(forKey: "proxyURL") ?? ""
        self.loadError = error
        // 有没打完的牌局时，打开 App 直接进牌桌
        if let active = loaded.activeGame { path = [.table(active.id)] }
    }

    // MARK: 牌局

    func game(_ id: UUID) -> Game? { archive.games.first { $0.id == id } }

    func update(_ game: Game) {
        archive.upsert(game)
        save()
    }

    @discardableResult
    func startGame(players: [Player], rules: GameRules) -> Game {
        let game = archive.start(Game(players: players, rules: rules))
        archive.remember(players)
        archive.lastRules = rules
        save()
        return game
    }

    func save() {
        do {
            try archive.save(to: archiveURL)
        } catch {
            loadError = "保存失败：\(error.localizedDescription)"
        }
    }

    // MARK: 识别

    func makeRecognizer() -> TileRecognizer {
        switch recognitionMode {
        case .demo:
            return demoRecognizer
        case .gemini:
            return RuleCheckedRecognizer(base: gemini())
        case .dual:
            return DualReadRecognizer(primary: OnDeviceRecognizer(), secondary: RuleCheckedRecognizer(base: gemini()))
        }
    }

    private func gemini() -> GeminiRecognizer {
        let endpoint: GeminiConfiguration.Endpoint
        if let url = URL(string: proxyURL), url.scheme == "https" {
            endpoint = .proxy(url: url, token: nil)
        } else {
            endpoint = .direct(GeminiKeychain())
        }
        let sheet = ReferenceSheet.jpegData().map { (data: $0, mimeType: "image/jpeg") }
        return GeminiRecognizer(configuration: GeminiConfiguration(endpoint: endpoint, referenceSheet: sheet))
    }
}
