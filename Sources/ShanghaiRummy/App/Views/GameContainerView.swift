import SwiftUI

/// Full-screen gameplay shell. Core turn interactions live in SpriteKit;
/// SwiftUI owns system-level presentation such as quit, pass-and-play privacy,
/// errors, and end-of-hand summaries.
struct GameContainerView: View {
    @StateObject var vm: GameViewModel
    @State private var isConfirmingExit = false
    @State private var isShowingTurnSoundSettings = false
    @State private var saveAlert: SaveAlert?
    @AppStorage(TurnSoundPreferences.enabledKey)
    private var turnSoundsEnabled = true
    let theme: VisualTheme
    let onSaveGame: (() throws -> Void)?
    let onGameCompleted: (() -> Void)?
    let onExit: () -> Void

    init(
        vm: GameViewModel,
        theme: VisualTheme = .gameNight,
        onSaveGame: (() throws -> Void)? = nil,
        onGameCompleted: (() -> Void)? = nil,
        onExit: @escaping () -> Void
    ) {
        _vm = StateObject(wrappedValue: vm)
        self.theme = theme
        self.onSaveGame = onSaveGame
        self.onGameCompleted = onGameCompleted
        self.onExit = onExit
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            GameSceneView(vm: vm, theme: theme)
                .background(Color(theme.background))
                .accessibilityIdentifier("game-table")

            HStack(spacing: 8) {
                Button {
                    isConfirmingExit = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(
                            size: 15,
                            weight: .bold,
                            design: .rounded
                        ))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Leave game")
                .accessibilityIdentifier("quit-game")

                if let onSaveGame,
                   canShowSaveGame {
                    Button {
                        do {
                            try onSaveGame()
                            saveAlert = .saved
                        } catch {
                            saveAlert = .failed(
                                error.localizedDescription
                            )
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(
                                size: 15,
                                weight: .bold,
                                design: .rounded
                            ))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Save solo game")
                    .accessibilityIdentifier("save-bot-game")
                }

                Button {
                    isShowingTurnSoundSettings = true
                } label: {
                    Image(systemName: turnSoundsEnabled
                        ? "speaker.wave.2.fill"
                        : "speaker.slash.fill")
                        .font(.system(
                            size: 15,
                            weight: .bold,
                            design: .rounded
                        ))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    turnSoundsEnabled
                        ? "Turn sound settings, sounds on"
                        : "Turn sound settings, sounds off"
                )
                .accessibilityIdentifier("turn-sound-settings")
            }
            .opacity(vm.isGameOver ? 0 : 1)
            .disabled(vm.isGameOver)
            .accessibilityHidden(vm.isGameOver)
            .padding(.leading, 14)
            .padding(.top, 8)

            VStack {
                Spacer()
                if let err = vm.lastError {
                    Text(err)
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.red.opacity(0.88), in: Capsule())
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .statusBarHidden(true)
        .sheet(isPresented: $isShowingTurnSoundSettings) {
            TurnSoundSettingsView()
        }
        .sheet(isPresented: $vm.isBetweenTurns) {
            PassAndPlayView(nextPlayerName: vm.privacyPlayerName) {
                vm.acknowledgeTurnPassed()
            }
            .interactiveDismissDisabled(true)
        }
        .alert(
            "Leave Game?",
            isPresented: $isConfirmingExit
        ) {
            Button("Keep Playing", role: .cancel) {}
            Button("Leave Game", role: .destructive) {
                onExit()
            }
        } message: {
            Text(exitConfirmationMessage)
        }
        .alert(item: $saveAlert) { alert in
            switch alert {
            case .saved:
                return Alert(
                    title: Text("Game Saved"),
                    message: Text(
                        "You can resume this solo table from the home screen."
                    ),
                    dismissButton: .default(Text("OK"))
                )
            case .failed(let message):
                return Alert(
                    title: Text("Couldn’t Save Game"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onChange(of: vm.state.phase) { _, phase in
            if phase == .gameEnded {
                onGameCompleted?()
            }
        }
        .overlay {
            if let stage = vm.openingDrawStage {
                OpeningDrawView(
                    stage: stage,
                    draws: vm.state.openingDraws,
                    players: vm.state.players,
                    theme: theme,
                    onShowSeatOrder: vm.showOpeningSeatOrder,
                    onContinue: vm.completeOpeningDrawCeremony
                )
            } else if let choice = vm.pendingInitialSequenceChoice {
                initialSequenceChoiceOverlay(choice)
            } else if let choice = vm.pendingSequenceEndChoice {
                sequenceEndChoiceOverlay(choice)
            } else if vm.isGameOver {
                gameOverOverlay
            } else if vm.isHandOver {
                handOverOverlay
            } else if let prompt = vm.contractReadyPrompt {
                contractReadyOverlay(prompt)
            } else if vm.isScorecardPresented {
                liveScorecardOverlay
            } else if vm.isBuyDecisionActive {
                buyDecisionOverlay
            }
        }
        .task {
            await runOpeningDrawCeremony()
        }
    }

    private enum SaveAlert: Identifiable {
        case saved
        case failed(String)

        var id: String {
            switch self {
            case .saved:
                return "saved"
            case .failed(let message):
                return "failed-\(message)"
            }
        }
    }

    private var canShowSaveGame: Bool {
        vm.openingDrawStage == nil
            && !vm.isBuyDecisionActive
            && vm.pendingInitialSequenceChoice == nil
            && vm.pendingSequenceEndChoice == nil
            && vm.contractReadyPrompt == nil
            && !vm.isScorecardPresented
            && !vm.isHandOver
            && !vm.isGameOver
    }

    private func runOpeningDrawCeremony() async {
        if vm.openingDrawStage == .drawing {
            if CommandLine.arguments.contains("--ui-testing") {
                return
            }
            do {
                try await Task.sleep(
                    for: GameViewModel.openingDrawRevealDuration
                )
            } catch {
                return
            }
            guard vm.openingDrawStage == .drawing else { return }
            vm.showOpeningSeatOrder()
        }

        guard vm.openingDrawStage == .seating else { return }
        if CommandLine.arguments.contains("--ui-testing") {
            return
        }
        do {
            try await Task.sleep(
                for: GameViewModel.openingDrawSeatingDuration
            )
        } catch {
            return
        }
        guard vm.openingDrawStage == .seating else { return }
        vm.completeOpeningDrawCeremony()
    }

    private var exitConfirmationMessage: String {
        if vm.isOnlineGame {
            return "You will leave this online table and may not be able to "
                + "rejoin."
        }
        return "Your current game will end and its progress will be lost."
    }

    private func contractReadyOverlay(
        _ prompt: GameViewModel.ContractReadyPrompt
    ) -> some View {
        ContractConfirmationView(
            prompt: prompt,
            level: vm.currentPlayer.currentLevel,
            contractDescription: vm.currentContractDescription,
            savedMelds: vm.contractDraft,
            remainingCardCount: contractReadyRemainingCardCount,
            theme: theme,
            onPutDown: {
                vm.confirmGoDown()
            },
            onReview: {
                vm.reviewContractMelds()
            },
            onDiscardAnyway: {
                vm.discardAnyway()
            }
        )
    }

    private var contractReadyRemainingCardCount: Int {
        let draftCardIds = Set(
            vm.contractDraft.flatMap { meld in meld.map(\.id) }
        )
        return vm.currentPlayer.hand.reduce(into: 0) { count, card in
            if !draftCardIds.contains(card.id) {
                count += 1
            }
        }
    }

    private func sequenceEndChoiceOverlay(
        _ choice: GameViewModel.PendingSequenceEndChoice
    ) -> some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .contentShape(Rectangle())

            VStack(spacing: 14) {
                Text("Choose Sequence End")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(
                    "\(CardNode.shortName(choice.card)) works on either end. Choose the natural position it should represent."
                )
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button(sequenceEndLabel(
                        title: "Low End",
                        representation: choice.startRepresentation
                    )) {
                        vm.chooseSequenceEnd(.start)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("sequence-low-end")

                    Button(sequenceEndLabel(
                        title: "High End",
                        representation: choice.endRepresentation
                    )) {
                        vm.chooseSequenceEnd(.end)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("sequence-high-end")
                }

                Button("Cancel") {
                    vm.cancelSequenceEndChoice()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("cancel-sequence-end")
            }
            .padding(22)
            .frame(maxWidth: 460)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding(28)
        }
        .accessibilityIdentifier("sequence-end-overlay")
        .accessibilityAddTraits(.isModal)
    }

    private func initialSequenceChoiceOverlay(
        _ choice: GameViewModel.PendingInitialSequenceChoice
    ) -> some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .contentShape(Rectangle())

            VStack(spacing: 12) {
                Text("Place Wild Cards")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Choose the sequence each wild should represent.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 240), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(choice.options.indices, id: \.self) { index in
                            Button {
                                vm.chooseInitialSequenceArrangement(at: index)
                            } label: {
                                Text(sequenceArrangementLabel(
                                    choice.options[index]
                                ))
                                .font(.system(
                                    .subheadline,
                                    design: .rounded,
                                    weight: .semibold
                                ))
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier(
                                "initial-sequence-option-\(index)"
                            )
                        }
                    }
                }
                .frame(maxHeight: 210)

                Button("Cancel") {
                    vm.cancelInitialSequenceChoice()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("cancel-initial-sequence-choice")
            }
            .padding(20)
            .frame(maxWidth: 650)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding(24)
        }
        .accessibilityIdentifier("initial-sequence-choice-overlay")
        .accessibilityAddTraits(.isModal)
    }

    private func sequenceArrangementLabel(_ cards: [Card]) -> String {
        let meld = Meld(
            kind: .sequence,
            cards: cards,
            ownerId: vm.currentPlayer.id
        )
        return cards.map { card in
            guard card.isWild,
                  let represented = MeldValidator.representedNatural(
                    for: card.id,
                    in: meld
                  ) else {
                return CardNode.shortName(card)
            }
            let naturalName = CardNode.shortName(
                rank: represented.rank,
                suit: represented.suit
            )
            return "\(CardNode.shortName(card)) → \(naturalName)"
        }.joined(separator: "  •  ")
    }

    private func sequenceEndLabel(
        title: String,
        representation: MeldValidator.WildRepresentation?
    ) -> String {
        guard let representation else { return title }
        let cardName = CardNode.shortName(
            rank: representation.rank,
            suit: representation.suit
        )
        return "\(title) • \(cardName)"
    }

    // MARK: - Hand / game over overlays

    private var liveScorecardOverlay: some View {
        LiveScorecardView(
            rows: vm.liveScoreboard,
            theme: theme,
            onDismiss: {
                vm.dismissScorecard()
            }
        )
    }

    private var buyDecisionOverlay: some View {
        ZStack {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .allowsHitTesting(false)

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    if !vm.isLocalBuyDecision {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(Color(theme.turnGlow))
                    }

                    Text(vm.buyDecisionTitle ?? "Choose How to Draw")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Color(theme.bannerText))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.center)
                }

                if vm.isLocalBuyDecision {
                    localBuyDecision
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(width: 216)
            .background(
                Color(theme.scoreChipBg),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(theme.turnGlow).opacity(0.9), lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.42), radius: 16, y: 7)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("buy-decision-panel")
        }
        .accessibilityIdentifier("buy-decision-overlay")
    }

