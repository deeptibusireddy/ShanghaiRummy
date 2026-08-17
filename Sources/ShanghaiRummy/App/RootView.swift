import SwiftUI

struct RootView: View {
    @EnvironmentObject var gameCenter: GameCenterManager
    @State private var activeGame: GameViewModel?
    @State private var activeTheme: VisualTheme = .gameNight
    @State private var showingFamilyTableSetup = false
    @State private var familyTableConfiguration =
        FamilyTableConfiguration()
    @State private var pendingFamilyTable: FamilyTableConfiguration?
    private let entryFinalistPreview = EntryFinalistLaunchConfiguration.current()

    var body: some View {
        if let preview = entryFinalistPreview {
            EntryFinalistPreviewHost(
                design: preview.design,
                screen: preview.screen
            )
        } else if let game = gameCenter.onlineGame {
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
                .fullScreenCover(
                    isPresented: $showingFamilyTableSetup,
                    onDismiss: startPendingFamilyTable
                ) {
                    MidnightDecoTableView(
                        configuration: $familyTableConfiguration,
                        localPlayerName: gameCenter.displayName,
                        isGameCenterAuthenticated:
                            gameCenter.isAuthenticated,
                        onBack: {
                            pendingFamilyTable = nil
                            showingFamilyTableSetup = false
                        },
                        onStart: { configuration in
                            pendingFamilyTable = configuration
                            showingFamilyTableSetup = false
                        }
                    )
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
                .sheet(
                    isPresented: $gameCenter.isPresentingAuthentication,
                    onDismiss: {
                        gameCenter.authenticationDidDismiss()
                    }
                ) {
                    if let controller = gameCenter.authenticationViewController {
                        GameCenterAuthenticationView(viewController: controller)
                            .ignoresSafeArea()
                    }
                }
                .onAppear {
                    if CommandLine.arguments.contains(
                        "--demo-family-table-setup"
                    ) {
                        familyTableConfiguration =
                            FamilyTableConfiguration()
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
                              CommandLine.arguments.contains(
                                "--demo-crowded-new-cards"
                              ) {
                        activeTheme = themeFromArgs()
                        activeGame = GameViewModel(
                            state: GameFactory.demoCrowdedHighlightedHand()
                        )
                    } else if activeGame == nil,
                       CommandLine.arguments.contains("--demo-mid-game") {
                        activeTheme = themeFromArgs()
                        var state = GameFactory.demoMidGame()
                        var localPlayerId: UUID?
                        let stagesTriplet = CommandLine.arguments.contains(
                            "--demo-stage-triplet"
                        )
                        let stagesLongSequence = CommandLine.arguments.contains(
                            "--demo-stage-long-sequence"
                        )
                        if stagesTriplet || stagesLongSequence {
                            let playerId = state.currentPlayerId
                            state.players[state.currentTurnIndex].hasGoneDownThisRound = false
                            state.players[state.currentTurnIndex].laidDownThisTurn = false
                            state.melds.removeAll { $0.ownerId == playerId }
                        }
                        if stagesLongSequence {
                            state.players[state.currentTurnIndex].hand = [
                                Card(suit: .hearts, rank: .three),
                                Card(suit: .hearts, rank: .four),
                                Card(suit: .hearts, rank: .five),
                                Card(suit: .hearts, rank: .six),
                                Card(suit: .hearts, rank: .seven),
                                Card(suit: .hearts, rank: .eight),
                                Card(suit: .hearts, rank: .nine),
                                Card(suit: .spades, rank: .king),
                                Card(suit: .diamonds, rank: .queen),
                                Card(suit: .clubs, rank: .ace),
                                Card.joker(),
                            ]
                        }
                        if CommandLine.arguments.contains("--demo-buy-decision") {
                            state.phase = .awaitingDraw
                            let youId = state.players[0].id
                            state.currentTurnIndex = 1
                            state.players[0].buysUsedThisRound = 1
                            state.players[0].hasGoneDownThisRound = false
                            state.players[0].laidDownThisTurn = false
                            state.melds.removeAll { $0.ownerId == youId }
                            state.buyDecisionPlayerId = youId
                            localPlayerId = youId
                        }
                        let vm = GameViewModel(
                            state: state,
                            localPlayerId: localPlayerId
                        )
                        if stagesLongSequence {
                            stageFirstHeartRun(in: vm)
                        } else if stagesTriplet {
                            stageFirstTriplet(in: vm)
                        }
                        activeGame = vm
                    } else if activeGame == nil,
                              CommandLine.arguments.contains(
                                "--demo-bot-turn"
                              ) {
                        activeTheme = themeFromArgs()
                        let built = GameFactory.newVsCPU(
                            you: "You",
                            cpuNames: ["Alex", "Jordan", "Sam"],
                            seed: 42
                        )
                        var state = built.state
                        state.currentTurnIndex = 1
                        state.buyDecisionPlayerId = state.players[1].id
                        let vm = GameViewModel(
                            state: state,
                            localPlayerId: state.players[0].id,
                            cpuActionDelay: .seconds(30)
                        )
                        vm.cpuPlayerIds = built.cpuIds
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

    private func stageFirstHeartRun(in vm: GameViewModel) {
        for card in vm.currentPlayer.hand
            .filter({ $0.suit == .hearts })
            .prefix(7) {
            vm.toggleStaged(cardId: card.id)
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
        BundAfterDarkHomeView(
            localPlayerName: gameCenter.displayName,
            isGameCenterAuthenticated: gameCenter.isAuthenticated,
            errorMessage: gameCenter.lastError,
            onCreateTable: {
                pendingFamilyTable = nil
                familyTableConfiguration = FamilyTableConfiguration()
                showingFamilyTableSetup = true
            },
            onAuthenticate: {
                Task {
                    await gameCenter.authenticate()
                }
            }
        )
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
