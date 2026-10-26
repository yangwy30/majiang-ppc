import SwiftUI
import MajiangKit

/// 记一局：全屏弹出，拍照 → 核对 → 结果。记下或关掉后回到牌桌。
struct RoundFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var flow: RoundFlow
    var onFinish: (HandOutcome) -> Void

    init(game: Game, demo: DemoScreen? = nil, onFinish: @escaping (HandOutcome) -> Void) {
        let flow = RoundFlow(game: game)
        #if DEBUG
        if let demo { DemoData.prepare(flow, for: demo) }
        #endif
        _flow = State(initialValue: flow)
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
        // 拍照页是深色底，状态栏要白字；导航栏的 toolbarColorScheme 管不到整个全屏弹层
        .preferredColorScheme(flow.steps.isEmpty ? .dark : .light)
    }

    private func finish(_ outcome: HandOutcome) {
        flow.showResult = false
        onFinish(outcome)
        dismiss()
    }
}
