import SwiftUI

@main
struct ShanghaiRummyApp: App {
    @StateObject private var gameCenter = GameCenterManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(gameCenter)
                .task {
                    guard !CommandLine.arguments.contains("--ui-testing") else {
                        return
                    }
                    await gameCenter.authenticate()
                }
        }
    }
}
