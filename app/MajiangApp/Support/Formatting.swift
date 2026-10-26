import Foundation
import MajiangKit

extension HandRecord {
    /// 一句话描述这一局，账本和牌桌页用。
    func summary(in game: Game) -> String {
        let name = { (i: Int) in game.players[i].name }
        switch outcome {
        case .win(let win):
            if let discarder = win.discarder {
                return "\(name(win.winner)) 和 \(name(discarder)) 点炮 · \(win.totalFan) 番"
            }
            return "\(name(win.winner)) 自摸 · \(win.totalFan) 番"
        case .drawn:
            return "荒庄"
        case .falseWin(let offender):
            return "\(name(offender)) 错和"
        case .manual(_, let note):
            return note.isEmpty ? "手动记分" : "手动记分 · \(note)"
        }
    }

    /// 「东圈第 2 局」。
    func handLabel(in game: Game) -> String {
        "\(game.prevalentWind(ofHand: handIndex).name)圈第 \(handIndex % 4 + 1) 局"
    }
}

extension Game {
    func moneyText(_ points: Int) -> String {
        let value = money(forPoints: points)
        let text = abs(value).formatted(.number.precision(.fractionLength(0...2)))
        return value < 0 ? "-¥\(text)" : "¥\(text)"
    }
}
