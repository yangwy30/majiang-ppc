import SwiftUI
import MajiangKit

/// 直接改分：家规不一样或者算错了要补救时用。直接填四个人这一局的得失分，加起来要等于 0。
struct ManualScoreView: View {
    @Environment(\.dismiss) private var dismiss
    var game: Game
    var onSave: ([Int], String) -> Void

    @State private var texts = ["", "", "", ""]
    @State private var note = ""

    private var values: [Int] { texts.map { Int($0.trimmingCharacters(in: .whitespaces)) ?? 0 } }
    private var sum: Int { values.reduce(0, +) }
    /// 有填了但不是整数的格子（比如「十」或「1.5」）。
    private var hasInvalid: Bool {
        texts.contains { text in
            let t = text.trimmingCharacters(in: .whitespaces)
            return !t.isEmpty && Int(t) == nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(0..<4, id: \.self) { i in
                        HStack {
                            Text(game.players[i].name)
                            Spacer()
                            TextField("0", text: $texts[i])
                                .keyboardType(.numbersAndPunctuation)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                    }
                } footer: {
                    if hasInvalid {
                        Text("只能填整数，输的分前面加负号").foregroundStyle(Theme.vermilion)
                    } else {
                        Text(sum == 0 ? "合计为 0，可以保存" : "四个人加起来要等于 0，现在差 \(-sum)")
                            .foregroundStyle(Theme.gray)
                    }
                }
                Section {
                    TextField("备注（可不填）", text: $note)
                } footer: {
                    Text("算作一局记进账本，庄家照常往下轮。")
                }
            }
            .page()
            .navigationTitle("直接改分")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onSave(values, note)
                        dismiss()
                    }
                    .disabled(hasInvalid || sum != 0 || values.allSatisfy { $0 == 0 })
                }
            }
        }
    }
}
