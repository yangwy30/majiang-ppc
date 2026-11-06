import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 用户给我们的话，发到中转站（Yang 在 /admin 上看）。两种：
/// - 「提意见」：用户自己写的一段话，可以留个联系方式。只带 App 版本和手机型号。
/// - 「认错了」：AI 读错、用户改过的那手牌，用户勾了才发：照片 + 认出来的牌 + 改对的牌，拿来改进认牌。
/// 地址跟认牌地址同一个中转站：…/recognize → …/feedback、…/misread。
public enum FeedbackClient {
    /// 意见最多多少字（服务器也截）。
    public static let maxTextLength = 2000
    public static let maxContactLength = 80

    public struct Message: Encodable, Equatable, Sendable {
        public var text: String
        public var contact: String
        public var app: String
        public var device: String

        public init(text: String, contact: String, app: String, device: String) {
            self.text = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(FeedbackClient.maxTextLength))
            self.contact = String(contact.trimmingCharacters(in: .whitespacesAndNewlines).prefix(FeedbackClient.maxContactLength))
            self.app = app
            self.device = device
        }
    }

    /// 一手牌：暗手里的牌和亮出来的副露，跟 `Recognition` 一样分开记。
    public struct HandTiles: Encodable, Equatable, Sendable {
        public var concealed: [Tile]
        public var melds: [Meld]

        public init(concealed: [Tile], melds: [Meld]) {
            self.concealed = concealed
            self.melds = melds
        }

        var all: [Tile] { concealed + melds.flatMap(\.tiles) }
    }

    public struct Misread: Encodable, Equatable, Sendable {
        /// JPEG，base64。
        public var photo: String
        public var recognized: HandTiles
        public var corrected: HandTiles
        /// 哪一路认的：端侧、Gemini、双读。
        public var source: String
        public var app: String
        public var device: String

        public init(photo: Data, recognized: HandTiles, corrected: HandTiles, source: String, app: String, device: String) {
            self.photo = photo.base64EncodedString()
            self.recognized = recognized
            self.corrected = corrected
            self.source = source
            self.app = app
            self.device = device
        }
    }

    /// 改对的牌和认出来的牌差了几张（多认、漏认、认错都算一张）。顺序不算：只换了位置不算认错。
    public static func changedCount(recognized: HandTiles, corrected: HandTiles) -> Int {
        var counts: [Tile: Int] = [:]
        for tile in recognized.all { counts[tile, default: 0] += 1 }
        for tile in corrected.all { counts[tile, default: 0] -= 1 }
        let extra = counts.values.filter { $0 > 0 }.reduce(0, +)
        let missing = counts.values.filter { $0 < 0 }.reduce(0, -)
        return max(extra, missing)
    }

    public static func url(forProxy proxy: URL, path: String) -> URL {
        proxy.deletingLastPathComponent().appendingPathComponent(path)
    }

    public static func send(_ message: Message, proxy: URL, deviceID: String,
                            http: HTTPClient = URLSessionHTTPClient()) async throws {
        try await post(message, to: url(forProxy: proxy, path: "feedback"), deviceID: deviceID, timeout: 20, http: http)
    }

    public static func send(_ misread: Misread, proxy: URL, deviceID: String,
                            http: HTTPClient = URLSessionHTTPClient()) async throws {
        try await post(misread, to: url(forProxy: proxy, path: "misread"), deviceID: deviceID, timeout: 60, http: http)
    }

    /// 失败时抛 `RecognitionError`，message 可以直接给用户看。
    static func post(_ body: some Encodable, to url: URL, deviceID: String, timeout: TimeInterval,
                     http: HTTPClient) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(deviceID, forHTTPHeaderField: "X-Majiang-Device")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let status: Int
        do {
            (data, status) = try await http.send(request)
        } catch {
            throw RecognitionError.unavailable("没发出去，看看网络再试一次")
        }
        guard status == 200 else {
            if let refusal = GeminiRecognizer.proxyRefusal(data) {
                throw RecognitionError.unavailable(refusal.message)
            }
            throw RecognitionError.unavailable("没发出去（HTTP \(status)），过一会儿再试")
        }
    }
}
