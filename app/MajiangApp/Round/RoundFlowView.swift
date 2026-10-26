import SwiftUI
import MajiangKit

/// 记一局：全屏弹出，拍照 → 核对 → 结果。记下或关掉后回到牌桌。
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
            CaptureView(flow: flow) { dismiss() }
                .navigationDestination(for: RoundStep.self) { _ in
                    CheckView(flow: flow, finish: finish)
                }
        }
        .tint(Theme.ink)
    }

    private func finish(_ outcome: HandOutcome) {
        flow.showResult = false
        onFinish(outcome)
        dismiss()
    }
}
