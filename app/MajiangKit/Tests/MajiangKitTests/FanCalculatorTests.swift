import XCTest
@testable import MajiangKit
import CGuobiao

final class FanCalculatorTests: XCTestCase {
    func testFanTableMatchesLibrary() {
        XCTAssertEqual(Fan.allCases.count, Int(gb_fan_table_size()) - 1)
        XCTAssertEqual(Fan.bigFourWinds.points, 88)
        XCTAssertEqual(Fan.chickenHand.points, 8)
        XCTAssertEqual(Fan.flowerTiles.points, 1)
        XCTAssertEqual(Fan.concealedKongAndMeldedKong.points, 5)
        XCTAssertEqual(Fan.selfDrawn.points, 1)
        XCTAssertEqual(Fan.allPungs.points, 6)
    }

    /// 64 条 mahjong-omakase 番种用例：每手牌都应该算出用例名字里的番种。
    func testOmakaseFanCases() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "guobiao-fan-cases_mahjong-omakase", withExtension: "json",
                                                  subdirectory: "Fixtures"))
        let cases = try JSONDecoder().decode([OmakaseCase].self, from: Data(contentsOf: url))
        XCTAssertEqual(cases.count, 64)

        // 这 3 条是用例本身有问题，算番库的结果是对的：
        let knownBadCases: Set<String> = [
            "t234w678t456b123w11",   // 「幺九刻」：手里没有幺九刻，11万是将
            "t123w789b111z666t99",   // 「暗杠」：没有标暗杠，111饼只是暗刻
            "pb7 w8 lt111z444b44",   // 「和绝张」：手里已经有一张 4饼 再单钓 4饼，不可能是绝张
        ]
        var failures: [String] = []
        for c in cases where !knownBadCases.contains(c.hand) {
            let hand = try XCTUnwrap(OmakaseNotation.parse(c.hand), c.hand)
            var context = WinContext(selfDrawn: c.opts.contains("zimo"))
            let expected = OmakaseNotation.fan(named: c.name)
            switch expected {
            case .lastTileDraw:
                context.selfDrawn = true
                context.lastTileOfWall = true
            case .lastTile:
                context.lastTileOfItsKind = true
            default:
                break
            }
            switch FanCalculator.score(hand, context: context) {
            case .success(let result):
                if let expected, !result.contains(expected) {
                    failures.append("\(c.name) \(c.hand): 算出 \(result.fans.map(\.fan.name))")
                }
            case .failure(let error):
                failures.append("\(c.name) \(c.hand): \(error)")
            }
        }
        XCTAssertEqual(failures, [])
    }

    func testFullFlushExample() throws {
        // 用户流程 mockup 里的清一色：1112233445566 7 饼（ground truth g01）
        let tiles = Tile.parseList("1p 1p 1p 2p 2p 3p 3p 4p 4p 5p 5p 6p 6p 7p")
        let hand = Hand(concealed: tiles)
        let result = try FanCalculator.score(hand, context: WinContext(selfDrawn: true)).get()
        XCTAssertTrue(result.contains(.fullFlush))
        XCTAssertTrue(result.meetsMinimum())
    }

    func testFlowersDoNotCountTowardMinimum() throws {
        // 平和 + 断幺 + 喜相逢 ... 不够 8 番
        let hand = Hand(melds: [.chow(Tile(.characters, 2))!],
                        concealed: Tile.parseList("345p 678s 234s 66m"),
                        winningTile: Tile(.characters, 6))
        let result = try FanCalculator.score(hand, context: WinContext(flowerCount: 5)).get()
        XCTAssertLessThan(result.fanWithoutFlowers, 8)
        XCTAssertEqual(result.flowerFan, 5)
        XCTAssertFalse(result.meetsMinimum())
        XCTAssertFalse(result.contains(.flowerTiles))
    }

    func testErrors() {
        let short = Hand(concealed: Tile.parseList("123m456m789m11p"))
        XCTAssertEqual(FanCalculator.score(short, context: WinContext()).failure, .wrongTileCount)

        let five = Hand(concealed: Tile.parseList("11111m456m789m123p"))
        XCTAssertEqual(FanCalculator.score(five, context: WinContext()).failure, .tileMoreThanFour)

        let noWin = Hand(concealed: Tile.parseList("13579m2468p135s东南"))
        XCTAssertEqual(FanCalculator.score(noWin, context: WinContext()).failure, .notAWin)
    }

    func testWindPungsUseSeatAndPrevalentWind() throws {
        let hand = Hand(concealed: Tile.parseList("南南南 西西西 123m 7m8m9m 1p1p"), winningTile: Tile(.dots, 1))
        let context = WinContext(prevalentWind: .south, seatWind: .west)
        let result = try FanCalculator.score(hand, context: context).get()
        XCTAssertTrue(result.contains(.prevalentWind))
        XCTAssertTrue(result.contains(.seatWind))
    }

    func testWaitingTiles() {
        // 九莲宝灯听九面
        let waits = FanCalculator.waitingTiles(melds: [], standing: Tile.parseList("1112345678999m"))
        XCTAssertEqual(waits, (1...9).map { Tile(.characters, $0) })
    }

    /// 测试照片的标准答案：规则引擎判断的「和没和」要和标准答案一致。
    func testGroundTruthWinDecisions() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "ground_truth", withExtension: "json", subdirectory: "Fixtures"))
        let file = try JSONDecoder().decode(GroundTruthFile.self, from: Data(contentsOf: url))
        var checked = 0
        for photo in file.photos {
            guard let win = photo.win else { continue }
            let tiles = Tile.parseList(photo.tiles)
            let isWin = Hand.inferred(fromFlat: tiles).map(FanCalculator.isWinningShape) ?? false
            XCTAssertEqual(isWin, win, "\(photo.id): \(photo.tiles)")
            checked += 1
        }
        XCTAssertGreaterThan(checked, 30)
    }
}

