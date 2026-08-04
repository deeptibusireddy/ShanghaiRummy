import SwiftUI

struct RootView: View {
    @EnvironmentObject var gameCenter: GameCenterManager
    @State private var activeGame: GameViewModel?
    @State private var activeTheme: VisualTheme = .cozyWood
    @State private var showingSetup = false

    var body: some View {
        if let game = activeGame {
            GameContainerView(vm: game, theme: activeTheme) {
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
                .onAppear {
                    if activeGame == nil,
                       CommandLine.arguments.contains("--demo-mid-game") {
                        activeTheme = themeFromArgs()
                        let vm = GameViewModel(state: GameFactory.demoMidGame())
                        if CommandLine.arguments.contains("--demo-stage-triplet") {
                            stageFirstTriplet(in: vm)
                        }
                        activeGame = vm
                    } else if activeGame == nil,
                              CommandLine.arguments.contains("--demo-vs-cpu") {
                        activeTheme = themeFromArgs()
                        let built = GameFactory.newVsCPU(
                            you: "You",
                            cpuNames: ["Alex", "Jordan", "Sam"],
                            seed: 42
                        )
                        let vm = GameViewModel(state: built.state)
                        vm.cpuPlayerIds = built.cpuIds
                        // If it's already a CPU's first turn, let them play.
                        vm.runAllCPUTurns()
                        activeGame = vm
                    } else if activeGame == nil,
                              CommandLine.arguments.contains("--demo-hand-over") {
                        activeTheme = themeFromArgs()
                        activeGame = GameViewModel(state: GameFactory.demoHandOver())
                    } else if activeGame == nil,
                              CommandLine.arguments.contains("--demo-game-over") {
                        activeTheme = themeFromArgs()
                        activeGame = GameViewModel(state: GameFactory.demoGameOver())
                    }
                }
        }
    }

    /// Stage the first triplet-forming set of cards in the current player's
    /// hand (if any) so the meld tray renders in demo screenshots.
    private func stageFirstTriplet(in vm: GameViewModel) {
        let hand = vm.currentPlayer.hand
        let byRank = Dictionary(grouping: hand, by: { $0.rank })
        for (_, cards) in byRank where cards.count >= 3 {
            for card in cards.prefix(3) { vm.toggleStaged(cardId: card.id) }
            vm.isMeldOverlayOpen = true
            return
        }
    }

    private func themeFromArgs() -> VisualTheme {
        if CommandLine.arguments.contains("--theme-felt") { return .casinoFelt }
        if CommandLine.arguments.contains("--theme-minimal") { return .minimalModern }
        return .cozyWood
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
