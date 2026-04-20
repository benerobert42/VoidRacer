import SwiftUI

@main
struct SkiRacingGameApp: App {
    @StateObject private var appState = AppState(engine: GameEngineWrapper())
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            switch appState.currentScreen {
            case .menu:
                MainMenuView()
            case .levelSelect:
                LevelSelectView()
            case .store:
                StoreView()
            case .game:
                GameView()
            case .gameOver:
                GameOverView()
            }
        }
        .ignoresSafeArea()
    }
}
