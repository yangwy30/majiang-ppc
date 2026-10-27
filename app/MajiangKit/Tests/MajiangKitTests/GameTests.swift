import XCTest
@testable import MajiangKit

final class GameTests: XCTestCase {
    private func makeGame(swap: Bool = false) -> Game {
        var rules = GameRules()
        rules.swapSeatsEachRound = swap
        rules.yuanPerPoint = 0.5
        return Game(players: ["杨", "小周", "阿乐", "老王"].map { Player(name: $0) }, rules: rules)
    }

    private func win(_ winner: Int, discarder: Int?, fan: Int, flowers: Int = 0) -> WinRecord {
        WinRecord(winner: winner, discarder: discarder, hand: nil, context: WinContext(flowerCount: flowers),
                  fans: [FanEntry(fan: .chickenHand, count: 1)] + Array(repeating: FanEntry(fan: .selfDrawn, count: 1), count: fan - 8),
                  flowerFan: flowers)
    }

    func testPayments() {
        XCTAssertEqual(Payment.winDeltas(winner: 0, discarder: nil, totalFan: 10, basePoints: 8), [54, -18, -18, -18])
        XCTAssertEqual(Payment.winDeltas(winner: 2, discarder: 1, totalFan: 10, basePoints: 8), [-8, -18, 34, -8])
        XCTAssertEqual(Payment.falseWinDeltas(offender: 3, penalty: 10), [10, 10, 10, -30])
    }

    func testHouseRulePayments() {
        // 封顶 64：88 番按 64 算
        XCTAssertEqual(Payment.winDeltas(winner: 3, discarder: 2, totalFan: 88, basePoints: 8, fanCap: 64), [-8, -8, -72, 88])
        // 只有点炮的人付
        XCTAssertEqual(Payment.winDeltas(winner: 2, discarder: 1, totalFan: 10, basePoints: 8, onlyDiscarderPays: true),
                       [0, -18, 18, 0])
        // 自摸不受「只有点炮的人付」影响
        XCTAssertEqual(Payment.winDeltas(winner: 0, discarder: nil, totalFan: 10, basePoints: 5, onlyDiscarderPays: true),
                       [45, -15, -15, -15])
    }

    func testPresets() {
        var rules = GameRules.standard
        rules.yuanPerPoint = 2
        XCTAssertTrue(rules.scoresLike(.standard), "1 分几元不算家规")
        rules.fanCap = 64
        XCTAssertFalse(rules.scoresLike(.standard))
        XCTAssertEqual(rules.cappedFan(88), 64)
        XCTAssertEqual(GameRules.beginner.minimumFan, 1)
    }

    func testChangingRulesRecomputesEveryHand() throws {
        var game = makeGame()
        try game.recordWin(win(0, discarder: nil, fan: 32))
        try game.recordWin(win(2, discarder: 1, fan: 8))
        try game.recordDraw()
        try game.recordWin(win(3, discarder: nil, fan: 30))
        XCTAssertEqual(game.scores, [74, -94, -46, 66])

        var rules = game.rules
        rules.basePoints = 5
        let preview = try game.changingRules(rules)
        XCTAssertEqual(preview.scores, [71, -85, -49, 63])
        XCTAssertEqual(game.scores, [74, -94, -46, 66], "预览不改原来的牌局")

        rules.fanCap = 16
        try game.changeRules(rules)
        XCTAssertEqual(game.scores, [63 - 5 - 21, -21 - 13 - 21, -21 + 23 - 21, -21 - 5 + 63])
        XCTAssertEqual(game.scores.reduce(0, +), 0)

        // 起和调高：前面不够番的和牌留着，标出来
        rules.minimumFan = 10
        try game.changeRules(rules)
        XCTAssertEqual(game.records.count, 4)
        XCTAssertEqual(game.winsBelowMinimum.map(\.handIndex), [1])

        // 打了 4 局，不能改成只打 0 圈
        rules.totalHands = 0
        XCTAssertThrowsError(try game.changeRules(rules))
    }

