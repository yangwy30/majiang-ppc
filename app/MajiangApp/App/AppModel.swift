import SwiftUI
import MajiangKit

/// 只有一条主线：首页 → 开局 → 牌桌（也是账本）→ 结算。记一局是从牌桌全屏弹出的。
enum Route: Hashable {
    case newGame
    case table(UUID)
    case settle(UUID)
}

/// 识别用哪一路。默认「自动」：有什么用什么，什么都没有才用演示数据。只在开发版的设置里能改。
enum RecognitionMode: String, CaseIterable, Identifiable {
    case auto, demo, gemini, onDevice, dual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: "自动（推荐）"
        case .demo: "演示数据"
        case .gemini: "Gemini"
        case .onDevice: "只用端侧模型"
        case .dual: "端侧 + Gemini 双读"
        }
    }

    var usesOnDeviceModel: Bool { self == .onDevice || self == .dual }

    /// 自动时实际用哪一路：Key 和端侧模型都有就双读，只有一样就用那一样，都没有才是演示数据。
    static func resolveAuto(hasKey: Bool, hasModel: Bool) -> RecognitionMode {
        switch (hasKey, hasModel) {
        case (true, true): .dual
        case (true, false): .gemini
        case (false, true): .onDevice
        case (false, false): .demo
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

    /// 后端代理地址（server/ 里的 Cloudflare Worker）；为空时直接调 Google（开发用）。
    /// 正式版默认走代理；开发版默认用自带的 Key 直连，想试代理就在设置里点「用我们的服务器」。
    var proxyURL: String {
        didSet { UserDefaults.standard.set(proxyURL, forKey: "proxyURL") }
    }

    static let defaultProxyURL = "https://majiang-relay.yangwang9710.workers.dev/recognize"

    private let archiveURL: URL
    /// iCloud 同步；截图模式下不同步。
    let cloud: CloudSync
    /// 演示识别只建一次，这样每次拍照会轮到下一手示例牌。
    private let demoRecognizer = MockRecognizer()
    /// 端侧模型加载一次就留着（外层 nil = 还没加载，内层 nil = 没装）。
    @ObservationIgnored private var loadedDetector: TileDetecting??

    /// 截图模式停在哪一页（见 DemoData）；正式版永远是 nil。
    let demoScreen = DemoScreen.current

    init(archiveURL: URL? = nil) {
        var url = archiveURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("majiang", isDirectory: true)
            .appendingPathComponent("archive.json")
        #if DEBUG
        if let screen = DemoScreen.current {
            // 截图用的假数据放临时目录，每次启动重新生成
            url = FileManager.default.temporaryDirectory.appendingPathComponent("demo-archive.json")
            try? FileManager.default.removeItem(at: url)
            if screen != .emptyHome { try? DemoData.archive().save(to: url) }
        }
        #endif
        // 读不出来时原文件会被改名备份，之后保存不会覆盖掉旧记录
        let (loaded, backup, failure) = GameArchive.loadOrRecover(from: url)
        var error: String?
        if let failure {
            error = "读取牌局记录失败：\(failure.localizedDescription)"
            if let backup { error! += "。原文件已备份为 \(backup.lastPathComponent)" }
        }
        self.archiveURL = url
        self.cloud = CloudSync(stateURL: url.deletingLastPathComponent().appendingPathComponent("cloud-state.json"))
        if DemoScreen.current != nil { cloud.enabled = false }
        self.archive = loaded
        #if DEBUG
        if DemoScreen.current == nil { GeminiKeychain.importBundledDevKey() }
        #endif
        self.recognitionMode = RecognitionMode(rawValue: UserDefaults.standard.string(forKey: "recognitionMode") ?? "") ?? .auto
        #if DEBUG
        self.proxyURL = UserDefaults.standard.string(forKey: "proxyURL") ?? ""
        #else
        self.proxyURL = UserDefaults.standard.string(forKey: "proxyURL") ?? Self.defaultProxyURL
        #endif
        self.loadError = error
        // 有没打完的牌局时，打开 App 直接进牌桌
        if let active = loaded.activeGame { path = [.table(active.id)] }
        switch demoScreen {
        case .home, .emptyHome, .backup: path = []
        case .newGame, .houseRules, .rulePicker: path = [.newGame]
        case .settle: path = loaded.finishedGames.first.map { [.settle($0.id)] } ?? []
        default: break
        }
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

    /// 存到本机，再排一次 iCloud 同步。
    func save() {
        saveLocally()
        cloud.scheduleSync(self)
    }

    /// 只存本机（收到 iCloud 的改动时用，不用再传回去）。
    func saveLocally() {
        do {
            try archive.save(to: archiveURL)
        } catch {
            loadError = "保存失败：\(error.localizedDescription)"
        }
    }

    func syncNow() async {
        guard demoScreen == nil else { return }
        await cloud.sync(self)
    }

    // MARK: 导出导入（不用 iCloud 时换手机）

    /// 把全部记录写成一个文件，用来存到「文件」或隔空投送。
    func exportFile() throws -> URL {
        let stamp = Date().formatted(.iso8601.year().month().day().dateSeparator(.omitted))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("拍照算番-全部牌局-\(stamp).json")
        try archive.exportData().write(to: url, options: .atomic)
        return url
    }

    /// 并入另一台手机导出的文件，只加不删。
    func importFile(_ url: URL) throws -> ArchiveMergeSummary {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let other = try GameArchive.decode(Data(contentsOf: url))
        let summary = archive.merge(other)
        if !summary.isEmpty || !other.frequentPlayers.isEmpty { save() }
        return summary
    }

    // MARK: 识别

    /// 这次拍照实际走哪一路（「自动」在这里落到具体的一路）。
    var effectiveRecognitionMode: RecognitionMode {
        guard recognitionMode == .auto else { return recognitionMode }
        let hasKey = GeminiKeychain.hasKey || URL(string: proxyURL)?.scheme == "https"
        return .resolveAuto(hasKey: hasKey, hasModel: Self.onDeviceModelURL != nil)
    }

    func makeRecognizer() -> TileRecognizer {
        if demoScreen != nil { return demoRecognizer }
        switch effectiveRecognitionMode {
        case .auto, .demo:
            return demoRecognizer
        case .gemini:
            return RuleCheckedRecognizer(base: gemini())
        case .onDevice:
            return OnDeviceRecognizer(detector: onDeviceDetector)
        case .dual:
            return DualReadRecognizer(primary: OnDeviceRecognizer(detector: onDeviceDetector),
                                      secondary: RuleCheckedRecognizer(base: gemini()))
        }
    }

    // MARK: 端侧模型

    /// 端侧模型在 App 包里的位置（Xcode 把 Resources/Models/MahjongTileDetector.mlpackage 编译成 .mlmodelc）。
    /// 模型不进仓库，没放的话就是 nil，双读只剩 Gemini 一路。见 app/README.md。
    nonisolated static var onDeviceModelURL: URL? {
        Bundle.main.url(forResource: "MahjongTileDetector", withExtension: "mlmodelc")
    }

    private var onDeviceDetector: TileDetecting? {
        if let loaded = loadedDetector { return loaded }
        let detector = Self.loadDetector()
        loadedDetector = .some(detector)
        return detector
    }

    /// 打开拍照页时先在后台把模型加载好，按快门时不用等。
    func preloadOnDeviceModel() async {
        guard loadedDetector == nil, effectiveRecognitionMode.usesOnDeviceModel else { return }
        let detector = await Task.detached(priority: .userInitiated) { Self.loadDetector() }.value
        if loadedDetector == nil { loadedDetector = .some(detector) }
    }

    nonisolated private static func loadDetector() -> TileDetecting? {
        guard let url = onDeviceModelURL else { return nil }
        return try? CoreMLTileDetector(compiledModelAt: url)
    }

    private func gemini() -> GeminiRecognizer {
        let endpoint: GeminiConfiguration.Endpoint
        if let url = URL(string: proxyURL), url.scheme == "https" {
            endpoint = .proxy(url: url, deviceID: DeviceID.current)
        } else {
            endpoint = .direct(GeminiKeychain())
        }
        let sheet = ReferenceSheet.jpegData().map { (data: $0, mimeType: "image/jpeg") }
        return GeminiRecognizer(configuration: GeminiConfiguration(endpoint: endpoint, referenceSheet: sheet))
    }
}
