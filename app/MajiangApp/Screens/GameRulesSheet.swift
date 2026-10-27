import SwiftUI
import MajiangKit

/// 打到一半改这场的规则。一场只用一套规则：改了以后前面的局一起重算，确认前先看每个人会变成多少。
struct GameRulesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let game: Game
    var onSave: (GameRules) -> Void
    @State private var draft: GameRules

    init(game: Game, onSave: @escaping (GameRules) -> Void) {
        self.game = game
        self.onSave = onSave
        _draft = State(initialValue: game.rules)
    }

    private var changed: Bool { draft != game.rules }

    /// 按新规则重算以后的牌局；改不了（比如圈数少于已经打的局数）时是 nil。
    private var preview: Game? { try? game.changingRules(draft) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !game.records.isEmpty {
                        Text("一场只用一套规则，改了以后前面的局一起重算。")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.gray)
                            .padding(.bottom, 10)
                    }
                    HouseRulesForm(rules: $draft, playedHands: game.currentHandIndex)
                    if changed, !game.records.isEmpty, let updated = preview {
                        previewSection(updated)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .page()
            .navigationTitle("这场的规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .buttonStyle(.text(size: 17))
                }
            }
            .bottomBar {
                Button(buttonTitle) {
                    if changed { onSave(draft) }
                    dismiss()
                }
                .buttonStyle(.primary)
                .disabled(changed && preview == nil)
            }
        }
        .presentationDetents([.large])
    }

    private var buttonTitle: String {
        guard changed else { return "好" }
        return game.records.isEmpty ? "改好了" : "改，前面 \(game.records.count) 局一起重算"
    }

    /// 每个人的分数从多少变成多少；起和调高后不够番的局单独说一句。
    private func previewSection(_ updated: Game) -> some View {
        let old = game.scores
        let new = updated.scores
        let moved = (0..<4).contains { old[$0] != new[$0] }
        let below = updated.winsBelowMinimum.compactMap { record in
            updated.records.firstIndex { $0.id == record.id }.map { "第 \($0 + 1) 局" }
        }
        return VStack(alignment: .leading, spacing: 0) {
            SectionLabel(moved ? "重算以后" : "前面的分数都不受影响")
                .padding(.top, 28)
                .padding(.bottom, 6)
            Hairline()
            ForEach(0..<4, id: \.self) { i in
                HStack(spacing: 10) {
                    Text(game.players[i].name).font(.system(size: 16))
                    Spacer()
                    if old[i] != new[i] {
                        Text(Theme.signed(old[i]))
                            .font(.system(size: 15).monospacedDigit())
                            .strikethrough()
                            .foregroundStyle(Theme.faint)
                        Text("→").font(.system(size: 13)).foregroundStyle(Theme.faint)
                    }
                    Text(Theme.signed(new[i]))
                        .font(Theme.score(20))
                        .foregroundStyle(Theme.scoreColor(new[i]))
                        .frame(minWidth: 52, alignment: .trailing)
                }
                .frame(height: 50)
                Hairline(color: Theme.lineSoft)
            }
            if !below.isEmpty {
                Text("\(below.joined(separator: "、"))的番数不够新的起和，先照样算着；要删可以在账本里点那一局。")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.gray)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
    }
}
