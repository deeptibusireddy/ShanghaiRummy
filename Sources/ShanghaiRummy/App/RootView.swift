import SwiftUI

struct RootView: View {
    @EnvironmentObject var gameCenter: GameCenterManager
    @State private var activeGame: GameViewModel?
    @State private var activeTheme: VisualTheme = .gameNight
    @State private var showingSetup = false

    var body: some View {
        if let game = gameCenter.onlineGame {
            GameContainerView(vm: game, theme: activeTheme) {
                gameCenter.leaveOnlineMatch()
            }
        } else if gameCenter.hasActiveMatch {
            onlineLobby
        } else if let game = activeGame {
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
                .fullScreenCover(isPresented: $gameCenter.isPresentingMatchmaker) {
                    ZStack(alignment: .bottom) {
                        GameCenterMatchmakerView(manager: gameCenter)
                        if let notice = gameCenter.matchmakerNotice {
                            Text(notice)
                                .font(.footnote.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.black.opacity(0.82), in: Capsule())
                                .padding(.horizontal, 24)
                                .padding(.bottom, 20)
                                .allowsHitTesting(false)
                        }
                    }
                    .ignoresSafeArea()
                }
                .sheet(isPresented: $gameCenter.isPresentingAuthentication) {
                    if let controller = gameCenter.authenticationViewController {
                        GameCenterAuthenticationView(viewController: controller)
                            .ignoresSafeArea()
                    }
                }
                .onAppear {
                    if activeGame == nil,
                       CommandLine.arguments.contains("--demo-mid-game") {
                        activeTheme = themeFromArgs()
                        var state = GameFactory.demoMidGame()
                        if CommandLine.arguments.contains("--demo-stage-triplet") {
                            let playerId = state.currentPlayerId
                            state.players[state.currentTurnIndex].hasGoneDownThisRound = false
                            state.players[state.currentTurnIndex].laidDownThisTurn = false
                            state.melds.removeAll { $0.ownerId == playerId }
                        }
                        let vm = GameViewModel(state: state)
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
    /// hand (if any) so the inline meld tray renders in demo screenshots.
    private func stageFirstTriplet(in vm: GameViewModel) {
        while vm.state.phase == .awaitingDraw {
            let decisionPlayerId = vm.state.buyDecisionPlayerId
            vm.passBuyOffer()
            vm.acknowledgeTurnPassed()
            if vm.state.buyDecisionPlayerId == decisionPlayerId {
                break
            }
        }
        let hand = vm.currentPlayer.hand
        let byRank = Dictionary(grouping: hand, by: { $0.rank })
        for (_, cards) in byRank where cards.count >= 3 {
            for card in cards.prefix(3) { vm.toggleStaged(cardId: card.id) }
            return
        }
    }

    private func themeFromArgs() -> VisualTheme {
        if CommandLine.arguments.contains("--theme-felt") { return .casinoFelt }
        if CommandLine.arguments.contains("--theme-minimal") { return .minimalModern }
        return .gameNight
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

                VStack(spacing: 8) {
                    Button("Invite Family (Game Center)") {
                        gameCenter.beginMatchmaking()
                    }
                    .buttonStyle(.bordered)

                    Button("Quick Pair (2-Player Beta Test)") {
                        gameCenter.beginQuickPair()
                    }
                    .buttonStyle(.bordered)

                    Text("For Quick Pair, tap it on both phones at the same time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .disabled(!gameCenter.isAuthenticated)

                if let error = gameCenter.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button("Practice (vs. CPU)") {
                    // TODO(M2.5): local single-player mode
                }
                .buttonStyle(.bordered)
                .disabled(true)
            }
            .padding()
        }
    }

    private var onlineLobby: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
            Text("Setting up the family table")
                .font(.title2.bold())
            Text(gameCenter.onlineStatusMessage)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Leave Match", role: .destructive) {
                gameCenter.leaveOnlineMatch()
            }
            .buttonStyle(.bordered)
        }
        .padding(32)
    }
}

#Preview {
    RootView().environmentObject(GameCenterManager())
}