    func testRulesRememberedPerGroupOfPlayers() {
        var archive = GameArchive()
        var house = GameRules()
        house.fanCap = 64
        archive.start(Game(players: ["杨", "阿强", "莉莉", "小张"].map { Player(name: $0) }, rules: house,
                           startedAt: Date(timeIntervalSince1970: 100)))
        archive.start(Game(players: ["杨", "小周", "阿乐", "老王"].map { Player(name: $0) },
                           startedAt: Date(timeIntervalSince1970: 200)))
        XCTAssertEqual(archive.lastRules(forPlayers: ["小张", "杨", "莉莉", "阿强"])?.fanCap, 64, "座位换了也认得")
        XCTAssertNil(archive.lastRules(forPlayers: ["杨", "阿强", "莉莉", "老王"]))
    }

    func testOldRulesWithoutHouseRuleFieldsStillLoad() throws {
        let json = #"{"yuanPerPoint":1,"basePoints":8,"minimumFan":8,"includeFlowers":true}"#
        let rules = try JSONDecoder().decode(GameRules.self, from: Data(json.utf8))
        XCTAssertEqual(rules.fanCap, 0)
        XCTAssertFalse(rules.onlyDiscarderPays)
    }

    func testDealerAndWindsRotateWithoutSwap() {
        var game = makeGame()
        XCTAssertEqual(game.dealer, 0)
        XCTAssertEqual(game.prevalentWind, .east)
        XCTAssertEqual((0..<4).map { game.seatWind(of: $0) }, [.east, .south, .west, .north])

        try! game.recordDraw()
        XCTAssertEqual(game.dealer, 1)
        XCTAssertEqual((0..<4).map { game.seatWind(of: $0) }, [.north, .east, .south, .west])

        for _ in 0..<3 { try! game.recordDraw() }
        XCTAssertEqual(game.currentHandIndex, 4)
        XCTAssertEqual(game.prevalentWind, .south)
        XCTAssertEqual(game.dealer, 0)
    }

    func testSeatSwapEachRound() {
        let game = makeGame(swap: true)
        // 南圈第一局：开局坐南位的小周换到东位，当庄
        XCTAssertEqual(game.dealer(ofHand: 4), 1)
        XCTAssertEqual(game.seatWind(of: 1, inHand: 4), .east)
        XCTAssertEqual(game.seatWind(of: 0, inHand: 4), .south)
        // 每一圈每个人都当一次庄
        for round in 0..<4 {
            XCTAssertEqual(Set((0..<4).map { game.dealer(ofHand: round * 4 + $0) }), [0, 1, 2, 3])
        }
    }

    func testRecordingAndLedger() throws {
        var game = makeGame()
        try game.recordWin(win(0, discarder: nil, fan: 10))
        try game.recordWin(win(2, discarder: 1, fan: 8, flowers: 2))
        try game.recordFalseWin(offender: 3)
        XCTAssertEqual(game.currentHandIndex, 2, "错和不推进局数")
        XCTAssertEqual(game.scores, [54 - 8 + 10, -18 - 18 + 10, -18 + 34 + 10, -18 - 8 - 30])
        XCTAssertEqual(game.scores.reduce(0, +), 0)
        XCTAssertEqual(game.money(forPoints: game.scores[0]), 28)
        XCTAssertEqual(game.biggestWin?.win.winner, 0)

        game.undoLast()
        XCTAssertEqual(game.records.count, 2)
    }

    func testRejectsInvalidWins() {
        var game = makeGame()
        XCTAssertThrowsError(try game.recordWin(win(0, discarder: 0, fan: 8)))
        var low = win(0, discarder: 1, fan: 8)
        low.fans = [FanEntry(fan: .allTypes, count: 1)]
        low.flowerFan = 4
        XCTAssertThrowsError(try game.recordWin(low)) { error in
            XCTAssertEqual(error as? GameError, .belowMinimumFan(6))
        }
        XCTAssertThrowsError(try game.recordManual(deltas: [1, 2, 3, 4]))
    }

    func testGameFinishesAfterSixteenHands() throws {
        var game = makeGame()
        for _ in 0..<16 { try game.recordDraw() }
        XCTAssertTrue(game.isFinished)
        XCTAssertThrowsError(try game.recordDraw())
    }

