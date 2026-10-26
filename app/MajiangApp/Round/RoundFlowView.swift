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

    private var checking: Bool { !flow.steps.isEmpty }

    var body: some View {
        // 核对页不是推进来的：拍照页往后退一点、变暗，核对页从下面升上来，牌一张张落进格子里
        ZStack {
            NavigationStack {
                CaptureView(flow: flow) { dismiss() }
            }
            .clipShape(RoundedRectangle(cornerRadius: checking ? 28 : 0, style: .continuous))
            .scaleEffect(checking ? 0.94 : 1, anchor: .top)
            .opacity(checking ? 0.45 : 1)
            .allowsHitTesting(!checking)

            if checking {
                NavigationStack {
                    CheckView(flow: flow, finish: finish)
                }
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: checking)
        .tint(Theme.ink)
        // 拍照页是深色底，状态栏要白字；导航栏的 toolbarColorScheme 管不到整个全屏弹层
        .preferredColorScheme(checking ? .light : .dark)
    }

    private func finish(_ outcome: HandOutcome) {
        flow.showResult = false
        onFinish(outcome)
        dismiss()
    }
}
