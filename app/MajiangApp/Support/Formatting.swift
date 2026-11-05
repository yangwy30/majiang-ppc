import Foundation
import MajiangKit

extension HandRecord {
    /// 和牌的那一局才有。
    var win: WinRecord? {
        if case .win(let win) = outcome { return win }
        return nil
    }

    var isWin: Bool { win != nil }

    /// 账本里的一行标题：「莉莉和 · 阿强点炮 · 8 番」「这局没人和」。
    func title(in game: Game) -> String {
        let name = { (i: Int) in game.players[i].name }
        switch outcome {
        case .win(let win):
            var parts = [win.discarder.map { "\(name(win.winner))和 · \(name($0))点炮" } ?? "\(name(win.winner))自摸"]
            // 大番种值得写出来（清一色、七对……），小番种不写
            if let top = win.fans.first, top.fan.points >= 6, top.fan != .chickenHand { parts.append(top.fan.name) }
            let paid = game.rules.paidFan(win)
            parts.append(paid < win.totalFan ? "\(win.totalFan) 番按 \(paid) 算" : "\(win.totalFan) 番")
            return parts.joined(separator: " · ")
        case .drawn:
            return "这局没人和"
        case .falseWin(let offender):
            return "\(name(offender))和错了"
        case .manual(_, let note):
            return note.isEmpty ? "直接改分" : "直接改分 · \(note)"
        }
    }

    /// 标题下面一行：谁付了多少。
    func detail(in game: Game) -> String {
        if case .drawn = outcome { return "不计分" }
        let losers = deltas.indices.filter { deltas[$0] < 0 }
        // 付一样多的人合在一起说：「杨、阿强、莉莉各 −20」
        var groups: [(amount: Int, players: [Int])] = []
        for i in losers {
            if let g = groups.firstIndex(where: { $0.amount == deltas[i] }) {
                groups[g].players.append(i)
            } else {
                groups.append((deltas[i], [i]))
            }
        }
        groups.sort { $0.amount < $1.amount }
        return groups.map { group in
            let names = group.players.map { game.players[$0].name }.joined(separator: "、")
            return group.players.count > 1 ? "\(names)各 \(Theme.signed(group.amount))" : "\(names) \(Theme.signed(group.amount))"
        }
        .joined(separator: "，")
    }

    /// 右边的数字：和牌的人赢了多少；和错的人赔了多少；没人和、直接改分不显示。
    var headline: Int? {
        switch outcome {
        case .win(let win): deltas[win.winner]
        case .falseWin(let offender): deltas[offender]
        case .drawn, .manual: nil
        }
    }
}

extension Game {
    /// 「¥76」「−¥12.5」。
    func moneyText(_ points: Int) -> String {
        let value = money(forPoints: points)
        let text = abs(value).formatted(.number.precision(.fractionLength(0...2)))
        return value < 0 ? "−¥\(text)" : "¥\(text)"
    }

    /// 现在打到的那一局（打完以后停在最后一局）。
    var displayHand: Int { min(currentHandIndex, rules.totalHands - 1) }

    /// 「南风圈 · 第 1 局」。
    var handLabel: String {
        "\(prevalentWind(ofHand: displayHand).name)风圈 · 第 \(displayHand % 4 + 1) 局"
    }

    /// 规则一行：「国标 · 带花 · 1 分 = 1 元」。
    var rulesSummary: String { rules.summary }