    func testEditingAnEarlierWinRecomputesTheLedger() throws {
        var game = makeGame()
        let first = try game.recordWin(win(0, discarder: 1, fan: 10))
        try game.recordWin(win(2, discarder: nil, fan: 8))
        // 第一局其实是阿乐和、老王点炮
        var fixed = win(2, discarder: 3, fan: 10)
        fixed.context = game.records[0].outcome.win!.context
        try game.replace(first.id, with: .win(fixed))
        XCTAssertEqual(game.records[0].id, first.id)
        XCTAssertEqual(game.records[0].deltas, [-8, -8, 34, -18])
        XCTAssertEqual(game.records[1].deltas, [-16, -16, 48, -16], "后面的局不受影响")
        XCTAssertEqual(game.scores, [-24, -24, 82, -34])
        XCTAssertEqual(game.records[0].outcome.win?.context.seatWind, .west, "门风跟着和牌的人换")
    }

    func testChangingAWinToAFalseWinRenumbersLaterHands() throws {
        var game = makeGame()
        let first = try game.recordWin(win(0, discarder: 1, fan: 8))
        try game.recordDraw()
        try game.recordWin(win(1, discarder: nil, fan: 8))
        try game.replace(first.id, with: .falseWin(offender: 0))
        XCTAssertEqual(game.records.map(\.handIndex), [0, 0, 1], "错和不算一局，后面的局往前挪")
        XCTAssertEqual(game.currentHandIndex, 2)
        XCTAssertEqual(game.records[0].deltas, [-30, 10, 10, 10])
        XCTAssertEqual(game.scores.reduce(0, +), 0)
    }

    func testRemovingAHandMovesLaterWinsAndRescoresWinds() throws {
        var game = makeGame()
        let draw = try game.recordDraw()
        // 第二局老王（西家）和：西风刻算门风刻
        let tiles = Hand(concealed: Tile.parseList("西西西 南南南 123m 456m 9m9m"), winningTile: Tile(.characters, 9))
        let context = game.winContext(for: 3)
        let result = try FanCalculator.score(tiles, context: context).get()
        XCTAssertTrue(result.contains(.seatWind))
        try game.recordWin(WinRecord(winner: 3, discarder: 0, hand: tiles, context: context, result: result))

        game.remove(draw.id)
        XCTAssertEqual(game.records.count, 1)
        XCTAssertEqual(game.records[0].handIndex, 0)
        let moved = try XCTUnwrap(game.records[0].outcome.win)
        XCTAssertEqual(moved.context.seatWind, .north, "挪到第一局，老王是北家")
        XCTAssertFalse(moved.fans.contains { $0.fan == .seatWind })
        XCTAssertEqual(game.records[0].deltas[3], 3 * 8 + moved.totalFan)
    }

    func testSwitchingSelfDrawnRescoresTheHand() throws {
        var game = makeGame()
        let tiles = Hand(concealed: Tile.parseList("1p 1p 1p 2p 2p 3p 3p 4p 4p 5p 5p 6p 6p 7p"))
        var context = game.winContext(for: 0)
        context.selfDrawn = true
        context.lastTileOfWall = true
        let result = try FanCalculator.score(tiles, context: context).get()
        let record = try game.recordWin(WinRecord(winner: 0, discarder: nil, hand: tiles, context: context, result: result))

        var edited = try XCTUnwrap(record.outcome.win)
        edited.discarder = 2
        try game.replace(record.id, with: .win(edited))
        let rescored = try XCTUnwrap(game.records[0].outcome.win)
        XCTAssertFalse(rescored.context.selfDrawn)
        XCTAssertFalse(rescored.context.lastTileOfWall, "妙手回春换成点炮就不成立了")
        XCTAssertFalse(rescored.fans.contains { $0.fan == .selfDrawn })
        XCTAssertEqual(game.records[0].deltas[2], -(8 + rescored.totalFan))
    }

