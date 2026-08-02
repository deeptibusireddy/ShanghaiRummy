import SwiftUI

@main
struct ShanghaiRummyApp: App {
    @StateObject private var gameCenter = GameCenterManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(gameCenter)
                .task { await gameCenter.authenticate() }
        }
    }
}