    /// 结果页和「这一局」底下那几行：「自摸：三家各付 8 + 32 = 40 分。」再说一句 8 分是什么。
    func paymentExplanation(_ win: WinRecord, deltas: [Int]) -> String {
        let base = rules.basePoints
        let fan = rules.paidFan(win)
        var lines: [String]
        if let discarder = win.discarder {
            lines = [rules.onlyDiscarderPays
                     ? "点炮：\(players[discarder].name)付 \(base) + \(fan) = \(base + fan) 分，按家规另外两家不用付。"
                     : "点炮：\(players[discarder].name)付 \(base) + \(fan) = \(base + fan) 分，另外两家各付 \(base) 分。"]
        } else {
            lines = ["自摸：三家各付 \(base) + \(fan) = \(base + fan) 分。"]
        }
        if base > 0 { lines.append("\(base) 分是底分，不管几番都要先付。") }
        if rules.yuanPerPoint != 1 {
            lines.append("按 1 分 = \(rules.yuanPerPoint.formatted()) 元，\(players[win.winner].name)这局赢 \(moneyText(deltas[win.winner]))。")
        }
        return lines.joined(separator: "\n")
    }

    /// 「这一局」牌下面的一句话：「自己摸到 7饼，和了。」「阿强打出 6饼，莉莉和了。」
    func winSentence(_ win: WinRecord) -> String? {
        guard let tile = win.hand?.winningTile.displayName else { return nil }
        let winner = players[win.winner].name
        guard let discarder = win.discarder.map({ players[$0].name }) else {
            return win.context.kongInvolved ? "开杠补摸到 \(tile)，和了。" : "自己摸到 \(tile)，和了。"
        }
        return win.context.kongInvolved ? "\(discarder)补杠的 \(tile) 被抢，\(winner)和了。" : "\(discarder)打出 \(tile)，\(winner)和了。"
    }
}

extension GameRules {
    /// 跟国标不一样的地方，一项一个短语：「底分 5」「封顶 64 番」。全按国标就是空的。
    var houseRuleParts: [String] {
        let standard = GameRules.standard
        var parts: [String] = []
        if basePoints != standard.basePoints { parts.append("底分 \(basePoints)") }
        if minimumFan != standard.minimumFan { parts.append(minimumFan == 1 ? "和了就算" : "\(minimumFan) 番起和") }
        if fanCap > 0 { parts.append("封顶 \(fanCap) 番") }
        if !includeFlowers { parts.append("不带花") }
        if onlyDiscarderPays { parts.append("点炮一家付") }
        if falseWinPenalty != standard.falseWinPenalty { parts.append("错和赔 \(falseWinPenalty)") }
        if totalHands != standard.totalHands { parts.append("\(totalHands / 4) 圈") }
        if swapSeatsEachRound { parts.append("每圈换座") }
        return parts
    }

    /// 分享图、结算页：「国标 · 带花 · 1 分 = 1 元」；有家规时只写改了的：「国标 · 封顶 64 番 · 1 分 = 2 元」。
    var summary: String {
        let house = houseRuleParts
        return (["国标"] + (house.isEmpty ? ["带花"] : house) + ["1 分 = \(yuanPerPoint.yuanText) 元"])
            .joined(separator: " · ")
    }

    /// 开局页那一行：「标准国标 · 1 分 1 元」「新手局 · 1 分 1 元」「封顶 64 番 · 1 分 2 元」。
    var shortSummary: String {
        let name = scoresLike(.standard) ? "标准国标" : scoresLike(.beginner) ? "新手局" : houseRuleParts.joined(separator: " · ")
        return "\(name) · 1 分 \(yuanPerPoint.yuanText) 元"
    }

    /// 牌桌顶上那一行，只有家规跟国标不一样时才有：「家规 · 封顶 64 番 · 1 分 2 元」。
    var houseRuleBadge: String? {
        let house = houseRuleParts
        guard !house.isEmpty else { return nil }
        return (["家规"] + house + ["1 分 \(yuanPerPoint.yuanText) 元"]).joined(separator: " · ")
    }
}

extension Date {
    /// 「10月25日 周六」。
    var dayLabel: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        let c = calendar.dateComponents([.month, .day, .weekday], from: self)
        return "\(c.month!)月\(c.day!)日 \(calendar.shortWeekdaySymbols[c.weekday! - 1])"
    }
}
