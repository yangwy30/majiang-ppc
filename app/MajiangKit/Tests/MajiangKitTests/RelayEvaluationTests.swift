import Foundation
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import MajiangKit

/// 走我们自己的中转站评测 Gemini 认牌（App 里同一套 GeminiRecognizer + 规则校验重问），手上没有 Gemini Key 时用。
/// 只测 Gemini，不跑端侧模型，所以 Linux 上也能跑。没设环境变量时跳过，CI 不跑。
///
///     MAJIANG_INVITE=ABC123                                   评测专用的邀请码（在 /admin 建，手机数 1，别用审核码或别人的码）
///     MAJIANG_DEVICE_ID=<UUID>                                固定一个设备编号，邀请码会绑在它上面
///     MAJIANG_PROXY_URL=https://majiang.acrossus.app/recognize  可选，默认就是这个
///     MAJIANG_PHOTOS / MAJIANG_REF_SHEET / MAJIANG_EXTRA_TRUTH / MAJIANG_ONLY / MAJIANG_REPEAT / MAJIANG_EVAL_OUT
///                                                             同 OnDeviceEvaluationTests
///     swift test --filter RelayEvaluationTests
///
/// 中转站每台手机每分钟最多 10 次，这里每次请求至少隔 7 秒。
final class RelayEvaluationTests: XCTestCase {
    private struct GroundTruth: Decodable {
        struct Photo: Decodable {
            var id: String
            var file: String
            var tiles: String
            var win: Bool?
        }
        var photos: [Photo]
    }

    private struct Row: Encodable {
        var id: String
        var truth: String
        var gemini: String?
        /// 原样的结构：立牌 | 副露
        var geminiRaw: String?
        var exact: Bool
        var win: Bool?
        var truthWin: Bool?
        var seconds: Double
        var error: String?
    }

    /// 两次请求之间至少隔一段时间，免得撞上中转站的每分钟限制。
    private actor Pacer {
        private var last = Date.distantPast
        let gap: TimeInterval
        init(gap: TimeInterval) { self.gap = gap }
        func wait() async {
            let delay = gap - Date().timeIntervalSince(last)
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            last = Date()
        }
    }

    private struct PacedHTTP: HTTPClient {
        let pacer: Pacer
        let base = URLSessionHTTPClient()
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            await pacer.wait()
            return try await base.send(request)
        }
    }

    private static func env(_ name: String) -> String? {
        ProcessInfo.processInfo.environment[name].map { NSString(string: $0).expandingTildeInPath }
    }

    private static func sorted(_ tiles: [Tile]) -> String { tiles.sorted().map(\.notation).joined(separator: " ") }

    func testGeminiThroughRelayOnTestPhotos() async throws {
        guard let invite = Self.env("MAJIANG_INVITE"), let device = Self.env("MAJIANG_DEVICE_ID") else {
            throw XCTSkip("没设 MAJIANG_INVITE / MAJIANG_DEVICE_ID，跳过中转站评测")
        }
        let proxy = try XCTUnwrap(URL(string: Self.env("MAJIANG_PROXY_URL") ?? "https://majiang.acrossus.app/recognize"))
        let photos = URL(fileURLWithPath: Self.env("MAJIANG_PHOTOS") ?? NSString(string: "~/Downloads/majiang-test-photos").expandingTildeInPath)
        let truthURL = try XCTUnwrap(Bundle.module.url(forResource: "ground_truth", withExtension: "json", subdirectory: "Fixtures"))
        var truth = try JSONDecoder().decode(GroundTruth.self, from: Data(contentsOf: truthURL))
        if let extra = Self.env("MAJIANG_EXTRA_TRUTH") {
            truth.photos += try JSONDecoder().decode(GroundTruth.self, from: Data(contentsOf: URL(fileURLWithPath: extra))).photos
        }
        if let only = Self.env("MAJIANG_ONLY") {
            let ids = Set(only.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
            truth.photos = truth.photos.filter { ids.contains($0.id) }
        }
        let repeats = max(1, Int(Self.env("MAJIANG_REPEAT") ?? "") ?? 1)

        let sheet = try Self.env("MAJIANG_REF_SHEET").map { (data: try Data(contentsOf: URL(fileURLWithPath: $0)), mimeType: "image/jpeg") }
        let config = GeminiConfiguration(endpoint: .proxy(url: proxy, deviceID: device, inviteCode: invite), referenceSheet: sheet)
        let gemini = RuleCheckedRecognizer(base: GeminiRecognizer(configuration: config, http: PacedHTTP(pacer: Pacer(gap: 7))))

        var rows: [Row] = []
        for photo in truth.photos.flatMap({ Array(repeating: $0, count: repeats) }) {
            let url = photos.appendingPathComponent(photo.file)
            guard let data = try? Data(contentsOf: url) else {
                print("缺照片 \(url.path)")
                continue
            }
            let expected = Tile.parseList(photo.tiles)
            let mime = url.pathExtension.lowercased() == "png" ? "image/png" : "image/jpeg"
            let start = Date()
            var row = Row(id: photo.id, truth: Self.sorted(expected), exact: false, truthWin: photo.win, seconds: 0)
            do {
                let remote = try await gemini.recognize(RecognitionRequest(image: data, mimeType: mime))
                row.gemini = Self.sorted(remote.hand.allTiles)
                row.geminiRaw = remote.concealed.map(\.tile.notation).joined(separator: " ")
                    + (remote.melds.isEmpty ? "" : " | " + remote.melds.map(\.displayText).joined(separator: " "))
                row.exact = row.gemini == row.truth
                row.win = FanCalculator.isWinningShape(remote.hand)
            } catch {
                row.error = "\(error)"
            }
            row.seconds = Date().timeIntervalSince(start)
            print(String(format: "%@ %@ %5.1f s  Gemini=%@", photo.id, row.exact ? "✅" : "❌", row.seconds, row.geminiRaw ?? row.error ?? "")
                  + (row.exact ? "" : "\n        应为=\(row.truth)"))
            rows.append(row)
        }

        let winRows = rows.filter { $0.truthWin != nil && $0.win != nil }
        let falseWins = rows.filter { $0.truthWin == false && $0.win == true }.count
        print("Gemini（中转站）：整手全对 \(rows.filter(\.exact).count)/\(rows.count)，"
              + "胡没胡判对 \(winRows.filter { $0.win == $0.truthWin }.count)/\(winRows.count)，误判成和 \(falseWins)，"
              + "出错 \(rows.filter { $0.error != nil }.count)")
        if let out = Self.env("MAJIANG_EVAL_OUT") {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(rows).write(to: URL(fileURLWithPath: out))
        }
    }
}
