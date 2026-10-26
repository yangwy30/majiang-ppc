import SwiftUI
import MajiangKit

enum RoundStep: Hashable {
    case check
}

/// 记一局的草稿：谁和了 → 拍照 → 核对（牌面 + 怎么和的）→ 结果。
@MainActor
@Observable
final class RoundFlow {
    let game: Game
    var steps: [RoundStep] = []

    var winner: Int
    var photo: UIImage?
    var isRecognizing = false
    var recognitionError: String?
    var source = ""
    /// 识别时的说明，比如有牌没认出来。
    var notes: [String] = []

    /// 立牌（含和张），可逐张修改。
    var tiles: [RecognizedTile] = []
    var melds: [Meld] = []
    /// 和的是 `tiles` 里的哪一张。
    var winningIndex: Int?
    /// 需要确认的牌里，规则引擎推荐的读法。
    var recommended: [Int: Tile] = [:]

    var selfDrawn = true
    /// 点炮的人。不预先猜，让用户自己点，免得记错人。
    var discarder: Int?
    var specials: Set<SpecialWin> = []
    var flowerCount = 0
    var showResult = false

    @ObservationIgnored private var suggestionCache: (hand: Hand, context: WinContext, value: [FixSuggestion])?

    init(game: Game) {
        self.game = game
        self.winner = game.dealer
    }

    // MARK: 手牌

    var hand: Hand {
        let concealed = tiles.map(\.tile)
        let index = winningIndex.flatMap { concealed.indices.contains($0) ? $0 : nil } ?? concealed.indices.last
        return Hand(melds: melds, concealed: concealed, winningTile: index.map { concealed[$0] })
    }

    var context: WinContext {
        var context = game.winContext(for: winner)
        context.selfDrawn = selfDrawn
        context.flowerCount = game.rules.includeFlowers ? flowerCount : 0
        SpecialWin.apply(specials.filter { isAvailable($0) }, to: &context)
        return context
    }

    var scoring: Result<ScoringResult, ScoringError> { FanCalculator.score(hand, context: context) }

    /// 牌型成立并且够起和番。
    var isValidWin: Bool {
        if case .success(let result) = scoring { return result.meetsMinimum(game.rules.minimumFan) }
        return false
    }

    var pendingReviewCount: Int { tiles.filter(\.needsReview).count }

    /// 第一张还拿不准的牌，核对页一次问一张。
    var firstPending: Int? { tiles.firstIndex(where: \.needsReview) }

    /// 底部按钮不能点时的原因；nil 表示可以看结果了。
    var blockedReason: String? {
        if tiles.isEmpty { return "先把牌加上" }
        if pendingReviewCount > 0 { return "还有 \(pendingReviewCount) 张没确认" }
        switch scoring {
        case .failure:
            return "先把牌改对"
        case .success(let result) where !result.meetsMinimum(game.rules.minimumFan):
            return "不够 \(game.rules.minimumFan) 番，和不了"
        case .success:
            break
        }
        if !selfDrawn && (discarder == nil || discarder == winner) { return "选一下是谁打的" }
        return nil
    }

    /// 改牌建议（算一次要试几百种改法，按手牌缓存）。
    var suggestions: [FixSuggestion] {
        let hand = hand, context = context
        if let cache = suggestionCache, cache.hand == hand, cache.context == context { return cache.value }
        let value = WinAssistant.fixSuggestions(for: hand, context: context, minimumFan: game.rules.minimumFan)
        suggestionCache = (hand, context, value)
        return value
    }

    /// 把第 `index` 张换成 `tile` 以后能不能和（只看这一张，别的牌按现在的读法）。
    func wins(with tile: Tile, at index: Int) -> Bool {
        guard tiles.indices.contains(index) else { return false }
        var concealed = tiles.map(\.tile)
        concealed[index] = tile
        let winning = winningIndex.flatMap { concealed.indices.contains($0) ? concealed[$0] : nil } ?? concealed.last
        let candidate = Hand(melds: melds, concealed: concealed, winningTile: winning)
        if case .success(let result) = FanCalculator.score(candidate, context: context) {
            return result.meetsMinimum(game.rules.minimumFan)
        }
        return false
    }

    func isAvailable(_ special: SpecialWin) -> Bool {
        special.unavailableReason(hand: hand, selfDrawn: selfDrawn) == nil
    }

    // MARK: 识别

    func recognize(with recognizer: TileRecognizer) async {
        guard let photo, let data = photo.jpegData(compressionQuality: 0.85) else { return }
        isRecognizing = true
        recognitionError = nil
        defer { isRecognizing = false }
        do {
            let recognition = try await recognizer.recognize(RecognitionRequest(image: data))
            load(recognition)
            steps = [.check]
        } catch let error as RecognitionError {
            recognitionError = error.message
        } catch {
            recognitionError = error.localizedDescription
        }
    }

    func load(_ recognition: Recognition) {
        tiles = recognition.concealed
        melds = recognition.melds
        flowerCount = recognition.flowerCount
        source = recognition.source
        notes = recognition.notes
        winningIndex = tiles.indices.last
        recommended = RecognitionResolver.resolve(recognition, context: context,
                                                  minimumFan: game.rules.minimumFan).recommended
    }

    /// 跳过拍照：从空手牌开始手动输入。
    func startManualEntry() {
        load(Recognition(concealed: [RecognizedTile](), source: "手动输入"))
        steps = [.check]
    }

    // MARK: 修改

    func choose(_ tile: Tile, at index: Int) {
        guard tiles.indices.contains(index) else { return }
        tiles[index].tile = tile
        tiles[index].alternatives = []
        tiles[index].uncertain = false
        recommended[index] = nil
    }

    /// 补一张牌。补的是漏读的牌，和张不跟着跳；还没有和张时才用这张。
    func append(_ tile: Tile) {
        tiles.append(RecognizedTile(tile: tile))
        if winningIndex == nil { winningIndex = tiles.indices.last }
    }

    /// 在第 `index` 张后面插一张（漏读了中间的牌）。
    func insert(_ tile: Tile, after index: Int) {
        guard tiles.indices.contains(index) else { return append(tile) }
        tiles.insert(RecognizedTile(tile: tile), at: index + 1)
        if let w = winningIndex, w > index { winningIndex = w + 1 }
        // 推荐读法按位置记的，位置变了就作废
        recommended = [:]
    }

    func remove(at index: Int) {
        guard tiles.indices.contains(index) else { return }
        tiles.remove(at: index)
        recommended = [:]
        // 和张在被删的牌后面时下标前移；删的就是和张时改用最右一张
        if let w = winningIndex {
            if w > index { winningIndex = w - 1 }
            else if w == index { winningIndex = tiles.indices.last }
        }
    }

    func apply(_ suggestion: FixSuggestion) {
        if let index = suggestion.index {
            choose(suggestion.to, at: index)
        } else {
            append(suggestion.to)
        }
    }

    // MARK: 记账

    var winRecord: WinRecord? {
        guard case .success(let result) = scoring, result.meetsMinimum(game.rules.minimumFan) else { return nil }
        // 拍照页回头改了和牌者时，之前选的点炮者可能就是和牌者本人，这时不能记账
        if !selfDrawn && (discarder == nil || discarder == winner) { return nil }
        return WinRecord(winner: winner, discarder: selfDrawn ? nil : discarder, hand: hand, context: context, result: result)
    }

    var deltas: [Int]? {
        guard let record = winRecord else { return nil }
        return Payment.winDeltas(winner: winner, discarder: record.discarder,
                                 totalFan: record.totalFan, basePoints: game.rules.basePoints)
    }
}
