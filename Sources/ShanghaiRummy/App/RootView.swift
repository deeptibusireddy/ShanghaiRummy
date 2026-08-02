import SwiftUI

struct RootView: View {
    @EnvironmentObject var gameCenter: GameCenterManager

    var body: some View {
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

                Button("Play with Family") {
                    // TODO: present GKTurnBasedMatchmakerViewController
                }
                .buttonStyle(.borderedProminent)
                .disabled(!gameCenter.isAuthenticated)

                Button("Practice (vs. CPU)") {
                    // TODO: local single-player mode
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}

#Preview {
    RootView().environmentObject(GameCenterManager())
}
