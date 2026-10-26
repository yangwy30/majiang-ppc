import CGuobiao

/// 照片看不出来、需要用户补充的和牌信息。
public struct WinContext: Hashable, Codable, Sendable {
    public var selfDrawn: Bool
    /// 和绝张。
    public var lastTileOfItsKind: Bool
    /// 自摸时为杠上开花，点炮时为抢杠和。
    public var kongInvolved: Bool
    /// 自摸时为妙手回春，点炮时为海底捞月。
    public var lastTileOfWall: Bool
    public var flowerCount: Int
    public var prevalentWind: Wind
    public var seatWind: Wind

    public init(selfDrawn: Bool = false, lastTileOfItsKind: Bool = false, kongInvolved: Bool = false,
                lastTileOfWall: Bool = false, flowerCount: Int = 0,
                prevalentWind: Wind = .east, seatWind: Wind = .east) {
        self.selfDrawn = selfDrawn
        self.lastTileOfItsKind = lastTileOfItsKind
        self.kongInvolved = kongInvolved
        self.lastTileOfWall = lastTileOfWall
        self.flowerCount = flowerCount
        self.prevalentWind = prevalentWind
        self.seatWind = seatWind
    }

    var flag: UInt8 {
        var flag = UInt8(selfDrawn ? GB_FLAG_SELF_DRAWN : GB_FLAG_DISCARD)
        if lastTileOfItsKind { flag |= UInt8(GB_FLAG_LAST_TILE) }
        if kongInvolved { flag |= UInt8(GB_FLAG_KONG_INVOLVED) }
        if lastTileOfWall { flag |= UInt8(GB_FLAG_WALL_LAST) }
        return flag
    }
}

public struct FanEntry: Hashable, Codable, Sendable {
    public let fan: Fan
    public let count: Int
    public var points: Int { fan.points * count }

    public init(fan: Fan, count: Int) {
        self.fan = fan
        self.count = count
    }
}

/// 算番结果。花牌番单独记，因为它不计入 8 番起和。
public struct ScoringResult: Hashable, Codable, Sendable {
    /// 番种明细，不含花牌，按番值从大到小。
    public let fans: [FanEntry]
    public let flowerFan: Int

    public var fanWithoutFlowers: Int { fans.reduce(0) { $0 + $1.points } }
    public var totalFan: Int { fanWithoutFlowers + flowerFan }

    public func meetsMinimum(_ minimum: Int = 8) -> Bool { fanWithoutFlowers >= minimum }

    public func contains(_ fan: Fan) -> Bool { fans.contains { $0.fan == fan } }
}

public enum ScoringError: Error, Hashable, Sendable {
    case wrongTileCount
    case tileMoreThanFour
    case notAWin

    public var message: String {
        switch self {
        case .wrongTileCount: "张数不对：立牌加副露应该是 14 张（每个杠多 1 张）"
        case .tileMoreThanFour: "同一种牌超过了 4 张"
        case .notAWin: "凑不成和牌：不是 4 组面子加 1 对将，也不是七对、十三幺、全不靠、组合龙"
        }
    }
}

/// 国标算番。底层是 ChineseOfficialMahjongHelper 的 C++ 实现。
public enum FanCalculator {
    /// 计算一手和牌的番种。
    public static func score(_ hand: Hand, context: WinContext) -> Result<ScoringResult, ScoringError> {
        guard hand.hasValidTileCount else { return .failure(.wrongTileCount) }
        guard hand.overusedTiles.isEmpty else { return .failure(.tileMoreThanFour) }
        guard let winIndex = hand.concealed.lastIndex(of: hand.winningTile) else { return .failure(.notAWin) }

        var standing = hand.concealed
        standing.remove(at: winIndex)
        let melds = hand.melds.map(\.cMeld)
        let codes = standing.map(\.code)

        let size = Int(gb_fan_table_size())
        var table = [UInt16](repeating: 0, count: size)
        // 花牌番自己加，库里传 0。
        let code = melds.withUnsafeBufferPointer { meldPtr in
            codes.withUnsafeBufferPointer { tilePtr in
                table.withUnsafeMutableBufferPointer { tablePtr in
                    gb_calculate(meldPtr.baseAddress, Int32(melds.count),
                                 tilePtr.baseAddress, Int32(codes.count),
                                 hand.winningTile.code, 0, context.flag,
                                 Int32(context.prevalentWind.rawValue), Int32(context.seatWind.rawValue),
                                 tablePtr.baseAddress)
                }
            }
        }

        switch code {
        case GB_ERROR_WRONG_TILES_COUNT: return .failure(.wrongTileCount)
        case GB_ERROR_TILE_MORE_THAN_4: return .failure(.tileMoreThanFour)
        case ..<1: return .failure(.notAWin)
        default: break
        }

        let fans = table.enumerated().compactMap { index, count -> FanEntry? in
            guard count > 0, let fan = Fan(rawValue: index), fan != .flowerTiles else { return nil }
            return FanEntry(fan: fan, count: Int(count))
        }
        .sorted { ($0.fan.points, -$0.fan.rawValue) > ($1.fan.points, -$1.fan.rawValue) }

        return .success(ScoringResult(fans: fans, flowerFan: max(0, context.flowerCount)))
    }

    /// 能和的牌（不管够不够 8 番）。`melds` 加 `standing` 必须是 13 张。
    public static func waitingTiles(melds: [Meld], standing: [Tile]) -> [Tile] {
        guard standing.count + 3 * melds.count == 13 else { return [] }
        let cMelds = melds.map(\.cMeld)
        let codes = standing.map(\.code)
        var out = [UInt8](repeating: 0, count: 34)
        let n = cMelds.withUnsafeBufferPointer { meldPtr in
            codes.withUnsafeBufferPointer { tilePtr in
                out.withUnsafeMutableBufferPointer { outPtr in
                    gb_waiting_tiles(meldPtr.baseAddress, Int32(cMelds.count),
                                     tilePtr.baseAddress, Int32(codes.count), outPtr.baseAddress)
                }
            }
        }
        return out.prefix(Int(n)).compactMap(Tile.init(code:))
    }

    /// 牌型是否成和（不看番数）。和的那张取哪张不影响这个判断。
    public static func isWinningShape(_ hand: Hand) -> Bool {
        guard hand.hasValidTileCount, hand.overusedTiles.isEmpty else { return false }
        var standing = hand.concealed
        let last = standing.removeLast()
        return waitingTiles(melds: hand.melds, standing: standing).contains(last)
    }
}

extension Meld {
    var cMeld: gb_meld_t {
        switch kind {
        case .chow:
            // 库里顺子记中间那张，吃的那张默认第 1 张。
            gb_meld_t(type: UInt8(GB_MELD_CHOW), tile: tile.code + 1, offer: 1)
        case .pung:
            gb_meld_t(type: UInt8(GB_MELD_PUNG), tile: tile.code, offer: 1)
        case .kong:
            gb_meld_t(type: UInt8(GB_MELD_KONG), tile: tile.code, offer: isConcealed ? 0 : 1)
        }
    }
}
