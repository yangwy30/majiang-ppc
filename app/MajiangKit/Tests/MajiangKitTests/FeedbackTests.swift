import XCTest
@testable import MajiangKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class FeedbackTests: XCTestCase {
    private final class Recorder: HTTPClient, @unchecked Sendable {
        var requests: [URLRequest] = []
        let status: Int
        let reply: String
        init(status: Int = 200, reply: String = #"{"ok":true}"#) { self.status = status; self.reply = reply }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (Data(reply.utf8), status)
        }
    }

    private let proxy = URL(string: "https://relay.example.com/recognize")!

    private func hand(_ text: String, melds: [Meld] = []) -> FeedbackClient.HandTiles {
        FeedbackClient.HandTiles(concealed: Tile.parseList(text), melds: melds)
    }

    func testChangedCountIgnoresOrder() {
        let read = hand("1112233445566p 7p")
        XCTAssertEqual(FeedbackClient.changedCount(recognized: read, corrected: read), 0)
        XCTAssertEqual(FeedbackClient.changedCount(recognized: read, corrected: hand("7p 6655443322111p")), 0, "只换了顺序")
        XCTAssertEqual(FeedbackClient.changedCount(recognized: hand("1112233445466p 7p"), corrected: read), 1, "一张读错")
        XCTAssertEqual(FeedbackClient.changedCount(recognized: hand("1112233445466p 9s"), corrected: read), 2, "两张读错")
        XCTAssertEqual(FeedbackClient.changedCount(recognized: hand("111223344556p 7p"), corrected: read), 1, "漏读一张")
        XCTAssertEqual(FeedbackClient.changedCount(recognized: hand("1112233445566p 7p 9s"), corrected: read), 1, "多读一张")
        XCTAssertEqual(FeedbackClient.changedCount(recognized: hand("123m 中中", melds: [.pung(Tile(.honors, 1))]),
                                                   corrected: hand("123m 中中", melds: [.pung(Tile(.honors, 2))])), 3, "碰读错了三张都算")
    }

    func testMessageIsTrimmedAndCapped() {
        let message = FeedbackClient.Message(text: "  \n算错了  ", contact: " wx_123 ", app: "1.0.3 (8)", device: "iPhone18,1")
        XCTAssertEqual(message.text, "算错了")
        XCTAssertEqual(message.contact, "wx_123")
        let long = FeedbackClient.Message(text: String(repeating: "长", count: 3000), contact: "", app: "", device: "")
        XCTAssertEqual(long.text.count, FeedbackClient.maxTextLength)
    }

    func testSendPostsToFeedbackNextToRecognize() async throws {
        let http = Recorder()
        let message = FeedbackClient.Message(text: "好用", contact: "", app: "1.0.3 (8)", device: "iPhone18,1")
        try await FeedbackClient.send(message, proxy: proxy, deviceID: "dev-1", http: http)
        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://relay.example.com/feedback")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Majiang-Device"), "dev-1")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: String])
        XCTAssertEqual(body, ["text": "好用", "contact": "", "app": "1.0.3 (8)", "device": "iPhone18,1"])
    }

    func testMisreadCarriesPhotoAndBothHands() async throws {
        let http = Recorder()
        let report = FeedbackClient.Misread(photo: Data([0xFF, 0xD8, 0xFF]), recognized: hand("12p", melds: [.pung(Tile(.honors, 5))]),
                                            corrected: hand("13p"), source: "双读", app: "1.0.3 (8)", device: "iPhone18,1")
        try await FeedbackClient.send(report, proxy: proxy, deviceID: "dev-1", http: http)
        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://relay.example.com/misread")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["photo"] as? String, "/9j/")
        XCTAssertEqual(body["source"] as? String, "双读")
        let recognized = try XCTUnwrap(body["recognized"] as? [String: Any])
        XCTAssertEqual(recognized["concealed"] as? [String], ["1p", "2p"])
        XCTAssertEqual((recognized["melds"] as? [Any])?.count, 1)
        let corrected = try XCTUnwrap(body["corrected"] as? [String: Any])
        XCTAssertEqual(corrected["concealed"] as? [String], ["1p", "3p"])
    }

    func testRefusalMessageIsShownAsIs() async {
        let http = Recorder(status: 429, reply: #"{"error":{"code":429,"message":"今天发得太多了，明天再来","majiang":true}}"#)
        let message = FeedbackClient.Message(text: "x", contact: "", app: "", device: "")
        do {
            try await FeedbackClient.send(message, proxy: proxy, deviceID: "d", http: http)
            XCTFail("应该抛错")
        } catch {
            XCTAssertEqual((error as? RecognitionError)?.message, "今天发得太多了，明天再来")
        }
    }
}
