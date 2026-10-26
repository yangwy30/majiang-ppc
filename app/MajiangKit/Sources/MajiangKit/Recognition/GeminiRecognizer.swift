import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// 发 HTTP 请求。单独抽出来，测试时可以换成假的。
public protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, Int)
}

public struct URLSessionHTTPClient: HTTPClient {
    public init() {}

    public func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

/// 取 API Key。App 里从钥匙串读，Key 绝不写进代码或仓库。
public protocol APIKeyProvider: Sendable {
    func apiKey() throws -> String
}

public struct GeminiConfiguration: Sendable {
    public enum Endpoint: Sendable {
        /// 开发阶段：App 直接调 Google，Key 由用户在设置里填，存在钥匙串。
        case direct(APIKeyProvider)
        /// 上架后：调我们自己的后端代理，代理持有 Key，App 里没有 Key。
        /// 代理收到的请求体和 Google generateContent 一样，原样转发即可（见 docs/app-architecture.md）。
        case proxy(url: URL, token: String?)
    }

    public var endpoint: Endpoint
    /// 研究阶段只用 Flash（Yang 的决定），见 research/gemini-recognition.md。
    public var model: String
    /// 牌面参考图。研究里「参考图 + 数点数」是最好的方法（33 张里 32 张全对）。
    /// 注意：研究用的参考图没有许可证，不能打包进 App，这里要用我们自己画的牌面。
    public var referenceSheet: (data: Data, mimeType: String)?
    public var timeout: TimeInterval

    public init(endpoint: Endpoint, model: String = "gemini-3.8-flash",
                referenceSheet: (data: Data, mimeType: String)? = nil, timeout: TimeInterval = 60) {
        self.endpoint = endpoint
        self.model = model
        self.referenceSheet = referenceSheet
        self.timeout = timeout
    }
}

/// 用 Gemini 认牌。只让模型读牌，和没和、几番由规则引擎决定。
public struct GeminiRecognizer: TileRecognizer {
    public let name = "Gemini"
    public var configuration: GeminiConfiguration
    public var http: HTTPClient

    public init(configuration: GeminiConfiguration, http: HTTPClient = URLSessionHTTPClient()) {
        self.configuration = configuration
        self.http = http
    }

    static let apiBase = URL(string: "https://generativelanguage.googleapis.com/v1beta")!

    public func recognize(_ request: RecognitionRequest) async throws -> Recognition {
        let urlRequest = try makeURLRequest(for: request)
        let data: Data
        let status: Int
        do {
            (data, status) = try await http.send(urlRequest)
        } catch {
            throw RecognitionError.network(error.localizedDescription)
        }
        guard status == 200 else {
            let text = String(decoding: data.prefix(300), as: UTF8.self)
            throw RecognitionError.network("HTTP \(status) \(text)")
        }
        return try Self.parseResponse(data)
    }

    // MARK: 请求

    func makeURLRequest(for request: RecognitionRequest) throws -> URLRequest {
        var urlRequest: URLRequest
        switch configuration.endpoint {
        case .direct(let keys):
            let key = try keys.apiKey()
            guard !key.isEmpty else { throw RecognitionError.notConfigured }
            urlRequest = URLRequest(url: Self.apiBase.appendingPathComponent("models/\(configuration.model):generateContent"))
            urlRequest.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        case .proxy(let url, let token):
            urlRequest = URLRequest(url: url)
            urlRequest.setValue(configuration.model, forHTTPHeaderField: "X-Majiang-Model")
            if let token { urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        }
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.timeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody(for: request))
        return urlRequest
    }

    func requestBody(for request: RecognitionRequest) -> [String: Any] {
        var parts: [[String: Any]] = []
        if let sheet = configuration.referenceSheet {
            parts.append(["text": "参考图：各种麻将牌的牌面（不同牌的画法可能不同，仅作参考）。"])
            parts.append(Self.imagePart(sheet.data, sheet.mimeType))
            parts.append(["text": "要识别的照片："])
        }
        parts.append(Self.imagePart(request.image, request.mimeType))
        parts.append(["text": Self.prompt])

        var contents: [[String: Any]] = [["role": "user", "parts": parts]]
        if let previous = request.previous, let feedback = request.feedback {
            contents.append(["role": "model", "parts": [["text": Self.encodeAnswer(previous)]]])
            contents.append(["role": "user", "parts": [["text": feedback + "\n请对照照片逐张重新数点数，再输出一次 JSON。"]]])
        }
        return [
            "contents": contents,
            "generationConfig": ["responseMimeType": "application/json", "responseSchema": Self.schema],
        ]
    }

    static func imagePart(_ data: Data, _ mimeType: String) -> [String: Any] {
        ["inline_data": ["mime_type": mimeType, "data": data.base64EncodedString()]]
    }

