import SwiftUI
import MajiangKit

/// 手动记分：照片和算番都不用，直接填四个人的得失分，加起来要等于 0。
struct ManualScoreView: View {
    @Environment(\.dismiss) private var dismiss
    var game: Game
    var onSave: ([Int], String) -> Void

    @State private var texts = ["", "", "", ""]
    @State private var note = ""

    private var values: [Int] { texts.map { Int($0) ?? 0 } }
    private var sum: Int { values.reduce(0, +) }

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
                    Text(sum == 0 ? "合计为 0，可以保存" : "四个人加起来要等于 0，现在差 \(-sum)")
                        .foregroundStyle(sum == 0 ? Theme.green : Theme.amber)
                }
                Section {
                    TextField("备注（可不填）", text: $note)
                }
            }
            .page()
            .navigationTitle("手动记分")
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
                    .disabled(sum != 0 || values.allSatisfy { $0 == 0 })
                }
            }
        }
    }
}