    func testFanOverride() throws {
        var game = makeGame()
        let record = try game.recordWin(win(1, discarder: 0, fan: 8, flowers: 2))
        var edited = try XCTUnwrap(record.outcome.win)
        edited.fanOverride = 16
        try game.replace(record.id, with: .win(edited))
        XCTAssertEqual(game.records[0].outcome.win?.totalFan, 16)
        XCTAssertEqual(game.records[0].deltas, [-24, 40, -8, -8])

        edited.fanOverride = 9  // 去掉 2 番花只剩 7 番
        XCTAssertThrowsError(try game.replace(record.id, with: .win(edited))) { error in
            XCTAssertEqual(error as? GameError, .belowMinimumFan(7))
        }
        XCTAssertEqual(game.records[0].outcome.win?.totalFan, 16, "改不了时牌局不变")
    }

    func testEditCannotPushPastLastHand() throws {
        var game = makeGame()
        for _ in 0..<15 { try game.recordDraw() }
        let falseWin = try game.recordFalseWin(offender: 1)
        try game.recordDraw()
        XCTAssertTrue(game.isFinished)
        XCTAssertThrowsError(try game.replace(falseWin.id, with: .drawn)) { error in
            XCTAssertEqual(error as? GameError, .tooManyHands(16))
        }
        // 打完的牌局也能改别的
        try game.replace(falseWin.id, with: .falseWin(offender: 2))
        XCTAssertEqual(game.records[15].deltas, [10, 10, -30, 10])
    }

    func testMinimalTransfers() {
        let scores = [72, -72, 30, -30]
        let transfers = Settlement.minimalTransfers(scores: scores)
        XCTAssertEqual(transfers.count, 2)
        XCTAssertTrue(transfers.contains(Transfer(from: 1, to: 0, points: 72)))

        let general = [100, -60, -25, -15]
        let t2 = Settlement.minimalTransfers(scores: general)
        XCTAssertEqual(t2.count, 3)
        var balance = general
        for t in t2 { balance[t.from] += t.points; balance[t.to] -= t.points }
        XCTAssertEqual(balance, [0, 0, 0, 0])

        XCTAssertEqual(Settlement.ranking(scores: general), [0, 3, 2, 1])
    }

    func testArchiveRoundTrip() throws {
        var archive = GameArchive()
        var game = makeGame()
        try game.recordWin(win(1, discarder: 3, fan: 12))
        archive.upsert(game)
        archive.remember(game.players)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("archive.json")
        try archive.save(to: url)
        let loaded = try GameArchive.load(from: url)
        // 日期按 ISO 8601 存到秒，所以不直接比较整个结构
        XCTAssertEqual(loaded.games.map(\.id), [game.id])
        XCTAssertEqual(loaded.games.first?.records.map(\.outcome), game.records.map(\.outcome))
        XCTAssertEqual(loaded.activeGame?.scores, game.scores)
        XCTAssertEqual(loaded.frequentPlayers.count, 4)
    }

    func testSpecialWinAvailability() {
        let hand = Hand(concealed: Tile.parseList("123m 456m 789m 123p 44p"), winningTile: Tile(.dots, 4))
        XCTAssertNotNil(SpecialWin.lastTileOfItsKind.unavailableReason(hand: hand, selfDrawn: false))
        XCTAssertNotNil(SpecialWin.kongReplacement.unavailableReason(hand: hand, selfDrawn: true))
        XCTAssertNil(SpecialWin.lastTileDraw.unavailableReason(hand: hand, selfDrawn: true))
        XCTAssertNotNil(SpecialWin.lastTileClaim.unavailableReason(hand: hand, selfDrawn: true))
    }

    func testFixSuggestionsFindMisreadPip() {
        // 清一色里一张 5饼 被读成了 4饼 → 应该建议改回去
        let tiles = Tile.parseList("111p 234p 567p 999p 5p 4p")  // 4p 应为 5p
        let hand = Hand(concealed: tiles, winningTile: tiles.last)
        let suggestions = WinAssistant.fixSuggestions(for: hand, context: WinContext())
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertEqual(suggestions.first?.from?.suit, .dots)
        XCTAssertEqual(suggestions.first.map { abs($0.from!.rank - $0.to.rank) }, 1)

        // 少读一张：补一张就能和
        let short = Hand(concealed: Array(Tile.parseList("111p 234p 567p 999p 5p")), winningTile: Tile(.dots, 5))
        let add = WinAssistant.fixSuggestions(for: short, context: WinContext())
        XCTAssertTrue(add.contains { $0.to == Tile(.dots, 5) })
        XCTAssertTrue(add.allSatisfy { $0.index == nil })
    }
}

