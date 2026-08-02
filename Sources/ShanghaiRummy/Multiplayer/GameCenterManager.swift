import Foundation
import GameKit

/// Wraps Game Center authentication and (later) turn-based matchmaking.
@MainActor
final class GameCenterManager: NSObject, ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var displayName: String = ""
    @Published private(set) var lastError: String?

    func authenticate() async {
        let localPlayer = GKLocalPlayer.local
        localPlayer.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.lastError = error.localizedDescription
                    self.isAuthenticated = false
                    return
                }
                if viewController != nil {
                    self.lastError = "Game Center sign-in required"
                    self.isAuthenticated = false
                    return
                }
                self.isAuthenticated = localPlayer.isAuthenticated
                self.displayName = localPlayer.displayName
            }
        }
    }

    // TODO: findMatch(), submitTurn(matchData:), GKTurnBasedEventListener.
}
