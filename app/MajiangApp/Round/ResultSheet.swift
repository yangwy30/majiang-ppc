import SwiftUI
import MajiangKit

/// 结果：从下往上弹出的一层。大番数、每个番种一句白话、这局谁付多少。
struct ResultSheet: View {
    var flow: RoundFlow
    var finish: (HandOutcome) -> Void

    var body: some View {
        Group {
            if let record = flow.winRecord, let deltas = flow.deltas {
                content(record, deltas)
            } else {
                ContentUnavailableView("这手牌还和不了", systemImage: "exclamationmark.circle")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .presentationBackground(Theme.paper)
    }

    private func content(_ record: WinRecord, _ deltas: [Int]) -> some View {
        let game = flow.game
        let name = { (i: Int) in game.players[i].name }
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(record.discarder.map { "\(name(record.winner)) · \(name($0))点炮" } ?? "\(name(record.winner)) · 自摸")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(record.totalFan)")
                        .font(.system(size: 88, weight: .ultraLight).monospacedDigit())
                        .tracking(-2)
                    Text("番").font(Theme.serif(22))
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 0) {
                    ForEach(record.fans, id: \.fan) { entry in
                        FanRow(name: entry.count > 1 ? "\(entry.fan.name) ×\(entry.count)" : entry.fan.name,
                               plain: entry.fan.explanation, points: entry.points)
                    }
                    if record.flowerFan > 0 {
                        FanRow(name: "花牌 ×\(record.flowerFan)", plain: "每张 1 番，不算进 8 番", points: record.flowerFan)
                    }
                }
                .padding(.top, 14)

                SectionLabel("这局谁付多少")
                    .padding(.top, 22)
                    .padding(.bottom, 6)
                VStack(spacing: 0) {
                    Hairline()
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(0..<4, id: \.self) { i in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name(i)).font(.system(size: 13)).foregroundStyle(Theme.gray).lineLimit(1)
                                Text(Theme.signed(deltas[i]))
                                    .font(Theme.score(24))
                                    .foregroundStyle(Theme.scoreColor(deltas[i]))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                    Hairline()
                }
                Text(explanation(record, deltas))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.gray)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 24)
        }
        .bottomBar {
            Button("记下") { finish(.win(record)) }
                .buttonStyle(.primary)
        }
    }

    /// 「自摸：三家各付 8 + 32 = 40 分。」再说一句 8 分是什么。
    private func explanation(_ record: WinRecord, _ deltas: [Int]) -> String {
        let game = flow.game
        let base = game.rules.basePoints
        let fan = record.totalFan
        var lines: [String]
        if let discarder = record.discarder {
            lines = ["点炮：\(game.players[discarder].name)付 \(base) + \(fan) = \(base + fan) 分，另外两家各付 \(base) 分。"]
        } else {
            lines = ["自摸：三家各付 \(base) + \(fan) = \(base + fan) 分。"]
        }
        lines.append("\(base) 分是底分，不管几番每人都要先付。")
        if game.rules.yuanPerPoint != 1 {
            lines.append("按 1 分 = \(game.rules.yuanPerPoint.formatted()) 元，\(game.players[record.winner].name)这局赢 \(game.moneyText(deltas[record.winner]))。")
        }
        return lines.joined(separator: "\n")
    }
}

private struct FanRow: View {
    var name: String
    var plain: String
    var points: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 16, weight: .medium))
                Text(plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Text("\(points)").font(.system(size: 16).monospacedDigit())
        }
        .padding(.vertical, 11)
        .overlay(alignment: .top) { Hairline() }
    }
}