private struct OmakaseCase: Decodable {
    let name: String
    let hand: String
    let opts: String
}

private struct GroundTruthFile: Decodable {
    struct Photo: Decodable {
        let id: String
        let tiles: String
        let win: Bool?
    }
    let photos: [Photo]
}

extension Result {
    var failure: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

/// mahjong-omakase 的记法：w 万、b 饼、t 条、z 字（1–7 东南西北中发白）；
/// a 暗杠、g 明杠、p 碰、c 吃（写顺子第一张）、l 立牌（最后一张是和张）。类型和花色都会延续。
enum OmakaseNotation {
    static func parse(_ text: String) -> Hand? {
        enum Mode { case standing, concealedKong, kong, pung, chow }
        var mode = Mode.standing
        var suit: Suit?
        var melds: [Meld] = []
        var standing: [Tile] = []

        for ch in text {
            switch ch {
            case "a": mode = .concealedKong
            case "g": mode = .kong
            case "p": mode = .pung
            case "c": mode = .chow
            case "l": mode = .standing
            case "w": suit = .characters
            case "b": suit = .dots
            case "t": suit = .bamboo
            case "z": suit = .honors
            case "1"..."9":
                guard let suit, let tile = Tile(suit: suit, rank: ch.wholeNumberValue!) else { return nil }
                switch mode {
                case .standing: standing.append(tile)
                case .concealedKong: melds.append(.kong(tile, concealed: true))
                case .kong: melds.append(.kong(tile, concealed: false))
                case .pung: melds.append(.pung(tile))
                case .chow:
                    guard let meld = Meld.chow(tile) else { return nil }
                    melds.append(meld)
                }
            default:
                continue
            }
        }
        guard let last = standing.last else { return nil }
        return Hand(melds: melds, concealed: standing, winningTile: last)
    }

    static func fan(named name: String) -> Fan? {
        let aliases = ["推不到": "推不倒"]
        let target = aliases[name] ?? name
        return Fan.allCases.first { $0.name == target }
    }
}
