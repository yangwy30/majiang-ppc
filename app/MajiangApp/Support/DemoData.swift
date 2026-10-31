import Foundation
import MajiangKit

/// 截图用：启动参数 `-demo-screen <页面>` 打开一份假数据，直接停在某个页面。
/// 数据存在临时目录，不会碰真的牌局记录。只在开发版里有。
enum DemoScreen: String {
    case emptyHome = "empty-home"
    case home, newGame = "new-game", table, editHand = "edit-hand", capture, check, notWin = "not-win", result, settle
    /// 双读：端侧结果已显示、Gemini 还在复核；复核完、有一张两边读得不一样和一张只有一边读到。
    case reviewing = "check-reviewing", dualRead = "check-dual"
    /// 发到群里的账本图：打完的结算 / 没打完的牌局；备份与换手机页。
    case shareSettle = "share-settle", shareLive = "share-live", backup
    /// 首页上打开填邀请码的页。
    case invite
    /// 家规：开局页的规则表单、点开一项的选项；牌桌上打到一半改这场的规则（预览底分改成 5）、
    /// 带家规的牌桌、封顶起作用的结果页、带家规的账本图。
    case houseRules = "house-rules", rulePicker = "rule-picker", gameRules = "game-rules"
    case tableHouse = "table-house", resultCapped = "result-capped", shareHouse = "share-house"

    /// 这几页的牌局带家规：封顶 64（结果页用 16，好让示例那手封顶）、1 分 2 元。
    var usesHouseRules: Bool { [.gameRules, .tableHouse, .resultCapped, .shareHouse].contains(self) }

    static var current: DemoScreen? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-demo-screen"), i + 1 < args.count else { return nil }
        return DemoScreen(rawValue: args[i + 1])
        #else
        return nil
        #endif
    }

    /// 在牌桌上自动打开记一局。
    var opensRound: Bool { [.capture, .check, .notWin, .result, .resultCapped, .reviewing, .dualRead].contains(self) }
}

#if DEBUG
enum DemoData {
    static let names = ["杨", "阿强", "莉莉", "小张"]

    static func archive() -> GameArchive {
        var archive = GameArchive()
        let players = names.map { Player(name: $0) }
        let day: TimeInterval = 86_400

        var older = Game(players: [players[0], players[1], Player(name: "老王"), players[3]], startedAt: Date().addingTimeInterval(-8 * day))
        win(&older, winner: 2, discarder: 0, hand: "123m 456m 789s 234p 55s")
        win(&older, winner: 0, discarder: nil, hand: "234m 456m 678m 东东东 99m")
        older.end()
        archive.upsert(older)

        var last = Game(players: players, startedAt: Date().addingTimeInterval(-1 * day))
        win(&last, winner: 0, discarder: nil, hand: "1112233445566p 7p")
        win(&last, winner: 3, discarder: 1, hand: "123s 456s 789s 南南南 22m")
        last.end()
        archive.upsert(last)

        var houseRules = GameRules()
        if let screen = DemoScreen.current, screen.usesHouseRules {
            houseRules.fanCap = screen == .resultCapped ? 16 : 64
            houseRules.yuanPerPoint = 2
        }
        var active = Game(players: players, rules: houseRules)
        win(&active, winner: 0, discarder: nil, hand: "1112233445566p 7p")
        win(&active, winner: 2, discarder: 1, hand: "123m 456m 789s 234p 55s")
        _ = try? active.recordDraw()
        win(&active, winner: 3, discarder: nil, hand: "234m 456m 678m 东东东 99m")
        archive.upsert(active)

        archive.remember(players + [Player(name: "老王"), Player(name: "小周")])
        return archive
    }

    /// 按真的算番记一手；凑不成或不够番时退回 8 番的无番和，保证有数据。
    private static func win(_ game: inout Game, winner: Int, discarder: Int?, hand text: String) {
        let tiles = Tile.parseList(text)
        let hand = Hand(concealed: tiles, winningTile: tiles.last)
        var context = game.winContext(for: winner)
        context.selfDrawn = discarder == nil
        let record: WinRecord
        if case .success(let result) = FanCalculator.score(hand, context: context), result.meetsMinimum(game.rules.minimumFan) {
            record = WinRecord(winner: winner, discarder: discarder, hand: hand, context: context, result: result)
        } else {
            record = WinRecord(winner: winner, discarder: discarder, hand: nil, context: context,
                               fans: [FanEntry(fan: .chickenHand, count: 1)], flowerFan: 0)
        }
        _ = try? game.recordWin(record)
    }

    /// 账本图截图用哪场牌局。
    static func shareGame(_ screen: DemoScreen, in archive: GameArchive) -> Game? {
        switch screen {
        case .shareSettle: archive.finishedGames.first
        case .shareLive, .shareHouse: archive.activeGame
        default: nil
        }
    }

    /// 记一局流程里要停的那一步。
    @MainActor
    static func prepare(_ flow: RoundFlow, for screen: DemoScreen) {
        let samples = MockRecognizer.defaultSamples
        switch screen {
        case .check:
            flow.load(samples[0])
            flow.steps = [.check]
        case .notWin:
            flow.load(samples[2])
            flow.steps = [.check]
        case .reviewing:
            flow.load(Recognition(concealed: Tile.parseList("1112233445566p 7p"), source: "端侧"))
            flow.isReviewing = true
            flow.steps = [.check]
        case .dualRead:
            // Gemini 把一张 5饼 读成 4饼；端侧在中间多读了一张 9条
            var gemini = Recognition(concealed: Tile.parseList("1112233445566p 7p"), source: "Gemini")
            gemini.concealed[9] = RecognizedTile(tile: Tile(suit: .dots, rank: 4)!)
            let onDevice = Recognition(concealed: Tile.parseList("111223p 9s 3445566p 7p"), source: "端侧")
            flow.load(DualReadRecognizer.merge(gemini, with: onDevice))
            flow.steps = [.check]
        case .result, .resultCapped:
            flow.load(samples[0])
            flow.choose(Tile(suit: .dots, rank: 5)!, at: 9)
            flow.steps = [.check]
            flow.showResult = true
        default:
            break
        }
    }
}
#endif