    /// 基于研究里效果最好的提示词（tools/gemini-test 的 PROMPT + PIP_HINT），改成按 App 的拍照约定分开立牌和副露。
    static let prompt = """
    这是一张麻将照片，拍的是和牌那家的牌：手牌推倒排成一排，和的那张放在最右；吃、碰、杠放在旁边，暗杠翻开一张。
    请逐张读出这家的牌。
    - 不要算进别人的牌、打出去的牌（牌河）、牌墙和桌上其他散牌。
    - 记法：1m-9m=万子，1p-9p=饼/筒子，1s-9s=条/索子，字牌用汉字：东 南 西 北 中 发 白。
    - concealed：排成一排的手牌，从左到右，包括最右边和的那张。
    - melds：摆在旁边的每一组吃、碰、杠。kind 写 chow（吃）、pung（碰）、kong（明杠）或 concealed_kong（暗杠）；杠写满 4 张，扣着的那张也算作这张杠牌。
    - 花牌（春夏秋冬梅兰竹菊）不要放进牌里，只在 flowers 里报数量。
    特别注意：条子和饼子要逐张数点数，不要凭整体印象猜。
    - 条子数竹节根数：1条通常画成一只鸟；5条是四角各一根 + 中间一根（中间那根常是红色）；4条是两列各两根、中间没有；6条是两排各三根；7条是顶上一根 + 下面六根；8条常画成 W/M 形；9条是三排各三根。
    - 饼子数圆点：6饼是上面 2 个 + 下面 4 个；7饼是斜着 3 个 + 下面 4 个；8饼是两列各 4 个。
    - 每张先数清楚再写，写完确认张数：立牌 + 每组副露 3 张（杠 4 张）一般共 14 张，每个杠多 1 张。
    不要判断和没和，只输出 JSON。
    """

    static let schema: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "concealed": ["type": "ARRAY", "items": ["type": "STRING"],
                          "description": "Standing tiles left to right, winning tile last, e.g. 1m, 5p, 9s, 东"],
            "melds": ["type": "ARRAY", "items": [
                "type": "OBJECT",
                "properties": [
                    "kind": ["type": "STRING", "enum": ["chow", "pung", "kong", "concealed_kong"]],
                    "tiles": ["type": "ARRAY", "items": ["type": "STRING"]],
                ],
                "required": ["kind", "tiles"],
            ]],
            "flowers": ["type": "INTEGER"],
            "confidence": ["type": "STRING", "enum": ["high", "medium", "low"]],
        ],
        "required": ["concealed", "melds", "flowers"],
    ]

    // MARK: 回答

    struct Answer: Codable {
        struct MeldAnswer: Codable {
            var kind: String
            var tiles: [String]
        }
        var concealed: [String]
        var melds: [MeldAnswer]?
        var flowers: Int?
        var confidence: String?
    }

    static func parseResponse(_ data: Data) throws -> Recognition {
        struct Envelope: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable {
                        var text: String?
                        var thought: Bool?
                    }
                    var parts: [Part]
                }
                var content: Content
            }
            var candidates: [Candidate]?
        }
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw RecognitionError.badResponse("不是 Gemini 的回答格式")
        }
        guard let parts = envelope.candidates?.first?.content.parts else {
            throw RecognitionError.badResponse("没有候选回答")
        }
        let text = parts.filter { $0.thought != true }.compactMap(\.text).joined()
        return try parseAnswer(Data(text.utf8))
    }

    static func parseAnswer(_ data: Data) throws -> Recognition {
        let answer: Answer
        do {
            answer = try JSONDecoder().decode(Answer.self, from: data)
        } catch {
            throw RecognitionError.badResponse("JSON 格式不对")
        }
        let concealed = answer.concealed.compactMap(Tile.init(notation:))
        guard concealed.count == answer.concealed.count else {
            throw RecognitionError.badResponse("有无法识别的牌：\(answer.concealed.joined(separator: " "))")
        }
        var melds: [Meld] = []
        for m in answer.melds ?? [] {
            let tiles = m.tiles.compactMap(Tile.init(notation:))
            guard let meld = Meld.from(tiles: tiles, concealedKong: m.kind == "concealed_kong") else {
                throw RecognitionError.badResponse("副露拼不成一组：\(m.tiles.joined(separator: " "))")
            }
            melds.append(meld)
        }
        return Recognition(concealed: concealed, melds: melds, flowerCount: max(0, answer.flowers ?? 0), source: "Gemini")
    }

    static func encodeAnswer(_ recognition: Recognition) -> String {
        let answer = Answer(
            concealed: recognition.concealed.map(\.tile.notation),
            melds: recognition.melds.map { meld in
                let kind = meld.kind == .kong ? (meld.isConcealed ? "concealed_kong" : "kong") : meld.kind.rawValue
                return Answer.MeldAnswer(kind: kind, tiles: meld.tiles.map(\.notation))
            },
            flowers: recognition.flowerCount)
        let data = (try? JSONEncoder().encode(answer)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}
