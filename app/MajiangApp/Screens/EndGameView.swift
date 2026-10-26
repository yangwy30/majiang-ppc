import SwiftUI
import MajiangKit

/// 9. 结束牌局：名次、输赢、最少转账、本场最大的一手。
struct EndGameView: View {
    @Environment(AppModel.self) private var model
    let gameID: UUID

    var body: some View {
        if let game = model.game(gameID) {
            content(game)
        }
    }

    private func content(_ game: Game) -> some View {
        let scores = game.scores
        let ranking = Settlement.ranking(scores: scores)
        let transfers = Settlement.minimalTransfers(scores: scores)
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(text: "名次")
                VStack(spacing: 0) {
                    ForEach(Array(ranking.enumerated()), id: \.element) { place, player in
                        HStack {
                            Text("\(place + 1)").font(.headline.monospacedDigit()).frame(width: 24)
                            Text(game.players[player].name)
                            Spacer()
                            Text(Theme.signed(scores[player]))
                                .font(.body.weight(.semibold).monospacedDigit())
                                .foregroundStyle(Theme.scoreColor(scores[player]))
                            Text(game.moneyText(scores[player]))
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(Theme.secondaryInk)
                                .frame(width: 70, alignment: .trailing)
                        }
                        .padding(14)
                        if place < 3 { Divider().overlay(Theme.border) }
                    }
                }
                .card(padding: 0)

                SectionTitle(text: "怎么转账（笔数最少）")
                VStack(alignment: .leading, spacing: 10) {
                    if transfers.isEmpty {
                        Text("不用转账").foregroundStyle(Theme.secondaryInk)
                    }
                    ForEach(Array(transfers.enumerated()), id: \.offset) { _, t in
                        HStack {
                            Text("\(game.players[t.from].name) → \(game.players[t.to].name)")
                            Spacer()
                            Text(game.moneyText(t.points)).font(.body.weight(.semibold).monospacedDigit())
                        }
                    }
                }
                .card()

                SectionTitle(text: "本场")
                VStack(alignment: .leading, spacing: 8) {
                    Text("打了 \(game.currentHandIndex) 局，1 分 = \(game.rules.yuanPerPoint.formatted()) 元")
                    if let biggest = game.biggestWin {
                        Text("最大的一手：\(game.players[biggest.win.winner].name) \(biggest.win.totalFan) 番"
                             + (biggest.win.fans.first.map { "（\($0.fan.name)）" } ?? ""))
                    }
                }
                .font(.subheadline)
                .card()
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                ShareLink(item: shareText(game, ranking: ranking, transfers: transfers)) {
                    Text("发到群里")
                }
                .buttonStyle(.primary)
                if game.endedAt == nil && !game.isFinished {
                    Button("结束这场牌局") {
                        var updated = game
                        updated.end()
                        model.update(updated)
                        model.path = []
                    }
                    .buttonStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(Theme.canvas)
        }
        .page()
        .navigationTitle(game.isFinished ? "结算" : "结束牌局")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func shareText(_ game: Game, ranking: [Int], transfers: [Transfer]) -> String {
        var lines = ["国标麻将 \(game.startedAt.formatted(date: .abbreviated, time: .omitted)) · \(game.currentHandIndex) 局"]
        for player in ranking {
            lines.append("\(game.players[player].name) \(Theme.signed(game.scores[player])) 分（\(game.moneyText(game.scores[player]))）")
        }
        if !transfers.isEmpty {
            lines.append("转账：")
            for t in transfers {
                lines.append("\(game.players[t.from].name) → \(game.players[t.to].name) \(game.moneyText(t.points))")
            }
        }
        return lines.joined(separator: "\n")
    }
}
