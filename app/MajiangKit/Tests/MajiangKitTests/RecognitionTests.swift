import XCTest
@testable import MajiangKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class RecognitionTests: XCTestCase {
    private struct FixedKey: APIKeyProvider {
        func apiKey() throws -> String { "test-key" }
    }

    private final class FakeHTTP: HTTPClient, @unchecked Sendable {
        var requests: [URLRequest] = []
        var replies: [String]
        init(replies: [String]) { self.replies = replies }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            let answer = replies.isEmpty ? "{}" : replies.removeFirst()
            let envelope: [String: Any] = ["candidates": [["content": ["parts": [["text": answer]]]]]]
            return (try JSONSerialization.data(withJSONObject: envelope), 200)
        }
    }

    func testGeminiParsesConcealedAndMelds() async throws {
        let http = FakeHTTP(replies: [#"{"concealed":["1m","2m","3m","5p","5p"],"melds":[{"kind":"pung","tiles":["东","东","东"]},{"kind":"concealed_kong","tiles":["9s","9s","9s","9s"]},{"kind":"chow","tiles":["4p","3p","2p"]}],"flowers":2}"#])
        let recognizer = GeminiRecognizer(configuration: GeminiConfiguration(endpoint: .direct(FixedKey())), http: http)
        let result = try await recognizer.recognize(RecognitionRequest(image: Data([0xFF, 0xD8])))
        XCTAssertEqual(result.concealed.map(\.tile), Tile.parseList("123m55p"))
        XCTAssertEqual(result.melds, [.pung(Tile(.honors, 1)), .kong(Tile(.bamboo, 9), concealed: true), .chow(Tile(.dots, 2))!])
        XCTAssertEqual(result.flowerCount, 2)

        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), "test-key")
        XCTAssertTrue(request.url!.absoluteString.hasSuffix("models/gemini-3.8-flash:generateContent"))
        XCTAssertFalse(request.url!.absoluteString.contains("test-key"), "Key 不能出现在 URL 里")
    }

    func testProxyRequestCarriesNoKey() throws {
        let config = GeminiConfiguration(endpoint: .proxy(url: URL(string: "https://example.com/recognize")!, token: "t"))
        let request = try GeminiRecognizer(configuration: config).makeURLRequest(for: RecognitionRequest(image: Data()))
        XCTAssertNil(request.value(forHTTPHeaderField: "x-goog-api-key"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer t")
    }

    func testRuleCheckRetriesOnceWithFeedback() async throws {
        let bad = #"{"concealed":["1p","1p","1p","2p","2p","3p","3p","4p","4p","5p","4p","6p","6p","7p"],"melds":[],"flowers":0}"#
        let good = #"{"concealed":["1p","1p","1p","2p","2p","3p","3p","4p","4p","5p","5p","6p","6p","7p"],"melds":[],"flowers":0}"#
        let http = FakeHTTP(replies: [bad, good])
        let gemini = GeminiRecognizer(configuration: GeminiConfiguration(endpoint: .direct(FixedKey())), http: http)
        let result = try await RuleCheckedRecognizer(base: gemini).recognize(RecognitionRequest(image: Data()))
        XCTAssertEqual(http.requests.count, 2)
        XCTAssertTrue(FanCalculator.isWinningShape(result.hand))

        let body = try JSONSerialization.jsonObject(with: http.requests[1].httpBody!) as! [String: Any]
        XCTAssertEqual((body["contents"] as! [Any]).count, 3, "第二次带上一轮回答和原因")
    }

    func testDualReadFlagsDisagreementsAndResolverPicksTheWinningOne() async throws {
        let a = Recognition(concealed: Tile.parseList("1112233445566p7p"), source: "端侧")
        var bTiles = Tile.parseList("1112233445566p7p")
        bTiles[9] = Tile(.dots, 6)
        let b = Recognition(concealed: bTiles, source: "Gemini")

        // 端侧读对，Gemini 读错一张
        let merged = DualReadRecognizer.merge(b, a)
        XCTAssertEqual(merged.reviewCount, 1)
        XCTAssertEqual(merged.concealed[9].candidates, [Tile(.dots, 6), Tile(.dots, 5)])

        let resolution = RecognitionResolver.resolve(merged, context: WinContext(selfDrawn: true))
        XCTAssertEqual(resolution.recommended[9], Tile(.dots, 5))
        XCTAssertTrue(resolution.result?.contains(.fullFlush) ?? false)

        // 一路失败时用另一路
        let dual = DualReadRecognizer(primary: OnDeviceRecognizer(), secondary: MockRecognizer(samples: [a], delay: .zero))
        let only = try await dual.recognize(RecognitionRequest(image: Data()))
        XCTAssertEqual(only.source, "端侧")
    }

    func testMergeWithDifferentCounts() {
        let a = Recognition(concealed: Tile.parseList("123m456m789m11p23p"), source: "a")
        let b = Recognition(concealed: Tile.parseList("123m456m789m11p234p"), source: "b")
        let merged = DualReadRecognizer.merge(a, b)
        XCTAssertEqual(merged.concealed.count, 13)
        XCTAssertEqual(merged.reviewCount, 0, "a 里的牌在 b 里都有")
        let c = DualReadRecognizer.merge(b, a)
        XCTAssertEqual(c.reviewCount, 1)
    }

    func testMockSamplesAreConsistent() throws {
        let samples = MockRecognizer.defaultSamples
        XCTAssertTrue(samples.allSatisfy { $0.hand.hasValidTileCount })
        let flush = RecognitionResolver.resolve(samples[0], context: WinContext())
        XCTAssertNotNil(flush.result)
        XCTAssertTrue(try FanCalculator.score(samples[1].hand, context: WinContext()).get().meetsMinimum())
        XCTAssertFalse(FanCalculator.isWinningShape(samples[2].hand))
        XCTAssertFalse(WinAssistant.fixSuggestions(for: samples[2].hand, context: WinContext()).isEmpty)
    }
}
