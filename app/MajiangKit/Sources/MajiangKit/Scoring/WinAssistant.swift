import Foundation

/// 「怎么和的」页上的特殊情况，以及在当前条件下能不能选。
public enum SpecialWin: String, CaseIterable, Codable, Sendable {
    case lastTileOfItsKind   // 和绝张
    case kongReplacement     // 杠上开花（自摸）
    case lastTileDraw        // 妙手回春（自摸）
    case lastTileClaim       // 海底捞月（点炮）
    case robbingTheKong      // 抢杠和（点炮）

    public var name: String {
        switch self {
        case .lastTileOfItsKind: "和绝张"
        case .kongReplacement: "杠上开花"
        case .lastTileDraw: "妙手回春"
        case .lastTileClaim: "海底捞月"
        case .robbingTheKong: "抢杠和"
        }
    }

    /// 不能选时给一句原因；能选时返回 nil。
    public func unavailableReason(hand: Hand, selfDrawn: Bool) -> String? {
        switch self {
        case .lastTileOfItsKind:
            let held = hand.concealed.filter { $0 == hand.winningTile }.count
            return held > 1 ? "手里已经有这张牌，和的不可能是最后一张" : nil
        case .kongReplacement:
            if !selfDrawn { return "只有自摸才可能" }
            return hand.kongCount == 0 ? "没有杠" : nil
        case .lastTileDraw:
            return selfDrawn ? nil : "只有自摸才可能"
        case .lastTileClaim:
            return selfDrawn ? "只有点炮才可能" : nil
        case .robbingTheKong:
            if selfDrawn { return "只有点炮才可能" }
            let held = hand.allTiles.filter { $0 == hand.winningTile }.count
            return held > 1 ? "别人加杠的牌只剩这一张，手里不能再有" : nil
        }
    }

    /// 把选中的特殊情况写进 WinContext。互斥的（杠上开花和妙手回春）由界面保证只选一个。
    public static func apply(_ selected: Set<SpecialWin>, to context: inout WinContext) {
        context.lastTileOfItsKind = selected.contains(.lastTileOfItsKind)
        context.kongInvolved = selected.contains(.kongReplacement) || selected.contains(.robbingTheKong)
        context.lastTileOfWall = selected.contains(.lastTileDraw) || selected.contains(.lastTileClaim)
    }
}

/// 不成和时的改牌建议：「把第 3 张 4条 改成 5条 就能和」。
public struct FixSuggestion: Hashable, Sendable {
    /// 在 `Hand.concealed` 里的位置；nil 表示要补一张牌（少读了一张）。
    public let index: Int?
    public let from: Tile?
    public let to: Tile
    public let result: ScoringResult

    public var text: String {
        if let from { "把 \(from.displayName) 改成 \(to.displayName)，就是 \(result.fanWithoutFlowers) 番" }
        else { "补一张 \(to.displayName)，就是 \(result.fanWithoutFlowers) 番" }
    }
}

public enum WinAssistant {
    /// 找出改一张（或补一张）牌就能够起和的改法，最可能认错的排前面。
    /// 认错多半是同花色点数差一点（5条 和 4条、6条），所以按点数差排序。
    public static func fixSuggestions(for hand: Hand, context: WinContext,
                                      minimumFan: Int = 8, limit: Int = 3) -> [FixSuggestion] {
        var found: [(cost: Int, suggestion: FixSuggestion)] = []

        if hand.concealed.count + 3 * hand.melds.count == 13 {
            // 少一张：补哪张能和
            for tile in FanCalculator.waitingTiles(melds: hand.melds, standing: hand.concealed) {
                let candidate = Hand(melds: hand.melds, concealed: hand.concealed + [tile], winningTile: tile)
                if case .success(let result) = FanCalculator.score(candidate, context: context), result.meetsMinimum(minimumFan) {
                    found.append((0, FixSuggestion(index: nil, from: nil, to: tile, result: result)))
                }
            }
        } else {
            for (index, original) in hand.concealed.enumerated() {
                for tile in Tile.all where tile != original {
                    var concealed = hand.concealed
                    concealed[index] = tile
                    let winning = index == hand.concealed.lastIndex(of: hand.winningTile) ? tile : hand.winningTile
                    let candidate = Hand(melds: hand.melds, concealed: concealed, winningTile: winning)
                    guard case .success(let result) = FanCalculator.score(candidate, context: context),
                          result.meetsMinimum(minimumFan) else { continue }
                    let cost = original.suit == tile.suit ? abs(original.rank - tile.rank) : 20
                    found.append((cost, FixSuggestion(index: index, from: original, to: tile, result: result)))
                }
            }
        }

        var seen = Set<String>()
        return found
            .sorted { ($0.cost, -$0.suggestion.result.fanWithoutFlowers) < ($1.cost, -$1.suggestion.result.fanWithoutFlowers) }
            .map(\.suggestion)
            .filter { seen.insert($0.text).inserted }
            .prefix(limit)
            .map { $0 }
    }

    /// 一句话说明为什么不成和。
    public static func explain(_ hand: Hand, context: WinContext, minimumFan: Int = 8) -> String {
        switch FanCalculator.score(hand, context: context) {
        case .failure(let error):
            if error == .tileMoreThanFour {
                let names = hand.overusedTiles.map(\.displayName).joined(separator: "、")
                return "\(names) 超过了 4 张，一定有牌认错了"
            }
            return error.message
        case .success(let result) where !result.meetsMinimum(minimumFan):
            return "牌型成立，但只有 \(result.fanWithoutFlowers) 番，不够 \(minimumFan) 番起和（花牌不算）"
        case .success:
            return "牌型成立"
        }
    }
}
