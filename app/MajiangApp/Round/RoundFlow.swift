import SwiftUI
import MajiangKit

enum RoundStep: Hashable {
    case confirm
    case notWin
    case details
    case result
}

/// 记一局的草稿：谁和了 → 照片 → 确认牌面 → 怎么和的 → 番数与收付。
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
    var discarder: Int?
    var specials: Set<SpecialWin> = []
    var flowerCount = 0

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
            steps = [.confirm]
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
        steps = [.confirm]
    }

    // MARK: 修改

    func choose(_ tile: Tile, at index: Int) {
        guard tiles.indices.contains(index) else { return }
        tiles[index].tile = tile
        tiles[index].alternatives = []
        tiles[index].uncertain = false
    }

    /// 补一张牌。补的是漏读的牌，和张不跟着跳；还没有和张时才用这张。
    func append(_ tile: Tile) {
        tiles.append(RecognizedTile(tile: tile))
        if winningIndex == nil { winningIndex = tiles.indices.last }
    }

    func remove(at index: Int) {
        guard tiles.indices.contains(index) else { return }
        tiles.remove(at: index)
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

    /// 一键采纳所有推荐读法。
    func acceptRecommendations() {
        for (index, tile) in recommended { choose(tile, at: index) }
        recommended = [:]
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

    /// 点炮的默认人选：和牌者的上家。
    func defaultDiscarder() -> Int {
        let hand = game.currentHandIndex
        let seating = game.seating(ofRound: game.roundIndex(ofHand: hand))
        let position = game.position(of: winner, inHand: hand)
        return seating[(position + 3) % 4]
    }
}
