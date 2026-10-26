import SwiftUI
import MajiangKit

/// 8. 账本：累计分 + 每局记录。最后一局可以左滑撤销。
struct LedgerView: View {
    @Environment(AppModel.self) private var model
    let gameID: UUID

    var body: some View {
        if let game = model.game(gameID) {
            List {
                Section {
                    HStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { i in
                            VStack(spacing: 4) {
                                Text(game.players[i].name).font(.subheadline).lineLimit(1)
                                Text(Theme.signed(game.scores[i]))
                                    .font(.title3.weight(.bold).monospacedDigit())
                                    .foregroundStyle(Theme.scoreColor(game.scores[i]))
                                Text(game.moneyText(game.scores[i]))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Theme.secondaryInk)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    if game.records.isEmpty {
                        Text("还没有记录").foregroundStyle(Theme.secondaryInk)
                    }
                    ForEach(Array(game.records.reversed())) { record in
                        RecordRow(record: record, game: game)
                            .listRowInsets(EdgeInsets())
                            .swipeActions(edge: .trailing) {
                                if record.id == game.records.last?.id {
                                    Button("撤销", role: .destructive) {
                                        var updated = game
                                        updated.undoLast()
                                        model.update(updated)
                                    }
                                }
                            }
                    }
                } header: {
                    Text("每局（最近的在上，最后一局可左滑撤销）")
                }
            }
            .listStyle(.insetGrouped)
            .page()
            .navigationTitle("账本")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
