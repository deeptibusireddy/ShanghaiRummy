import SwiftUI

struct RootView: View {
    @EnvironmentObject var gameCenter: GameCenterManager
    @State private var activeGame: GameViewModel?
    @State private var activeTheme: VisualTheme = .gameNight
    @State private var showingFamilyTableSetup = false
    @State private var familyTableConfiguration =
        FamilyTableConfiguration()
    @State private var tableAssemblyConfiguration:
        FamilyTableConfiguration?
    @State private var tableAssemblyHandoffComplete = false
    @State private var isShowingTurnSoundSettings = false
    private let entryFinalistPreview = EntryFinalistLaunchConfiguration.current()
    private let tableAssemblyPreview =
        TableAssemblyLaunchConfiguration.current()

    var body: some View {
        if let preview = entryFinalistPreview {
            EntryFinalistPreviewHost(
                design: preview.design,
                screen: preview.screen
            )
        } else if let preview = tableAssemblyPreview {
            TableAssemblyView(
                configuration: preview.configuration,
                localPlayerName: "Deepti",
                connectedGuestNames: preview.connectedGuestNames,
                isMatchActive: preview.isMatchActive,
                statusMessage: preview.statusMessage,
                errorMessage: nil,
                onChooseGuests: {},
                onEditTable: {},
                onLeaveTable: {}
            )
        } else if showingFamilyTableSetup {
            familyTableSetup
        } else if let configuration = tableAssemblyConfiguration,
                  !tableAssemblyHandoffComplete {
            tableAssemblyView(configuration: configuration)
        } else if let game = gameCenter.onlineGame {
            GameContainerView(vm: game, theme: activeTheme) {
                tableAssemblyConfiguration = nil
                tableAssemblyHandoffComplete = false
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
                .sheet(isPresented: $isShowingTurnSoundSettings) {
                    TurnSoundSettingsView()
                }
                .fullScreenCover(isPresented: $gameCenter.isPresentingMatchmaker) {
                    matchmakerContent(configuration: nil)
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
                              CommandLine.arguments.contains(
                                "--demo-contract-ready"
                              )
                                || CommandLine.arguments.contains(
                                    "--demo-contract-discard-warning"
                                ) {
                        activeTheme = themeFromArgs()
                        activeGame = contractConfirmationDemo(
                            discardWarning: CommandLine.arguments.contains(
                                "--demo-contract-discard-warning"
                            )
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
                        let botId = state.players.first {
                            built.cpuIds.contains($0.id)
                        }!.id
                        state.currentTurnIndex = state.players.firstIndex {
                            $0.id == botId
                        }!
                        state.buyDecisionPlayerId = botId
                        let vm = GameViewModel(
                            state: state,
                            localPlayerId: built.localPlayerId,
                            cpuActionDelay: .seconds(30)
                        )
                        vm.configureCPUPlayers(built.cpuDifficulties)
                        activeGame = vm
                    } else if activeGame == nil,
                              CommandLine.arguments.contains("--demo-vs-cpu") {
                        activeTheme = themeFromArgs()
                        let built = GameFactory.newVsCPU(
                            you: "You",
                            cpuNames: ["Alex", "Jordan", "Sam"],
                            seed: 42
                        )
                        let vm = GameViewModel(
                            state: built.state,
                            localPlayerId: built.localPlayerId
                        )
                        vm.configureCPUPlayers(built.cpuDifficulties)
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

    private func contractConfirmationDemo(
        discardWarning: Bool
    ) -> GameViewModel {
        let firstTriplet = [
            Card(suit: .hearts, rank: .king),
            Card(suit: .spades, rank: .king),
            Card(suit: .diamonds, rank: .king),
        ]
        let secondTriplet = [
            Card(suit: .hearts, rank: .seven),
            Card(suit: .spades, rank: .seven),
            Card(suit: .clubs, rank: .seven),
        ]
        let discard = Card(suit: .clubs, rank: .three)
        let localPlayer = Player(
            name: "You",
            hand: firstTriplet + secondTriplet + [discard]
        )
        let opponent = Player(name: "Morgan")
        let state = GameState(
            players: [localPlayer, opponent],
            currentRound: 1,
            currentTurnIndex: 0,
            dealerIndex: 1,
            stock: [
                Card(suit: .diamonds, rank: .four),
                Card(suit: .clubs, rank: .five),
            ],
            discard: [Card(suit: .hearts, rank: .three)],
            melds: [],
            phase: .awaitingMeldOrDiscard,
            stockReshufflesUsed: 0,
            randomSeed: 44
        )
        let vm = GameViewModel(
            state: state,
            localPlayerId: localPlayer.id
        )
        for card in firstTriplet {
            vm.toggleStaged(cardId: card.id)
        }
        _ = vm.saveStagedAsMeld()
        for card in secondTriplet {
            vm.toggleStaged(cardId: card.id)
        }
        _ = vm.saveStagedAsMeld()
        if discardWarning {
            vm.reviewContractMelds()
            _ = vm.requestDiscard(discard)
        }
        return vm
    }

    private func themeFromArgs() -> VisualTheme {
        if CommandLine.arguments.contains("--theme-felt") { return .casinoFelt }
        if CommandLine.arguments.contains("--theme-minimal") { return .minimalModern }
        return .gameNight
    }

    private func startFamilyTable(
        configuration: FamilyTableConfiguration
    ) {
        showingFamilyTableSetup = false
        tableAssemblyHandoffComplete = false
        if configuration.invitedHumanCount == 0 {
            tableAssemblyConfiguration = nil
            startBotOnlyGame(
                botDifficulties: configuration.botDifficulties
            )
        } else {
            tableAssemblyConfiguration = configuration
            gameCenter.beginMatchmaking(
                invitedHumanCount: configuration.invitedHumanCount,
                botDifficulties: configuration.botDifficulties
            )
        }
    }

    private var familyTableSetup: some View {
        MidnightDecoTableView(
            configuration: $familyTableConfiguration,
            localPlayerName: gameCenter.displayName,
            isGameCenterAuthenticated: gameCenter.isAuthenticated,
            onBack: {
                tableAssemblyConfiguration = nil
                showingFamilyTableSetup = false
            },
            onStart: { configuration in
                startFamilyTable(configuration: configuration)
            }
        )
        .fullScreenCover(isPresented: $gameCenter.isPresentingMatchmaker) {
            matchmakerContent(configuration: nil)
        }
    }

    private func tableAssemblyView(
        configuration: FamilyTableConfiguration
    ) -> some View {
        TableAssemblyView(
            configuration: configuration,
            localPlayerName: gameCenter.displayName,
            connectedGuestNames: gameCenter.connectedGuestNames,
            isMatchActive: gameCenter.hasActiveMatch,
            statusMessage: gameCenter.onlineStatusMessage,
            errorMessage: gameCenter.lastError,
            onChooseGuests: {
                gameCenter.beginMatchmaking(
                    invitedHumanCount:
                        configuration.invitedHumanCount,
                    botDifficulties: configuration.botDifficulties
                )
            },
            onEditTable: {
                gameCenter.leaveOnlineMatch()
                familyTableConfiguration = configuration
                tableAssemblyConfiguration = nil
                tableAssemblyHandoffComplete = false
                showingFamilyTableSetup = true
            },
            onLeaveTable: {
                gameCenter.leaveOnlineMatch()
                tableAssemblyConfiguration = nil
                tableAssemblyHandoffComplete = false
            }
        )
        .task(id: gameCenter.onlineGame != nil) {
            guard gameCenter.onlineGame != nil else { return }
            do {
                try await Task.sleep(for: .seconds(1.4))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            tableAssemblyHandoffComplete = true
        }
        .fullScreenCover(isPresented: $gameCenter.isPresentingMatchmaker) {
            matchmakerContent(configuration: configuration)
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
    }

    @ViewBuilder
    private func matchmakerContent(
        configuration: FamilyTableConfiguration?
    ) -> some View {
        if let configuration {
            VStack(spacing: 0) {
                GameCenterTableContextBanner(
                    configuration: configuration,
                    notice: gameCenter.matchmakerNotice
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    EntryFinalistPalette.midnightDeco.background
                )

                GameCenterMatchmakerView(manager: gameCenter)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(
                EntryFinalistPalette.midnightDeco.background
                    .ignoresSafeArea()
            )
        } else {
            ZStack(alignment: .bottom) {
                GameCenterMatchmakerView(manager: gameCenter)
                if let notice = gameCenter.matchmakerNotice {
                    Text(notice)
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            .black.opacity(0.82),
                            in: Capsule()
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                        .allowsHitTesting(false)
                }
            }
            .ignoresSafeArea()
        }
    }

    private func startBotOnlyGame(
        botDifficulties: [BotDifficulty]
    ) {
        let botCount = botDifficulties.count
        let botNames = (0..<botCount).map { "Bot \($0 + 1)" }
        var seed = CommandLine.arguments.contains("--ui-testing")
            ? UInt64(0)
            : UInt64.random(in: 0...UInt64.max)
        var built = GameFactory.newVsCPU(
            you: "You",
            cpuNames: botNames,
            cpuDifficulties: botDifficulties,
            seed: seed
        )
        if CommandLine.arguments.contains("--ui-testing") {
            while built.state.currentPlayerId != built.localPlayerId,
                  seed < 100 {
                seed += 1
                built = GameFactory.newVsCPU(
                    you: "You",
                    cpuNames: botNames,
                    cpuDifficulties: botDifficulties,
                    seed: seed
                )
            }
        }
        let viewModel = GameViewModel(
            state: built.state,
            localPlayerId: built.localPlayerId,
            presentsOpeningDraw: true
        )
        viewModel.configureCPUPlayers(built.cpuDifficulties)
        activeGame = viewModel
    }

    private var homeMenu: some View {
        BundAfterDarkHomeView(
            localPlayerName: gameCenter.displayName,
            isGameCenterAuthenticated: gameCenter.isAuthenticated,
            errorMessage: gameCenter.lastError,
            onCreateTable: {
                tableAssemblyConfiguration = nil
                tableAssemblyHandoffComplete = false
                familyTableConfiguration = FamilyTableConfiguration()
                showingFamilyTableSetup = true
            },
            onAuthenticate: {
                Task {
                    await gameCenter.authenticate()
                }
            },
            onSoundSettings: {
                isShowingTurnSoundSettings = true
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
