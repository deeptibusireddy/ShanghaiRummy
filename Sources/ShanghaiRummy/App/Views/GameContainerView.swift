import SwiftUI

/// Full-screen gameplay shell. Core turn interactions live in SpriteKit;
/// SwiftUI owns system-level presentation such as quit, pass-and-play privacy,
/// errors, and end-of-hand summaries.
struct GameContainerView: View {
    @StateObject var vm: GameViewModel
    let theme: VisualTheme
    let onExit: () -> Void

    init(vm: GameViewModel, theme: VisualTheme = .gameNight, onExit: @escaping () -> Void) {
        _vm = StateObject(wrappedValue: vm)
        self.theme = theme
        self.onExit = onExit
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            GameSceneView(vm: vm, theme: theme)
                .background(Color(theme.background))
                .accessibilityIdentifier("game-table")

            Button(action: onExit) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quit game")
            .accessibilityIdentifier("quit-game")
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
        .sheet(isPresented: $vm.isBetweenTurns) {
            PassAndPlayView(nextPlayerName: vm.privacyPlayerName) {
                vm.acknowledgeTurnPassed()
            }
            .interactiveDismissDisabled(true)
        }
        .overlay {
            if let choice = vm.pendingInitialSequenceChoice {
                initialSequenceChoiceOverlay(choice)
            } else if let choice = vm.pendingSequenceEndChoice {
                sequenceEndChoiceOverlay(choice)
            } else if vm.isBuyDecisionActive {
                buyDecisionOverlay
            } else if vm.isHandOver {
                handOverOverlay
            } else if vm.isGameOver {
                gameOverOverlay
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

    private var buyDecisionOverlay: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())

            HStack(spacing: 12) {
                if !vm.isLocalBuyDecision {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(vm.buyDecisionTitle ?? "Choose How to Draw")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .lineLimit(1)

                if vm.isLocalBuyDecision {
                    Spacer(minLength: 12)
                    localBuyDecision
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: 640)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
            .padding(.top, 8)
            .padding(.horizontal, 72)
        }
        .accessibilityIdentifier("buy-decision-overlay")
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private var localBuyDecision: some View {
        let discardName = vm.state.discard.last.map(CardNode.shortName) ?? "discard"
        let acceptTitle = vm.isTurnPlayersFirstRefusal
            ? "Take \(discardName)"
            : "Buy \(discardName) + 1"
        let passTitle = vm.isTurnPlayersFirstRefusal
            ? "Offer Clockwise"
            : "Pass"
        HStack(spacing: 12) {
            Button(acceptTitle) {
                vm.acceptBuyOffer()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!vm.canAcceptBuyOffer || vm.isSubmittingOnlineAction)
            .accessibilityIdentifier("accept-buy-offer")

            Button(passTitle) {
                vm.passBuyOffer()
            }
            .buttonStyle(.bordered)
            .disabled(!vm.canPassBuyOffer || vm.isSubmittingOnlineAction)
            .accessibilityIdentifier("pass-buy-offer")
        }
    }

    private var handOverOverlay: some View {
        VStack(spacing: 14) {
            Text("Hand \(vm.state.currentRound) Over")
                .font(.title2).bold()
            let outName = vm.pendingHandSummary?.first(where: { $0.wentOut })?.name
            if let out = outName {
                Text("\(out) went out")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            scoreTable
            if vm.canAdvanceHand {
                Button("Deal Next Hand") { vm.advanceHand() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            } else {
                Text("Waiting for \(vm.currentPlayerName) to deal the next hand")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: 460)
        .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
        .padding()
    }

    @ViewBuilder
    private var scoreTable: some View {
        let rows = vm.pendingHandSummary ?? []
        VStack(spacing: 6) {
            HStack {
                Text("Player").frame(maxWidth: .infinity, alignment: .leading)
                Text("Lvl").frame(width: 44, alignment: .trailing)
                Text("Round").frame(width: 60, alignment: .trailing)
                Text("Total").frame(width: 60, alignment: .trailing)
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            Divider()
            ForEach(rows) { row in
                HStack {
                    HStack(spacing: 6) {
                        Text(row.name).bold()
                        if row.wentOut {
                            Text("• out")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                        if row.didLevelUp && !row.wentOut {
                            Text("• down")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 2) {
                        Text("\(row.currentLevel)")
                        if row.didLevelUp {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                    .frame(width: 44, alignment: .trailing)

                    Text("\(row.roundPoints)")
                        .frame(width: 60, alignment: .trailing)
                        .foregroundStyle(row.roundPoints == 0 ? .green : .primary)
                    Text("\(row.totalAfter)")
                        .frame(width: 60, alignment: .trailing)
                        .bold()
                }
                .font(.body)
            }
        }
    }

    private var gameOverOverlay: some View {
        VStack(spacing: 14) {
            Text("🎉 Game Over")
                .font(.title).bold()
            let names = vm.winnerNames
            if names.count > 1 {
                Text("Co-winners: " + names.joined(separator: ", "))
                    .font(.headline)
            } else {
                Text((names.first ?? "Someone") + " wins!")
                    .font(.headline)
            }
            finalTable
            Button("Back to Menu") { onExit() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: 460)
        .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
        .padding()
    }

    @ViewBuilder
    private var finalTable: some View {
        let rows = vm.finalScoreboard ?? []
        VStack(spacing: 6) {
            HStack {
                Text("Rank").frame(width: 44, alignment: .leading)
                Text("Player").frame(maxWidth: .infinity, alignment: .leading)
                Text("Lvl").frame(width: 44, alignment: .trailing)
                Text("Total").frame(width: 60, alignment: .trailing)
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            Divider()
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                HStack {
                    Text("\(i + 1)")
                        .frame(width: 44, alignment: .leading)
                        .foregroundStyle(row.isWinner ? .yellow : .primary)
                    HStack(spacing: 6) {
                        Text(row.name).bold()
                        if row.isWinner {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(row.currentLevel)")
                        .frame(width: 44, alignment: .trailing)
                    Text("\(row.totalScore)")
                        .frame(width: 60, alignment: .trailing)
                        .bold()
                }
                .font(.body)
            }
        }
    }
}
