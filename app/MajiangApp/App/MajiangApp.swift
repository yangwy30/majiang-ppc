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

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .newGame: NewGameView()
                    case .table(let id): TableView(gameID: id)
                    case .settle(let id): SettleView(gameID: id)
                    }
                }
        }
        .tint(Theme.ink)
        .preferredColorScheme(.light)
        // 打开和回到前台时和 iCloud 同步一次（换了手机、另一台设备记过的局会出现）
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { Task { await model.syncNow() } }
        }
    }
}
