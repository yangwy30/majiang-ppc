import SwiftUI
import MajiangKit

/// 规则和番种说明：给不熟国标的人看的白话版。
struct RulesGuideView: View {
    @Environment(\.dismiss) private var dismiss

    private let basics: [(String, String)] = [
        ("怎么算钱", "和牌的人先从每家收 8 分底分，再收番数。自摸：三家都付 8 + 番数；点炮：点炮的人付 8 + 番数，另外两家只付 8。"),
        ("要 8 番才能和", "番数不够 8 番不能和。花牌每张 1 番，但不算进这 8 番。"),
        ("庄怎么轮", "不连庄，每局庄家往下轮一位。东南西北 4 圈、16 局打完一场。App 会自己轮，不用记。"),
        ("一炮只能一个人和", "几个人同时能和同一张牌时，按点炮那家的下家、对家、上家的顺序，只算第一个。"),
        ("和错了", "推倒了却凑不成和牌，赔另外三家各 10 分，这一局接着打。"),
    ]

    private var groups: [(points: Int, fans: [Fan])] {
        Dictionary(grouping: Fan.allCases, by: \.points)
            .map { ($0.key, $0.value) }
            .sorted { $0.points > $1.points }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(basics, id: \.0) { title, text in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title).font(.system(size: 16, weight: .semibold))
                            Text(text)
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.gray)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 12)
                    }

                    ForEach(groups, id: \.points) { group in
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(group.points)").font(Theme.score(28))
                            Text("番").font(Theme.serif(15))
                        }
                        .padding(.top, 28)
                        .padding(.bottom, 4)
                        ForEach(group.fans, id: \.self) { fan in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fan.name).font(.system(size: 16, weight: .medium))
                                Text(fan.explanation)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.gray)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 11)
                            .overlay(alignment: .top) { Hairline() }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .page()
            .navigationTitle("规则和番种")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                NavClose("关闭") { dismiss() }
            }
        }
    }
}
