import SwiftUI
import MajiangKit

/// 5b. 不成和：说明原因，给出最可能的改法；也可以记为错和。
struct NotWinView: View {
    @Bindable var flow: RoundFlow
    var finish: (HandOutcome) -> Void
    @State private var confirmFalseWin = false

    private var suggestions: [FixSuggestion] {
        WinAssistant.fixSuggestions(for: flow.hand, context: flow.context, minimumFan: flow.game.rules.minimumFan)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Chip(text: "不成和", kind: .warning)
                    Text(WinAssistant.explain(flow.hand, context: flow.context, minimumFan: flow.game.rules.minimumFan))
                        .font(.body)
                    TileRow(tiles: flow.hand.concealed, width: 22)
                }
                .card()

                if !suggestions.isEmpty {
                    SectionTitle(text: "最可能认错的牌")
                    VStack(spacing: 0) {
                        ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                            Button {
                                flow.apply(suggestion)
                                flow.steps.removeLast()
                            } label: {
                                HStack(spacing: 12) {
                                    if let from = suggestion.from {
                                        TileFace(tile: from, width: 32)
                                        Image(systemName: "arrow.right").foregroundStyle(Theme.tertiaryInk)
                                    } else {
                                        Image(systemName: "plus").foregroundStyle(Theme.tertiaryInk)
                                    }
                                    TileFace(tile: suggestion.to, width: 32)
                                    Text(suggestion.text).font(.subheadline).multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if index < suggestions.count - 1 { Divider().overlay(Theme.border) }
                        }
                    }
                    .card(padding: 0)
                } else {
                    Text("改一张牌也凑不成能起和的牌，可能认错了不止一张，或者吃碰杠分组不对。回去逐张对照照片看看。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("其实是诈和？").font(.subheadline.weight(.semibold))
                    Text("按规则记为错和：\(flow.game.players[flow.winner].name) 赔另外三家各 \(flow.game.rules.falseWinPenalty) 分，这一局继续打。")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                    Button("记为错和") { confirmFalseWin = true }
                        .buttonStyle(.secondary)
                        .padding(.top, 4)
                }
                .card()
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            Button("回去改牌") { flow.steps.removeLast() }
                .buttonStyle(.primary)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(Theme.canvas)
        }
        .page()
        .navigationTitle("不成和")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("记 \(flow.game.players[flow.winner].name) 错和？", isPresented: $confirmFalseWin, titleVisibility: .visible) {
            Button("记为错和", role: .destructive) { finish(.falseWin(offender: flow.winner)) }
        }
    }
}
