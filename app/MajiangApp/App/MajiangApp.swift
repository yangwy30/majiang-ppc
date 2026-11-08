import SwiftUI

@main
struct MajiangApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}

/// 没有 tab bar：首页 → 开局 → 牌桌 → 结算。
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var language = LiveLanguage.shared

    var body: some View {
        #if DEBUG
        if let screen = model.demoScreen, let game = DemoData.shareGame(screen, in: model.archive) {
            // 截图：把账本图按真实大小放在屏幕中间
            ScrollView { ShareCard(game: game).padding(.vertical, 40) }
                .frame(maxWidth: .infinity)
                .background(Theme.line.ignoresSafeArea())
                // 文字版也打到控制台，方便对着看（simctl launch --console）
                .onAppear { print(game.shareText) }
        } else {
            stack
        }
        #else
        stack
        #endif
    }

    private var stack: some View {
        @Bindable var model = model
        return NavigationStack(path: $model.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .newGame: NewGameView()
                    case .table(let id): TableView(gameID: id)
                    case .hand(let game, let record): HandDetailView(gameID: game, recordID: record)
                    case .settle(let id): SettleView(gameID: id)
                    }
                }
        }
        // 换了语言：整个界面按新语言重建一遍，已经画好的字全部换掉（停在哪一页由 model.path 记着，不会丢）
        .id(language.localization)
        // 「更多 › 语言」挂在重建范围外面：点了一种语言，底下的界面换过去，这一页留着、对勾跟着动
        .sheet(isPresented: $language.showingSheet) { LanguageSheet() }
        .environment(\.locale, language.locale)
        .tint(Theme.ink)
        .preferredColorScheme(.light)
        // 打开和回到前台时和 iCloud 同步一次（换了手机、另一台设备记过的局会出现）
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { Task { await model.syncNow() } }
        }
    }
}

/// 返回键是自己画的（见 `NavBack`），系统会顺手关掉从左边缘右滑返回；这里打开回来。只有一页时不响应。
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
