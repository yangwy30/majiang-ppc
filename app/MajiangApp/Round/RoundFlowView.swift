import SwiftUI
import MajiangKit

/// 记一局的整个流程，全屏弹出，做完或取消后回到牌桌。
struct RoundFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var flow: RoundFlow
    var onFinish: (HandOutcome) -> Void

    init(game: Game, onFinish: @escaping (HandOutcome) -> Void) {
        _flow = State(initialValue: RoundFlow(game: game))
        self.onFinish = onFinish
    }

    var body: some View {
        NavigationStack(path: $flow.steps) {
            CaptureView(flow: flow)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("取消") { dismiss() }
                    }
                }
                .navigationDestination(for: RoundStep.self) { step in
                    switch step {
                    case .confirm: ConfirmTilesView(flow: flow)
                    case .notWin: NotWinView(flow: flow, finish: finish)
                    case .details: WinDetailsView(flow: flow)
                    case .result: ResultView(flow: flow, finish: finish)
                    }
                }
        }
        .tint(Theme.ink)
    }

    private func finish(_ outcome: HandOutcome) {
        onFinish(outcome)
        dismiss()
    }
}

/// 选谁和了：四个名字的分段选择。
struct PlayerPicker: View {
    var game: Game
    @Binding var selection: Int
    var excluded: Int?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                let selected = selection == i
                Button {
                    selection = i
                } label: {
                    Text(game.players[i].name)
                        .font(.subheadline.weight(selected ? .semibold : .regular))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(selected ? .white : Theme.ink)
                        .background(selected ? Theme.ink : Theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(selected ? .clear : Theme.border))
                }
                .buttonStyle(.plain)
                .disabled(i == excluded)
                .opacity(i == excluded ? 0.35 : 1)
            }
        }
    }
}
