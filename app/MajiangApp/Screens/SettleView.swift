import SwiftUI
import MajiangKit

/// 结算：名次、最省事的转账、本场最大的一手。进到这里时牌局已经结束了。
struct SettleView: View {
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
            VStack(alignment: .leading, spacing: 0) {
                PageTitle(title: "打完了",
                          subtitle: "\(game.startedAt.dayLabel) · \(game.currentHandIndex) 局 · 1 分 = \(game.rules.yuanPerPoint.formatted(.number.precision(.fractionLength(0...2)))) 元")

                VStack(spacing: 0) {
                    ForEach(Array(ranking.enumerated()), id: \.element) { place, player in
                        HStack(spacing: 16) {
                            Text("\(place + 1)")
                                .font(Theme.serif(15))
                                .foregroundStyle(Theme.gray)
                                .frame(width: 14)
                            Text(game.players[player].name).font(.system(size: 17, weight: .medium))
                            Spacer()
                            Text(Theme.signed(scores[player]))
                                .font(Theme.score(26))
                                .foregroundStyle(Theme.scoreColor(scores[player]))
                        }
                        .frame(height: 60)
                        Hairline()
                    }
                }
                .padding(.top, 26)

                SectionLabel("这样转账最省事")
                    .padding(.top, 32)
                    .padding(.bottom, 10)
                VStack(spacing: 0) {
                    if transfers.isEmpty {
                        Text("不用转账，正好打平。")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.gray)
                            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                    }
                    ForEach(Array(transfers.enumerated()), id: \.offset) { index, t in
                        HStack {
                            HStack(spacing: 10) {
                                Text(game.players[t.from].name)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.faint)
                                    .accessibilityLabel("转给")
                                Text(game.players[t.to].name)
                            }
                            .font(.system(size: 16))
                            Spacer()
                            Text(game.moneyText(t.points))
                                .font(.system(size: 17, weight: .semibold).monospacedDigit())
                        }
                        .frame(height: 54)
                        if index < transfers.count - 1 { Hairline(color: Theme.lineSoft) }
                    }
                }
                .padding(.vertical, 4)
                .block()

                if let biggest = game.biggestWin {
                    Text("最大的一手：\(game.players[biggest.win.winner].name)，"
                         + (biggest.win.fans.first.map { "\($0.fan.name) " } ?? "") + "\(biggest.win.totalFan) 番")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .padding(.top, 24)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .bottomBar {
            ShareLink(item: shareText(game, ranking: ranking, transfers: transfers)) {
                Text("分享到群里")
            }
            .buttonStyle(.primary)
        }
        .page()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { model.path = [] }
                    .font(.system(size: 17, weight: .semibold))
            }
        }
    }

    private func shareText(_ game: Game, ranking: [Int], transfers: [Transfer]) -> String {
        var lines = ["国标麻将 \(game.startedAt.dayLabel) · \(game.currentHandIndex) 局"]
        for player in ranking {
            lines.append("\(game.players[player].name) \(Theme.signed(game.scores[player])) 分（\(game.moneyText(game.scores[player]))）")
        }
        if !transfers.isEmpty {
            lines.append("这样转账最省事：")
            for t in transfers {
                lines.append("\(game.players[t.from].name) → \(game.players[t.to].name) \(game.moneyText(t.points))")
            }
        }
        return lines.joined(separator: "\n")
    }
}
