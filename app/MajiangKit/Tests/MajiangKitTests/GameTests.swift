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