    @ViewBuilder
    private var localBuyDecision: some View {
        let discard = vm.state.discard.last
        let acceptDisabled =
            !vm.canAcceptBuyOffer || vm.isSubmittingOnlineAction
        let passDisabled =
            !vm.canPassBuyOffer || vm.isSubmittingOnlineAction
        VStack(spacing: 7) {
            if !vm.isTurnPlayersFirstRefusal {
                Text("BUYS LEFT: \(vm.currentPlayerBuysRemaining)")
                    .font(.system(
                        .caption,
                        design: .rounded,
                        weight: .bold
                    ))
                    .foregroundStyle(Color(theme.turnGlow))
                    .accessibilityIdentifier("buy-count")
            }

            HStack(spacing: 8) {
                Button {
                    vm.acceptBuyOffer()
                } label: {
                    buyActionLabel(discard: discard)
                        .background(
                            Color(theme.turnGlow),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .opacity(acceptDisabled ? 0.45 : 1)
                .disabled(acceptDisabled)
                .accessibilityLabel(
                    acceptBuyOfferAccessibilityLabel(for: discard)
                )
                .accessibilityIdentifier("accept-buy-offer")

                Button {
                    vm.passBuyOffer()
                } label: {
                    Text("Pass")
                        .font(.system(
                            .subheadline,
                            design: .rounded,
                            weight: .bold
                        ))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .foregroundStyle(Color(theme.bannerText))
                        .background(
                            Color(theme.scoreChipBg),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    Color(theme.bannerText).opacity(0.75),
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
                .frame(width: 64)
                .opacity(passDisabled ? 0.45 : 1)
                .disabled(passDisabled)
                .accessibilityIdentifier("pass-buy-offer")
            }
        }
    }

    private func buyActionLabel(discard: Card?) -> some View {
        HStack(spacing: 3) {
            Text(vm.isTurnPlayersFirstRefusal ? "Take" : "Buy")
                .font(.system(size: 12, weight: .bold, design: .rounded))

            if let discard {
                compactCardChip(discard)
            } else {
                Text("discard")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }

            if !vm.isTurnPlayersFirstRefusal {
                Text("+1")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
        }
        .foregroundStyle(.black.opacity(0.84))
        .lineLimit(1)
        .frame(maxWidth: .infinity, minHeight: 42)
    }

    private func compactCardChip(_ card: Card) -> some View {
        HStack(spacing: 2) {
            if card.isPrintedJoker {
                Text("J")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color(theme.blackSuit))
                Image(systemName: "star.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color(theme.jokerAccent))
            } else if let rank = card.rank, let suit = card.suit {
                Text(rankGlyph(rank))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color(theme.blackSuit))
                Image(systemName: suitSystemImageName(suit))
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(suitColor(suit))
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 28)
        .background(
            Color(theme.cardFace),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(theme.cardStroke), lineWidth: 1)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func rankGlyph(_ rank: Rank) -> String {
        switch rank {
        case .ace: return "A"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        default: return "\(rank.rawValue)"
        }
    }

    private func suitSystemImageName(_ suit: Suit) -> String {
        switch suit {
        case .clubs: return "suit.club.fill"
        case .diamonds: return "suit.diamond.fill"
        case .hearts: return "suit.heart.fill"
        case .spades: return "suit.spade.fill"
        }
    }

    private func suitColor(_ suit: Suit) -> Color {
        switch suit {
        case .diamonds, .hearts:
            return Color(theme.redSuit)
        case .clubs, .spades:
            return Color(theme.blackSuit)
        }
    }

    private func acceptBuyOfferAccessibilityLabel(
        for discard: Card?
    ) -> String {
        let action = vm.isTurnPlayersFirstRefusal ? "Take" : "Buy"
        let cardName = discard.map(accessibilityName) ?? "discard"
        if vm.isTurnPlayersFirstRefusal {
            return "\(action) \(cardName)"
        }
        return "\(action) \(cardName) plus 1 penalty card"
    }

    private func accessibilityName(_ card: Card) -> String {
        if card.isPrintedJoker { return "joker" }
        guard let rank = card.rank, let suit = card.suit else {
            return "discard"
        }
        let rankName: String
        switch rank {
        case .ace: rankName = "ace"
        case .jack: rankName = "jack"
        case .queen: rankName = "queen"
        case .king: rankName = "king"
        default: rankName = "\(rank.rawValue)"
        }
        return "\(rankName) of \(suit.rawValue)"
    }

    private var handOverOverlay: some View {
        RoundScorecardView(
            handNumber: vm.state.currentRound,
            rows: vm.pendingHandSummary ?? [],
            canAdvance: vm.canAdvanceHand,
            nextDealerName: vm.nextDealerName,
            theme: theme,
            onAdvance: {
                vm.advanceHand()
            }
        )
    }

    private var gameOverOverlay: some View {
        GameOverCelebrationView(
            rows: vm.finalScoreboard ?? [],
            winnerNames: vm.winnerNames,
            theme: theme,
            onExit: onExit
        )
    }
}
