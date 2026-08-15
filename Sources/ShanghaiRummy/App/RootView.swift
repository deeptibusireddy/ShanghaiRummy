import SwiftUI

struct RootView: View {
    @EnvironmentObject var gameCenter: GameCenterManager
    @State private var activeGame: GameViewModel?
    @State private var activeTheme: VisualTheme = .gameNight
    @State private var showingFamilyTableSetup = false
    @State private var pendingFamilyTable: FamilyTableConfiguration?

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
                .sheet(
                    isPresented: $showingFamilyTableSetup,
                    onDismiss: startPendingFamilyTable
                ) {
                    FamilyTableSetupView(
                        localPlayerName: gameCenter.displayName,
                        isGameCenterAuthenticated: gameCenter.isAuthenticated
                    ) { configuration in
                        pendingFamilyTable = configuration
                        showingFamilyTableSetup = false
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
                    if CommandLine.arguments.contains(
                        "--demo-family-table-setup"
                    ) {
                        showingFamilyTableSetup = true
                    } else if activeGame == nil,
                       CommandLine.arguments.contains("--demo-six-player-status") {
                        activeTheme = themeFromArgs()
                        let state = GameFactory.demoSixPlayerStatus()
                        let vm = GameViewModel(
                            state: state,
                            localPlayerId: state.players[0].id
                        )
                        if CommandLine.arguments.contains("--demo-scorecard") {
                            vm.presentScorecard()
                        }
                        activeGame = vm
                    } else if activeGame == nil,
                       CommandLine.arguments.contains("--demo-mid-game") {
                        activeTheme = themeFromArgs()
                        var state = GameFactory.demoMidGame()
                        if CommandLine.arguments.contains("--demo-stage-triplet") {
                            let playerId = state.currentPlayerId
                            state.players[state.currentTurnIndex].hasGoneDownThisRound = false
                            state.players[state.currentTurnIndex].laidDownThisTurn = false
                            state.melds.removeAll { $0.ownerId == playerId }
                        }
                        if CommandLine.arguments.contains("--demo-buy-decision") {
                            state.phase = .awaitingDraw
                            state.buyDecisionPlayerId = state.currentPlayerId
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

    private func startPendingFamilyTable() {
        guard let configuration = pendingFamilyTable else { return }
        pendingFamilyTable = nil

        if configuration.invitedHumanCount == 0 {
            startBotOnlyGame(botCount: configuration.botCount)
        } else {
            gameCenter.beginMatchmaking(
                invitedHumanCount: configuration.invitedHumanCount,
                botCount: configuration.botCount
            )
        }
    }

    private func startBotOnlyGame(botCount: Int) {
        let botNames = (0..<botCount).map { "Bot \($0 + 1)" }
        let built = GameFactory.newVsCPU(
            you: "You",
            cpuNames: botNames,
            seed: UInt64.random(in: 0...UInt64.max)
        )
        let viewModel = GameViewModel(
            state: built.state,
            localPlayerId: built.state.players[0].id
        )
        viewModel.cpuPlayerIds = built.cpuIds
        activeGame = viewModel
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
                    Text(
                        "Play with bots now, or sign in to Game Center "
                            + "to invite people."
                    )
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 8) {
                    Button("Create Table") {
                        showingFamilyTableSetup = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("create-table")

                    Text("Choose people, bots, or both.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let error = gameCenter.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

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
