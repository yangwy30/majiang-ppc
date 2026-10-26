import Foundation

/// 双读：两路识别同时跑，读得一样的牌直接用，不一样的牌标出来让用户选。
/// 研究里的模拟：端侧 + Gemini 一致的牌全部正确，不一致的平均要点 2–3 下。
public struct DualReadRecognizer: TileRecognizer {
    public let name = "双读"
    public var primary: TileRecognizer
    public var secondary: TileRecognizer

    public init(primary: TileRecognizer, secondary: TileRecognizer) {
        self.primary = primary
        self.secondary = secondary
    }

    public func recognize(_ request: RecognitionRequest) async throws -> Recognition {
        async let first = Result(catching: { try await primary.recognize(request) })
        async let second = Result(catching: { try await secondary.recognize(request) })
        switch (await first, await second) {
        case (.success(let a), .success(let b)):
            return Self.merge(a, b)
        case (.success(let a), .failure):
            return a
        case (.failure, .success(let b)):
            return b
        case (.failure(let error), .failure):
            throw error
        }
    }

    /// 合并两路结果。张数相同按位置比；张数不同时按多出来的牌比。
    public static func merge(_ a: Recognition, _ b: Recognition) -> Recognition {
        var merged = a
        merged.source = "双读"
        merged.flowerCount = max(a.flowerCount, b.flowerCount)
        if merged.melds.isEmpty { merged.melds = b.melds }

        let left = a.concealed.map(\.tile)
        let right = b.concealed.map(\.tile)
        if left.count == right.count {
            for i in left.indices where left[i] != right[i] {
                merged.concealed[i].alternatives = Array(Set(merged.concealed[i].alternatives + [right[i]])).sorted()
            }
        } else {
            // 只在 a 里出现的牌，候选是 b 里同花色、点数最近的多出来的牌
            var onlyInB = right
            var onlyInA: [Int] = []
            for (i, tile) in left.enumerated() {
                if let j = onlyInB.firstIndex(of: tile) { onlyInB.remove(at: j) } else { onlyInA.append(i) }
            }
            for i in onlyInA {
                let tile = left[i]
                let nearest = onlyInB.min { distance(tile, $0) < distance(tile, $1) }
                merged.concealed[i].alternatives = nearest.map { [$0] } ?? []
                merged.concealed[i].uncertain = true
            }
        }
        return merged
    }

    private static func distance(_ x: Tile, _ y: Tile) -> Int {
        x.suit == y.suit ? abs(x.rank - y.rank) : 100
    }
}

/// 规则校验：识别结果凑不成和牌时，带着原因让同一路识别再看一次（研究里这一步把判胡从 31/33 提到 33/33）。
public struct RuleCheckedRecognizer: TileRecognizer {
    public var base: TileRecognizer
    public var name: String { base.name }

    public init(base: TileRecognizer) {
        self.base = base
    }

    public func recognize(_ request: RecognitionRequest) async throws -> Recognition {
        let first = try await base.recognize(request)
        guard let feedback = Self.problem(with: first) else { return first }
        var retry = request
        retry.previous = first
        retry.feedback = feedback
        guard let second = try? await base.recognize(retry) else { return first }
        return Self.problem(with: second) == nil ? second : first
    }

    /// 读出的牌有明显问题时返回原因。
    public static func problem(with recognition: Recognition) -> String? {
        let hand = recognition.hand
        if !hand.overusedTiles.isEmpty {
            return "你读出的牌里 \(hand.overusedTiles.map(\.notation).joined(separator: " ")) 超过 4 张，这不可能。"
        }
        if !FanCalculator.isWinningShape(hand) {
            let count = hand.allTiles.count
            return "按国标规则，你读出的这 \(count) 张牌拼不成和牌。很可能有一两张牌认错了（常见是条子、饼子的点数差一，或漏读了被遮挡、切边的牌）。"
        }
        return nil
    }
}

/// 在两路读法不一致的牌里，挑出能和、番数最高的组合，标成推荐（确认页上的「这张才能和」）。
public enum RecognitionResolver {
    public struct Resolution: Hashable, Sendable {
        /// 每张需要确认的牌推荐的读法（下标同 `Recognition.concealed`）。
        public let recommended: [Int: Tile]
        public let result: ScoringResult?
    }

    public static func resolve(_ recognition: Recognition, context: WinContext, maxFlagged: Int = 6) -> Resolution {
        let flagged = recognition.concealed.indices.filter { recognition.concealed[$0].needsReview }
        guard !flagged.isEmpty, flagged.count <= maxFlagged else {
            return Resolution(recommended: [:], result: try? FanCalculator.score(recognition.hand, context: context).get())
        }

        var best: (choice: [Int: Tile], result: ScoringResult)?
        func search(_ k: Int, _ choice: [Int: Tile]) {
            if k == flagged.count {
                var tiles = recognition.concealed.map(\.tile)
                for (i, tile) in choice { tiles[i] = tile }
                let hand = Hand(melds: recognition.melds, concealed: tiles, winningTile: tiles.last)
                if case .success(let result) = FanCalculator.score(hand, context: context),
                   result.fanWithoutFlowers > (best?.result.fanWithoutFlowers ?? -1) {
                    best = (choice, result)
                }
                return
            }
            let index = flagged[k]
            for tile in recognition.concealed[index].candidates {
                var next = choice
                next[index] = tile
                search(k + 1, next)
            }
        }
        search(0, [:])
        return Resolution(recommended: best?.choice ?? [:], result: best?.result)
    }
}

extension Result where Failure == Error {
    init(catching body: () async throws -> Success) async {
        do { self = .success(try await body()) } catch { self = .failure(error) }
    }
}
