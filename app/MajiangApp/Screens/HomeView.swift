import SwiftUI
import MajiangKit

/// 首页：没打完的牌局、以前的牌局、开一局。有没打完的牌局时 App 直接打开牌桌，这里是返回后看到的。
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showGuide = false
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if let game = model.archive.activeGame {
                    SectionLabel("没打完")
                        .padding(.top, 44)
                        .padding(.bottom, 12)
                    Button {
                        model.path.append(.table(game.id))
                    } label: {
                        ActiveGameCard(game: game)
                    }
                    .buttonStyle(.plain)
                }

                if !model.archive.finishedGames.isEmpty {
                    SectionLabel("以前的")
                        .padding(.top, 36)
                        .padding(.bottom, 4)
                    ForEach(model.archive.finishedGames) { game in
                        Button {
                            model.path.append(.settle(game.id))
                        } label: {
                            HistoryRow(game: game)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button("第一次打国标？看看番怎么算 ›") { showGuide = true }
                    .buttonStyle(.text(size: 14))
                    .padding(.top, 10)

                if let error = model.loadError {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.gray)
                        .padding(.top, 16)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
        }
        .bottomBar {
            Button("开一局") { model.path.append(.newGame) }
                .buttonStyle(.primary)
        }
        .page()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showGuide) { RulesGuideView() }
        #if DEBUG
        .sheet(isPresented: $showSettings) { SettingsView() }
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("国标记分")
                .font(.system(size: 34, weight: .semibold))
                .tracking(-0.5)
                #if DEBUG
                // 开发版的设置（识别方式、API Key）藏在长按标题里，正式版没有设置页
                .onLongPressGesture { showSettings = true }
                #endif
            Text("打完一手，拍一下和牌的人的牌，App 帮你算番记账。")
                .font(.system(size: 15))
                .foregroundStyle(Theme.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ActiveGameCard: View {
    var game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(game.handLabel).font(.system(size: 17, weight: .semibold))
                Spacer()
                Text("继续 ›").font(.system(size: 15)).foregroundStyle(Theme.gray)
            }
            HStack(alignment: .top, spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.players[i].name)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.gray)
                            .lineLimit(1)
                        Text(Theme.signed(game.scores[i]))
                            .font(Theme.score(24))
                            .foregroundStyle(Theme.scoreColor(game.scores[i]))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 20)
        .block(radius: 22)
        .contentShape(Rectangle())
    }
}

private struct HistoryRow: View {
    var game: Game

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(game.startedAt.dayLabel).font(.system(size: 16, weight: .medium))
                    Text(game.players.map(\.name).joined(separator: "、") + " · \(game.currentHandIndex) 局")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.gray)
                        .lineLimit(1)
                }
                Spacer()
                // 第一位当作「我」：开局时第一个填的是自己
                Text(Theme.signed(game.scores[0]))
                    .font(Theme.score(20))
                    .foregroundStyle(Theme.scoreColor(game.scores[0]))
            }
            .padding(.vertical, 14)
            Hairline()
        }
        .contentShape(Rectangle())
    }
}