final class ArchiveAndParsingTests: XCTestCase {
    func testOldArchiveWithMissingFieldsStillLoads() throws {
        let json = #"{"games":[{"id":"6E897041-FD3D-4426-B080-2D7BC6E72995","startedAt":"2026-10-26T04:00:00Z","players":[{"id":"6E897041-FD3D-4426-B080-2D7BC6E72991","name":"a"},{"id":"6E897041-FD3D-4426-B080-2D7BC6E72992","name":"b"},{"id":"6E897041-FD3D-4426-B080-2D7BC6E72993","name":"c"},{"id":"6E897041-FD3D-4426-B080-2D7BC6E72994","name":"d"}],"rules":{"yuanPerPoint":2}}]}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(GameArchive.self, from: Data(json.utf8))
        XCTAssertEqual(archive.games.first?.rules.yuanPerPoint, 2)
        XCTAssertEqual(archive.games.first?.rules.totalHands, 16)
        XCTAssertEqual(archive.version, 1)
    }

    func testUnreadableArchiveIsBackedUpNotOverwritten() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("archive.json")
        try Data("{ not json".utf8).write(to: url)

        let (archive, backup, error) = GameArchive.loadOrRecover(from: url)
        XCTAssertNotNil(error)
        XCTAssertTrue(archive.games.isEmpty)
        let backupURL = try XCTUnwrap(backup)
        XCTAssertEqual(try String(contentsOf: backupURL, encoding: .utf8), "{ not json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testStartingAGameEndsTheUnfinishedOne() {
        var archive = GameArchive()
        let players = ["a", "b", "c", "d"].map { Player(name: $0) }
        let first = archive.start(Game(players: players))
        archive.start(Game(players: players))
        XCTAssertTrue(archive.finishedGames.contains { $0.id == first.id })
        XCTAssertEqual(archive.games.filter { !$0.isFinished }.count, 1)
    }

    func testGeminiAnswerToleratesShortConcealedKongAndUnknownTiles() throws {
        let json = #"{"concealed":["1m","2m","3m","梅","5p","5p","?"],"melds":[{"kind":"concealed_kong","tiles":["9s","9s","9s"]},{"kind":"chow","tiles":["1s","2s","4s"]}],"flowers":0}"#
        let r = try GeminiRecognizer.parseAnswer(Data(json.utf8))
        XCTAssertEqual(r.melds, [.kong(Tile(.bamboo, 9), concealed: true)])
        XCTAssertEqual(r.flowerCount, 1)
        XCTAssertEqual(r.concealed.prefix(3).map(\.tile), Tile.parseList("1s2s4s"))
        XCTAssertTrue(r.concealed.prefix(3).allSatisfy(\.uncertain))
        XCTAssertEqual(r.notes.count, 2)
    }

    func testBlockedGeminiResponseExplainsWhy() {
        let json = #"{"promptFeedback":{"blockReason":"SAFETY"}}"#
        XCTAssertThrowsError(try GeminiRecognizer.parseResponse(Data(json.utf8))) { error in
            XCTAssertTrue((error as? RecognitionError)?.message.contains("SAFETY") ?? false)
        }
    }

    func testNoFixSuggestionsForCorrectLowFanHand() {
        // 牌型成立但不够 8 番：不要建议把牌改成能和的大番
        let hand = Hand(melds: [.chow(Tile(.characters, 2))!],
                        concealed: Tile.parseList("345p 678s 234s 66m"), winningTile: Tile(.characters, 6))
        XCTAssertTrue(WinAssistant.fixSuggestions(for: hand, context: WinContext()).isEmpty)
    }

    func testSpecialWinConflicts() {
        XCTAssertTrue(SpecialWin.kongReplacement.conflicts.contains(.lastTileDraw))
        XCTAssertTrue(SpecialWin.lastTileClaim.conflicts.contains(.robbingTheKong))
    }
}

private extension HandOutcome {
    var win: WinRecord? {
        if case .win(let win) = self { return win }
        return nil
    }
}
