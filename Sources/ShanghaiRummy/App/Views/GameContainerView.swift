import SwiftUI

/// Placeholder game container. Renders a text-only view of the game state so we
/// can drive turns end-to-end before the SpriteKit scene lands in M2b.
///
/// Every action goes through `GameViewModel` so we'll be able to swap the
/// SpriteKit scene in without touching the view model.
struct GameContainerView: View {
    @StateObject var vm: GameViewModel
    let onExit: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                // SpriteKit scene fills the screen.
                GameSceneView(vm: vm)
                    .background(Color(red: 0.32, green: 0.22, blue: 0.14))
                // Overlay controls (error, scoreboard summary, toolbar) drawn
                // above the scene. In M2d these move into the scene proper.
                VStack {
                    Spacer()
                    if let err = vm.lastError {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(.red.opacity(0.85)))
                            .padding(.bottom, 8)
                    }
                }
            }
            .navigationTitle("Hand \(vm.state.currentRound)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Quit") { onExit() }
                }
            }
            .sheet(isPresented: $vm.isBetweenTurns) {
                PassAndPlayView(nextPlayerName: vm.currentPlayerName) {
                    vm.acknowledgeTurnPassed()
                }
                .interactiveDismissDisabled(true)
            }
            .overlay {
                if vm.isHandOver {
                    handOverOverlay
                } else if vm.isGameOver {
                    gameOverOverlay
                }
            }
        }
    }

    // MARK: - Hand / game over overlays

    private var handOverOverlay: some View {
        VStack(spacing: 16) {
            Text("Hand \(vm.state.currentRound) over")
                .font(.title2).bold()
            Text("Levels advance for everyone who went down.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Next hand") { vm.advanceHand() }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
        .padding()
    }

    private var gameOverOverlay: some View {
        VStack(spacing: 16) {
            Text("🎉 Game over")
                .font(.title).bold()
            let names = vm.winnerNames
            if names.count > 1 {
                Text("Co-winners: " + names.joined(separator: ", "))
                    .font(.headline)
            } else {
                Text((names.first ?? "Someone") + " wins!")
                    .font(.headline)
            }
            Button("Back to menu") { onExit() }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
        .padding()
    }
}
