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

/// 只有一条主线：首页 → 牌桌 → 记一局 → 账本，没有 tab bar。
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .newGame: NewGameView()
                    case .table(let id): TableView(gameID: id)
                    case .ledger(let id): LedgerView(gameID: id)
                    case .endGame(let id): EndGameView(gameID: id)
                    case .settings: SettingsView()
                    }
                }
        }
        .tint(Theme.ink)
        .preferredColorScheme(.light)
    }
}
