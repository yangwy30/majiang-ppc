import SwiftUI
import MajiangKit

/// 牌桌，也是账本：上面按座位画四个人，往下滚是每一局的记录。
struct TableView: View {
    @Environment(AppModel.self) private var model
    let gameID: UUID

    @State private var recording = false
    @State private var manualScoring = false
    @State private var showGuide = false
    @State private var confirmEnd = false
    @State private var recordError: String?
    /// 刚记下的一局，底部显示 5 秒「撤销」。
    @State private var justRecorded: HandRecord?
    @State private var undoTimer: Task<Void, Never>?

    var body: some View {
        if let game = model.game(gameID) {
            content(game)
        } else {
            ContentUnavailableView("找不到这场牌局", systemImage: "questionmark")
        }
    }

    private func content(_ game: Game) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TableDiagram(game: game)
                    .padding(.top, 10)

                HStack(alignment: .firstTextBaseline) {
                    Text("账本").font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(game.isFinished ? "打了 \(game.currentHandIndex) 局"
                         : "打了 \(game.currentHandIndex) 局 · 还剩 \(game.remainingHands) 局")
                        .font(.system(size: 13))
                }
                .foregroundStyle(Theme.gray)
                .padding(.top, 26)
                .padding(.bottom, 6)
                Hairline()

                if game.records.isEmpty {
                    Text("还没有记录。有人和了就点下面的按钮。")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.gray)
                        .padding(.vertical, 14)
                }
                ForEach(Array(game.records.enumerated().reversed()), id: \.element.id) { number, record in
                    RecordRow(number: number + 1, record: record, game: game)
                }
            }
            .padding(.horizontal, 24)
        }
        .bottomBar {
            if let record = justRecorded {
                UndoBar(text: "已记下第 \(record.handIndex + 1) 局") { undo(record) }
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if game.isFinished {
                Button("看结算") { settle(game) }
                    .buttonStyle(.primary)
            } else {
                Button("有人和了") { recording = true }
                    .buttonStyle(.primary)
                Button("这局没人和") { record { try $0.recordDraw() } }
                    .buttonStyle(.text)
            }
        }
        .page()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("直接改分") { manualScoring = true }
                    Button("规则和番种说明") { showGuide = true }
                    Divider()
                    if !game.isFinished {
                        Button("结束牌局", role: .destructive) { confirmEnd = true }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 44, alignment: .trailing)
                }
                .accessibilityLabel("更多")
            }
        }
        .alert("结束这场牌局？", isPresented: $confirmEnd) {
            Button("结束", role: .destructive) { settle(game) }
            Button("再打会儿", role: .cancel) {}
        } message: {
            Text("结束后就不能再记了，会算出谁该给谁转多少。")
        }
        .fullScreenCover(isPresented: $recording) {
            RoundFlowView(game: game, demo: model.demoScreen) { outcome in
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
        .sheet(isPresented: $showGuide) { RulesGuideView() }
        .onAppear {
            if model.demoScreen == .table { justRecorded = game.records.last }
            if model.demoScreen?.opensRound == true { recording = true }
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
            let record = try change(&updated)
            model.update(updated)
            showUndo(for: record)
        } catch let error as GameError {
            recordError = error.message
        } catch {
            recordError = error.localizedDescription
        }
    }

    private func showUndo(for record: HandRecord) {
        undoTimer?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { justRecorded = record }
        undoTimer = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) { justRecorded = nil }
        }
    }

    private func undo(_ record: HandRecord) {
        undoTimer?.cancel()
        guard var updated = model.game(gameID), updated.records.last?.id == record.id else { return }
        updated.undoLast()
        model.update(updated)
        withAnimation(.easeIn(duration: 0.2)) { justRecorded = nil }
    }

    /// 结束牌局（打满 16 局时已经算结束），换到结算页；返回直接回首页。
    private func settle(_ game: Game) {
        var updated = game
        if updated.endedAt == nil { updated.end() }
        model.update(updated)
        model.path = [.settle(game.id)]
    }
}

/// 方桌：我（第一个填的人）在下面，下家在右，对家在上，上家在左。
private struct TableDiagram: View {
    var game: Game

    var body: some View {
        let hand = game.displayHand
        let seating = game.seating(ofRound: game.roundIndex(ofHand: hand))
        let me = game.position(of: 0, inHand: hand)
        let at = { (offset: Int) in seating[(me + offset) % 4] }
        ZStack {
            VStack(spacing: 6) {
                Text(game.prevalentWind(ofHand: hand).name)
                    .font(Theme.serif(56))
                Text(game.isFinished ? "打完了" : "风圈 · 第 \(hand % 4 + 1) 局")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.gray)
            }
            .frame(width: 168, height: 168)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Theme.white)
                    .shadow(color: Theme.ink.opacity(0.04), radius: 1, y: 1)
                    .shadow(color: Theme.ink.opacity(0.05), radius: 12, y: 8)
            }

            SeatLabel(game: game, player: at(2), hand: hand, alignment: .center)
                .frame(maxHeight: .infinity, alignment: .top)
            SeatLabel(game: game, player: at(0), hand: hand, alignment: .center)
                .frame(maxHeight: .infinity, alignment: .bottom)
            SeatLabel(game: game, player: at(3), hand: hand, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            SeatLabel(game: game, player: at(1), hand: hand, alignment: .trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: 304)
    }
}

private struct SeatLabel: View {
    var game: Game
    var player: Int
    var hand: Int
    var alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            HStack(spacing: 6) {
                Text(game.seatWind(of: player, inHand: hand).name)
                    .font(Theme.serif(13))
                    .foregroundStyle(Theme.gray)
                Text(game.players[player].name)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if game.dealer(ofHand: hand) == player && !game.isFinished {
                    DealerStamp(size: 18)
                }
            }
            Text(Theme.signed(game.scores[player]))
                .font(Theme.score(26))
                .foregroundStyle(Theme.scoreColor(game.scores[player]))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        // 左右两边夹在桌子和屏幕边之间，只有 80 宽
        .frame(maxWidth: alignment == .center ? nil : 84,
               alignment: alignment == .leading ? .leading : alignment == .trailing ? .trailing : .center)
    }
}

/// 账本里的一局。
private struct RecordRow: View {
    var number: Int
    var record: HandRecord
    var game: Game

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(number)")
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(Theme.gray)
                    .frame(width: 18, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text(record.title(in: game)).font(.system(size: 16))
                    Text(record.detail(in: game))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.gray)
                }
                Spacer(minLength: 8)
                if let value = record.headline {
                    Text(Theme.signed(value))
                        .font(.system(size: 17).monospacedDigit())
                        .foregroundStyle(Theme.scoreColor(value))
                } else {
                    Text("—").font(.system(size: 17)).foregroundStyle(Theme.gray)
                }
            }
            .padding(.vertical, 14)
            Hairline(color: Theme.lineSoft)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 记下后底部的黑色提示条。
private struct UndoBar: View {
    var text: String
    var undo: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text(text).font(.system(size: 14))
            Button(action: undo) {
                Text("撤销")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(.white.opacity(0.14), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(.leading, 18)
        .padding(.trailing, 4)
        .frame(height: 40)
        .background(Theme.ink, in: Capsule())
    }
}
