import SwiftUI
import MajiangKit

enum Route: Hashable {
    case newGame
    case table(UUID)
    case ledger(UUID)
    case endGame(UUID)
    case settings
}

/// 识别用哪一路。默认演示数据，填了 Key 之后可以切到 Gemini。
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

    init(archiveURL: URL? = nil) {
        let url = archiveURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("majiang", isDirectory: true)
            .appendingPathComponent("archive.json")
        var loaded = GameArchive()
        var error: String?
        do {
            loaded = try GameArchive.load(from: url)
        } catch let failure {
            error = "读取牌局记录失败：\(failure.localizedDescription)"
        }
        self.archiveURL = url
        self.archive = loaded
        self.recognitionMode = RecognitionMode(rawValue: UserDefaults.standard.string(forKey: "recognitionMode") ?? "") ?? .demo
        self.proxyURL = UserDefaults.standard.string(forKey: "proxyURL") ?? ""
        self.loadError = error
    }

    // MARK: 牌局

    func game(_ id: UUID) -> Game? { archive.games.first { $0.id == id } }

    func update(_ game: Game) {
        archive.upsert(game)
        save()
    }

    @discardableResult
    func startGame(players: [Player], rules: GameRules) -> Game {
        let game = Game(players: players, rules: rules)
        archive.upsert(game)
        archive.remember(players)
        archive.lastRules = rules
        save()
        return game
    }

    func delete(_ id: UUID) {
        archive.games.removeAll { $0.id == id }
        save()
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
            return MockRecognizer()
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
