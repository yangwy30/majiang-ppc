import SwiftUI
import MajiangKit

/// 1. 首页：进行中的牌局 + 历史牌局 + 开新局。
struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let game = model.archive.activeGame {
                    Button {
                        model.path.append(.table(game.id))
                    } label: {
                        ActiveGameCard(game: game)
                    }
                    .buttonStyle(.plain)
                }

                if !model.archive.finishedGames.isEmpty {
                    SectionTitle(text: "历史牌局")
                    VStack(spacing: 0) {
                        ForEach(model.archive.finishedGames) { game in
                            Button {
                                model.path.append(.endGame(game.id))
                            } label: {
                                HistoryRow(game: game)
                            }
                            .buttonStyle(.plain)
                            if game.id != model.archive.finishedGames.last?.id {
                                Divider().overlay(Theme.border)
                            }
                        }
                    }
                    .card(padding: 0)
                } else if model.archive.activeGame == nil {
                    EmptyHome()
                }

                if let error = model.loadError {
                    Text(error).font(.footnote).foregroundStyle(Theme.crimson)
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            Button("开新局") { model.path.append(.newGame) }
                .buttonStyle(.primary)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(Theme.canvas)
        }
        .page()
        .navigationTitle("国标记分")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.path.append(.settings)
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("设置")
            }
        }
    }
}

private struct ActiveGameCard: View {
    var game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("进行中").font(.headline)
                Spacer()
                Chip(text: "\(game.prevalentWind.name)圈 · 第 \(game.currentHandIndex % 4 + 1) 局", kind: .neutral)
            }
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in
                    VStack(spacing: 4) {
                        Text(game.players[i].name).font(.subheadline).lineLimit(1)
                        Text(Theme.signed(game.scores[i]))
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(Theme.scoreColor(game.scores[i]))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text("剩 \(game.remainingHands) 局 · 点击继续")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
        }
        .card()
    }
}

private struct HistoryRow: View {
    var game: Game

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(game.startedAt.formatted(date: .abbreviated, time: .omitted)).font(.subheadline.weight(.medium))
                Text(game.players.map(\.name).joined(separator: "、") + " · \(game.currentHandIndex) 局")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(1)
            }
            Spacer()
            // 第一位当作「我」：开局时东位填自己
            Text(Theme.signed(game.scores[0]))
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.scoreColor(game.scores[0]))
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Theme.tertiaryInk)
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}

private struct EmptyHome: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("打完一局，对着和牌拍一张").font(.title3.weight(.bold))
            Text("App 认牌、算番、记账。圈风门风和庄家自动轮转，不用记规则。")
                .foregroundStyle(Theme.secondaryInk)
        }
        .card(padding: 20)
    }
}
