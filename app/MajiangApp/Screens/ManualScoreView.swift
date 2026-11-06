import SwiftUI
import MajiangKit

/// 直接改分：家规不一样或者算错了要补救时用。直接填四个人这一局的得失分，加起来要等于 0。
/// 不让人在键盘上找负号：每人一个「赢 / 输」，键盘只要数字。一局多半是一家赢三家输，所以默认是「输」，
/// 赢的那家点一下；填了三家，第四家差多少直接给出来，点一下填上。
struct ManualScoreView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    var game: Game
    var onSave: ([Int], String) -> Void

    @State private var texts = ["", "", "", ""]
    /// 1 是赢，-1 是输。
    @State private var signs = [-1, -1, -1, -1]
    @State private var note = ""
    @FocusState private var focused: Int?

    private var values: [Int] { (0..<4).map { signs[$0] * (Int(texts[$0]) ?? 0) } }
    private var sum: Int { values.reduce(0, +) }
    private var allZero: Bool { values.allSatisfy { $0 == 0 } }

    /// 只剩一家没填时，这一家填多少正好凑平。
    private var balance: (player: Int, value: Int)? {
        let empty = texts.indices.filter { texts[$0].isEmpty }
        guard empty.count == 1, let i = empty.first else { return nil }
        let rest = values.enumerated().filter { $0.offset != i }.map(\.element).reduce(0, +)
        return rest == 0 ? nil : (i, -rest)
    }

    /// 不能保存时按钮上直接写原因。
    private var saveTitle: String {
        if allZero { return "填上这一局的得失分" }
        if sum != 0 { return "加起来要等于 0" }
        return "记下"
    }

    private var status: String {
        if allZero { return "四个人加起来要等于 0。" }
        if sum > 0 { return "赢的比输的多 \(sum) 分，加起来要等于 0。" }
        if sum < 0 { return "输的比赢的多 \(-sum) 分，加起来要等于 0。" }
        return "加起来正好是 0。"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("家规不一样或者算错了时用：直接填四个人这一局赢了多少、输了多少。")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .fixedSize(horizontal: false, vertical: true)

                    Hairline()
                        .padding(.top, 18)
                    ForEach(0..<4, id: \.self) { i in
                        row(i)
                    }

                    if let balance {
                        Button {
                            signs[balance.player] = balance.value < 0 ? -1 : 1
                            texts[balance.player] = String(abs(balance.value))
                            focused = nil
                        } label: {
                            Text("\(game.players[balance.player].name)填 \(Theme.signed(balance.value))，正好凑平 ›")
                        }
                        .buttonStyle(.text(Theme.ink, size: 15))
                        .padding(.top, 6)
                    } else {
                        Text(status)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.gray)
                            .frame(minHeight: 44)
                            .padding(.top, 6)
                    }

                    SectionLabel("备注")
                        .padding(.top, 24)
                    TextField("可不填，比如「杠上开花按家规多给」", text: $note)
                        .font(.system(size: 16))
                        .focused($focused, equals: 4)
                        .padding(.vertical, 14)
                    Hairline()
                    Text("算作一局记进账本，庄家照常往下轮。")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gray)
                        .padding(.top, 12)
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .page()
            .navigationTitle("直接改分")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                NavClose { dismiss() }
            }
            .bottomBar {
                Button(saveTitle) {
                    onSave(values, note)
                    dismiss()
                }
                .buttonStyle(.primary)
                .disabled(sum != 0 || allZero)
            }
            .onAppear {
                #if DEBUG
                if model.demoScreen == .manualScore {
                    texts = ["40", "16", "8", ""]
                    signs = [1, -1, -1, -1]
                    return
                }
                #endif
                focused = 0
            }
        }
    }

    /// 一行一个人：名字、赢 / 输、分数。点这一行哪儿都是填分。
    private func row(_ i: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text(game.players[i].name)
                    .font(.system(size: 17))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SegmentedSwitch(options: [(1, "赢"), (-1, "输")], selection: $signs[i])
                    .frame(width: 96)
                TextField("0", text: $texts[i])
                    .keyboardType(.numberPad)
                    .focused($focused, equals: i)
                    .font(Theme.score(26))
                    .foregroundStyle(Theme.scoreColor(values[i]))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                    .onChange(of: texts[i]) { _, new in
                        // 只收数字（粘贴进来的也一样），最多 5 位
                        let digits = String(new.filter(\.isASCIIDigit).prefix(5))
                        let cleaned = digits.isEmpty ? "" : String(Int(digits) ?? 0)
                        if cleaned != new { texts[i] = cleaned }
                    }
                    .accessibilityLabel("\(game.players[i].name)\(signs[i] > 0 ? "赢" : "输")的分")
            }
            .frame(minHeight: 64)
            .contentShape(Rectangle())
            .onTapGesture { focused = i }
            Hairline(color: Theme.lineSoft)
        }
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
