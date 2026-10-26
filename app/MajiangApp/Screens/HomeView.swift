import SwiftUI
import MajiangKit

/// 首页：没打完的牌局、以前的牌局、开一局。有没打完的牌局时 App 直接打开牌桌，这里是返回后看到的。
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showGuide = false
    @State private var showSettings = false

    private var isEmpty: Bool { model.archive.games.isEmpty }

    var body: some View {
        Group {
            if isEmpty {
                EmptyHome(openGuide: { showGuide = true }, openSettings: { showSettings = true },
                          start: { model.path.append(.newGame) })
            } else {
                list
            }
        }
        .page()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showGuide) { RulesGuideView() }
        #if DEBUG
        .sheet(isPresented: $showSettings) { SettingsView() }
        #endif
    }

    private var list: some View {
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

/// 第一次打开、还没有任何牌局时的首页：一句话加三步，说清这个 App 是干什么的。
private struct EmptyHome: View {
    var openGuide: () -> Void
    var openSettings: () -> Void
    var start: () -> Void

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    brand
                    // 标题和步骤作为一块往下放：上方留白 : 下方留白 ≈ 5 : 3，两段都至少 32
                    VStack(alignment: .leading, spacing: 0) {
                        headline
                        steps.padding(.top, 40)
                    }
                    .padding(.vertical, 32)
                    .frame(maxHeight: .infinity, alignment: Alignment(horizontal: .leading, vertical: .fiveEighths))
                }
                .padding(.horizontal, 28)
                // 安全区以下再留 38，离屏幕顶约 100
                .padding(.top, 38)
                .frame(minHeight: geo.size.height)
            }
        }
        .bottomBar {
            Button("开一局", action: start)
                .buttonStyle(.primary)
            Button("第一次打国标？先看看番怎么算", action: openGuide)
                .buttonStyle(.text(size: 14))
                .padding(.top, 10)
        }
    }
}

private extension EmptyHome {
    var brand: some View {
        HStack(spacing: 12) {
            Text("和")
                .font(Theme.serif(17))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Theme.vermilion, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text("国标记分").font(.system(size: 17, weight: .semibold))
        }
        .accessibilityElement(children: .combine)
        #if DEBUG
        // 开发版的设置（识别方式、API Key）藏在长按品牌标里，正式版没有设置页
        .onLongPressGesture { openSettings() }
        #endif
    }

    var headline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("拍一下，")
            Text("番和钱都算好。")
        }
        .font(Theme.serif(32, semibold: true))
    }

    var steps: some View {
        VStack(spacing: 0) {
            StepRow(number: "一", title: "拍", detail: "和牌的人把牌推倒，拍一张") {
                HStack(spacing: 2) {
                    ForEach(Array(Tile.parseList("12355p").enumerated()), id: \.offset) { _, tile in
                        TileFace(tile: tile, width: 16)
                    }
                }
            }
            StepRow(number: "二", title: "算", detail: "认出牌，按国标算番") {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("32").font(Theme.score(30, weight: .ultraLight))
                    Text("番").font(Theme.serif(13, semibold: true))
                }
            }
            StepRow(number: "三", title: "记", detail: "谁给谁多少，自动记账") {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("+120").foregroundStyle(Theme.vermilion)
                    Text("−40").foregroundStyle(Theme.ink)
                }
                .font(Theme.score(15))
            }
        }
    }
}

private extension VerticalAlignment {
    /// 放在 5/8 高度处：子视图和容器都按这个比例对齐，上下留白就是 5 : 3。
    enum FiveEighths: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat { d.height * 5 / 8 }
    }

    static let fiveEighths = VerticalAlignment(FiveEighths.self)
}

/// 三步里的一行：朱红数字、标题和说明、右边一个小样。
private struct StepRow<Sample: View>: View {
    var number: String
    var title: String
    var detail: String
    @ViewBuilder var sample: Sample

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 数字放进描边小方印，单独一笔的「一」才不像破折号
                Text(number)
                    .font(Theme.serif(15, semibold: true))
                    .foregroundStyle(Theme.vermilion)
                    .frame(width: 26, height: 26)
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.vermilion, lineWidth: 1))
                    .frame(width: 28, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 17, weight: .semibold))
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(.leading, 6)
                Spacer(minLength: 12)
                sample.accessibilityHidden(true)
            }
            .padding(.vertical, 24)
            Hairline()
        }
    }
}
