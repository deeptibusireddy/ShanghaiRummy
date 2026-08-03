import SwiftUI

struct RootView: View {
    @EnvironmentObject var gameCenter: GameCenterManager
    @State private var activeGame: GameViewModel?
    @State private var showingSetup = false

    var body: some View {
        if let game = activeGame {
            GameContainerView(vm: game) {
                activeGame = nil
            }
        } else {
            homeMenu
                .sheet(isPresented: $showingSetup) {
                    NewGameSetupView { vm in
                        showingSetup = false
                        activeGame = vm
                    }
                }
        }
    }

    private var homeMenu: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Shanghai Rummy")
                    .font(.largeTitle.bold())

                if gameCenter.isAuthenticated {
                    Text("Signed in as \(gameCenter.displayName)")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Sign in to Game Center to play with family")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("Hot-Seat (Pass & Play)") {
                    showingSetup = true
                }
                .buttonStyle(.borderedProminent)

                Button("Play with Family (Game Center)") {
                    // TODO(M3): present GKTurnBasedMatchmakerViewController
                }
                .buttonStyle(.bordered)
                .disabled(!gameCenter.isAuthenticated)

                Button("Practice (vs. CPU)") {
                    // TODO(M2.5): local single-player mode
                }
                .buttonStyle(.bordered)
                .disabled(true)
            }
            .padding()
        }
    }
}

#Preview {
    RootView().environmentObject(GameCenterManager())
}
