import SwiftUI
import MajiangKit

/// 3. 牌桌：按真实座位画四个人，中间是圈风和剩余局数。
struct TableView: View {
    @Environment(AppModel.self) private var model
    let gameID: UUID

    @State private var recording = false
    @State private var manualScoring = false
    @State private var confirmDraw = false
    @State private var recordError: String?

    var body: some View {
        if let game = model.game(gameID) {
            content(game)
        } else {
            ContentUnavailableView("找不到这场牌局", systemImage: "questionmark")
        }
    }

    private func content(_ game: Game) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TableDiagram(game: game)

                if !game.records.isEmpty {
                    HStack {
                        SectionTitle(text: "最近几局")
                        Button("账本") { model.path.append(.ledger(game.id)) }
                            .font(.footnote.weight(.semibold))
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(game.records.suffix(4).reversed())) { record in
                            RecordRow(record: record, game: game)
                            if record.id != game.records.suffix(4).first?.id {
                                Divider().overlay(Theme.border)
                            }
                        }
                    }
                    .card(padding: 0)
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if game.isFinished {
                    Button("结算") { model.path.append(.endGame(game.id)) }
                        .buttonStyle(.primary)
                } else {
                    Button("有人和了") { recording = true }
                        .buttonStyle(.primary)
                    HStack(spacing: 10) {
                        Button("荒庄") { confirmDraw = true }
                            .buttonStyle(.secondary)
                        Button("手动记分") { manualScoring = true }
                            .buttonStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(Theme.canvas)
        }
        .page()
        .navigationTitle("\(game.prevalentWind.name)圈 · 第 \(min(game.currentHandIndex, game.rules.totalHands - 1) % 4 + 1) 局")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("账本", systemImage: "list.bullet") { model.path.append(.ledger(game.id)) }
                    Button("结束牌局", systemImage: "flag.checkered") { model.path.append(.endGame(game.id)) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("这一局荒庄？不计分，只推进局数。", isPresented: $confirmDraw, titleVisibility: .visible) {
            Button("荒庄") { record { try $0.recordDraw() } }
        }
        .fullScreenCover(isPresented: $recording) {
            RoundFlowView(game: game) { outcome in
                switch outcome {
                case .win(let win): record { try $0.recordWin(win) }
                case .falseWin(let offender): record { try $0.recordFalseWin(offender: offender) }
                default: break
                }
            }
        }
        .sheet(isPresented: $manualScoring) {
            ManualScoreView(game: game) { deltas, note in
                record { try $0.recordManual(deltas: deltas, note: note) }
            }
        }
        .alert("没有记上", isPresented: Binding(get: { recordError != nil }, set: { if !$0 { recordError = nil } })) {
            Button("好") { recordError = nil }
        } message: {
            Text(recordError ?? "")
        }
    }

    /// 记一条到这场牌局；失败时弹窗说明，不悄悄丢掉。
    private func record(_ change: (inout Game) throws -> HandRecord) {
        guard var updated = model.game(gameID) else { return }
        do {
            _ = try change(&updated)
            model.update(updated)
        } catch let error as GameError {
            recordError = error.message
        } catch {
            recordError = error.localizedDescription
        }
    }
}

/// 方桌：东在下，南在右，西在上，北在左（逆时针）。
private struct TableDiagram: View {
    var game: Game

    var body: some View {
        let hand = min(game.currentHandIndex, game.rules.totalHands - 1)
        let seating = game.seating(ofRound: game.roundIndex(ofHand: hand))
        VStack(spacing: 12) {
            SeatLabel(game: game, player: seating[2], hand: hand)
            HStack(spacing: 12) {
                SeatLabel(game: game, player: seating[3], hand: hand)
                    .frame(maxWidth: .infinity)
                // 中间固定为正方形；在没有高度约束的 HStack 里用 aspectRatio 会被压扁，「东圈」变成省略号
                VStack(spacing: 6) {
                    Text("\(game.prevalentWind(ofHand: hand).name)圈")
                        .font(.system(size: 34, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(game.isFinished ? "已打完" : "剩 \(game.remainingHands) 局")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                }
                .frame(width: 116, height: 116)
                .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border))
                SeatLabel(game: game, player: seating[1], hand: hand)
                    .frame(maxWidth: .infinity)
            }
            SeatLabel(game: game, player: seating[0], hand: hand)
        }
        .card()
    }
}

private struct SeatLabel: View {
    var game: Game
    var player: Int
    var hand: Int

    var body: some View {
        let isDealer = game.dealer(ofHand: hand) == player
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(game.seatWind(of: player, inHand: hand).name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryInk)
                if isDealer { Chip(text: "庄", kind: .dealer) }
            }
            Text(game.players[player].name).font(.subheadline.weight(.semibold)).lineLimit(1)
            Text(Theme.signed(game.scores[player]))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.scoreColor(game.scores[player]))
        }
        .frame(minWidth: 72)
    }
}

struct RecordRow: View {
    var record: HandRecord
    var game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.summary(in: game)).font(.subheadline.weight(.medium))
                Spacer()
                Text(record.handLabel(in: game)).font(.caption).foregroundStyle(Theme.tertiaryInk)
            }
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in
                    Text("\(game.players[i].name) \(Theme.signed(record.deltas[i]))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.scoreColor(record.deltas[i]))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
    }
}
