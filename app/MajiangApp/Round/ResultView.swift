import SwiftUI
import MajiangKit

/// 7. 番数与收付。
struct ResultView: View {
    @Bindable var flow: RoundFlow
    var finish: (HandOutcome) -> Void

    var body: some View {
        if let record = flow.winRecord, let deltas = flow.deltas {
            content(record, deltas)
        } else {
            ContentUnavailableView("这手牌不够起和", systemImage: "exclamationmark.triangle")
        }
    }

    private func content(_ record: WinRecord, _ deltas: [Int]) -> some View {
        let game = flow.game
        let base = game.rules.basePoints
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 6) {
                    Text("\(record.totalFan)")
                        .font(.system(size: 64, weight: .bold).monospacedDigit())
                    Text("番").font(.headline).foregroundStyle(Theme.secondaryInk)
                    Text("\(game.players[record.winner].name) \(record.isSelfDrawn ? "自摸" : "和牌")")
                        .font(.subheadline)
                    if let hand = record.hand {
                        TileText(tiles: hand.allTiles.sorted(), font: .footnote)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                }
                .frame(maxWidth: .infinity)
                .card(padding: 20)

                SectionTitle(text: "番种")
                VStack(spacing: 0) {
                    ForEach(record.fans, id: \.fan) { entry in
                        FanRow(name: entry.count > 1 ? "\(entry.fan.name) ×\(entry.count)" : entry.fan.name,
                               points: entry.points, explanation: entry.fan.explanation)
                        Divider().overlay(Theme.border)
                    }
                    if record.flowerFan > 0 {
                        FanRow(name: "花牌 ×\(record.flowerFan)", points: record.flowerFan,
                               explanation: Fan.flowerTiles.explanation)
                        Divider().overlay(Theme.border)
                    }
                    HStack {
                        Text("合计").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(record.totalFan) 番").font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                    .padding(14)
                }
                .card(padding: 0)

                SectionTitle(text: "本局收付")
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<4, id: \.self) { i in
                        HStack {
                            Text(game.players[i].name)
                            if i == record.winner { Chip(text: "和", kind: .success) }
                            if i == record.discarder { Chip(text: "点炮", kind: .dealer) }
                            Spacer()
                            Text(Theme.signed(deltas[i]))
                                .font(.body.weight(.semibold).monospacedDigit())
                                .foregroundStyle(Theme.scoreColor(deltas[i]))
                            Text(game.moneyText(deltas[i]))
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(Theme.secondaryInk)
                                .frame(width: 64, alignment: .trailing)
                        }
                    }
                    Divider().overlay(Theme.border)
                    Text(record.isSelfDrawn
                         ? "自摸：三家各付 底分 \(base) + \(record.totalFan) 番 = \(base + record.totalFan)"
                         : "点炮：\(game.players[record.discarder!].name) 付 \(base) + \(record.totalFan) = \(base + record.totalFan)，另外两家各付底分 \(base)")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                }
                .card()
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            Button("记入账本") { finish(.win(record)) }
                .buttonStyle(.primary)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(Theme.canvas)
        }
        .page()
        .navigationTitle("番数与收付")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FanRow: View {
    var name: String
    var points: Int
    var explanation: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.subheadline.weight(.medium))
                Text(explanation).font(.caption).foregroundStyle(Theme.secondaryInk)
            }
            Spacer()
            Text("\(points)").font(.subheadline.monospacedDigit())
        }
        .padding(14)
    }
}
