import XCTest
@testable import ShanghaiRummy

final class CPUPlayerTests: XCTestCase {

    // MARK: - Helpers

    private func c(_ suit: Suit, _ rank: Rank) -> Card { Card(suit: suit, rank: rank) }
    private func joker() -> Card { Card.joker() }

    /// Build a minimal GameState with a single player under test at index 0
    /// and a filler opponent at index 1 (so `advanceHand`/turn indices are
    /// exercisable). Round defaults to 1 (contract: 2 triplets).
    private func state(hand: [Card],
                       phase: GameState.Phase = .awaitingDraw,
                       melds: [Meld] = [],
                       discard: [Card] = [],
                       stock: [Card] = Array(repeating: Card(suit: .clubs, rank: .four),
                                             count: 20),
                       hasGoneDown: Bool = false,
                       laidDownThisTurn: Bool = false,
                       buysUsed: Int = 0,
                       level: Int = 1) -> (GameState, Player) {
        let me = Player(
            name: "Bot",
            hand: hand,
            buysUsedThisRound: buysUsed,
            hasGoneDownThisRound: hasGoneDown,
            laidDownThisTurn: laidDownThisTurn,
            currentLevel: level
        )
        let other = Player(name: "Filler", hand: [], currentLevel: level)
        let s = GameState(
            players: [me, other],
            currentRound: 1,
            currentTurnIndex: 0,
            dealerIndex: 1,
            stock: stock,
            discard: discard,
            melds: melds,
            phase: phase,
            stockReshufflesUsed: 0,
            randomSeed: 1
        )
        return (s, me)
    }

    // MARK: - Draw phase

    func testDrawsFromStockWhenDiscardIsNotWild() {
        let (s, me) = state(hand: [c(.hearts, .three)],
                            discard: [c(.hearts, .five)])
        let action = CPUPlayer.nextAction(for: me.id, in: s)
        guard case .draw(_, let src) = action else {
            return XCTFail("Expected .draw, got \(action)")
        }
        XCTAssertEqual(src, .stock)
    }

    func testTakesDiscardWhenTopIsJoker() {
        let (s, me) = state(hand: [c(.hearts, .three)],
                            discard: [c(.hearts, .five), joker()])
        let action = CPUPlayer.nextAction(for: me.id, in: s)
        guard case .draw(_, let src) = action else {
            return XCTFail("Expected .draw, got \(action)")
        }
        XCTAssertEqual(src, .discard)
    }

    func testTakesDiscardWhenTopIsLiveTwo() {
        let (s, me) = state(hand: [c(.hearts, .three)],
                            discard: [c(.spades, .two)])
        let action = CPUPlayer.nextAction(for: me.id, in: s)
        guard case .draw(_, let src) = action else {
            return XCTFail("Expected .draw, got \(action)")
        }
        XCTAssertEqual(src, .discard)
    }

    func testIgnoresDeadTwoOnDiscard() {
        var dead = c(.spades, .two)
        dead = dead.markedDeadIfTwo()
        let (s, me) = state(hand: [c(.hearts, .three)], discard: [dead])
        let action = CPUPlayer.nextAction(for: me.id, in: s)
        guard case .draw(_, let src) = action else {
            return XCTFail("Expected .draw, got \(action)")
        }
        XCTAssertEqual(src, .stock)
    }

    func testTakesDiscardThatCompletesRequiredTriplet() {
        let hand = [
            c(.hearts, .king),
            c(.spades, .king),
            c(.hearts, .three),
        ]
        let (s, me) = state(
            hand: hand,
            discard: [c(.diamonds, .king)]
        )

        let action = CPUPlayer.nextAction(for: me.id, in: s)

        guard case .draw(_, let source) = action else {
            return XCTFail("Expected .draw, got \(action)")
        }
        XCTAssertEqual(source, .discard)
    }

    func testTakesDiscardThatCompletesRequiredSequence() {
        let hand = [
            c(.hearts, .four),
            c(.hearts, .five),
            c(.hearts, .six),
        ]
        let (s, me) = state(
            hand: hand,
            discard: [c(.hearts, .seven)],
            level: 3
        )

        let action = CPUPlayer.nextAction(for: me.id, in: s)

        guard case .draw(_, let source) = action else {
            return XCTFail("Expected .draw, got \(action)")
        }
        XCTAssertEqual(source, .discard)
    }

    func testAcceptsWildDiscardWhenOfferedABuy() {
        var (s, me) = state(
            hand: [c(.hearts, .three)],
            discard: [joker()]
        )
        s.currentTurnIndex = 1
        s.buyDecisionPlayerId = me.id

        XCTAssertEqual(
            CPUPlayer.nextAction(for: me.id, in: s),
            .acceptBuyOffer(playerId: me.id)
        )
    }

    func testPassesNonWildDiscardWhenOfferedABuy() {
        var (s, me) = state(
            hand: [c(.hearts, .three)],
            discard: [c(.hearts, .five)]
        )
        s.currentTurnIndex = 1
        s.buyDecisionPlayerId = me.id

        XCTAssertEqual(
            CPUPlayer.nextAction(for: me.id, in: s),
            .passBuyOffer(playerId: me.id)
        )
    }

    func testBuysUsefulNonWildDiscard() {
        var (s, me) = state(
            hand: [c(.hearts, .king), c(.spades, .king)],
            discard: [c(.diamonds, .king)]
        )
        s.currentTurnIndex = 1
        s.buyDecisionPlayerId = me.id

        XCTAssertEqual(
            CPUPlayer.nextAction(for: me.id, in: s),
            .acceptBuyOffer(playerId: me.id)
        )
    }

    func testConservesEarlyBuyAfterUsingStrategicBudget() {
        var (s, me) = state(
            hand: [c(.hearts, .king), c(.spades, .king)],
            discard: [c(.diamonds, .king)],
            buysUsed: 1
        )
        s.currentTurnIndex = 1
        s.buyDecisionPlayerId = me.id

        XCTAssertEqual(
            CPUPlayer.nextAction(for: me.id, in: s),
            .passBuyOffer(playerId: me.id)
        )
    }

    func testUsesMoreBuyBudgetForLateLevelSequenceProgress() {
        var (s, me) = state(
            hand: [c(.hearts, .four), c(.hearts, .five)],
            discard: [c(.hearts, .six)],
            buysUsed: 1,
            level: 8
        )
        s.currentTurnIndex = 1
        s.buyDecisionPlayerId = me.id

        XCTAssertEqual(
            CPUPlayer.nextAction(for: me.id, in: s),
            .acceptBuyOffer(playerId: me.id)
        )
    }

    func testLateLevelBotBuysEnoughCardsToHoldItsContract() {
        let hand = (0..<11).map { _ in c(.clubs, .king) }
        var (s, me) = state(
            hand: hand,
            discard: [c(.diamonds, .seven)],
            level: 10
        )
        s.currentTurnIndex = 1
        s.buyDecisionPlayerId = me.id

        XCTAssertEqual(
            CPUPlayer.nextAction(for: me.id, in: s),
            .acceptBuyOffer(playerId: me.id)
        )
    }

    func testLateLevelBotPassesOnceContractFitsWithNextDraw() {
        let hand = (0..<15).map { _ in c(.clubs, .king) }
        var (s, me) = state(
            hand: hand,
            discard: [c(.diamonds, .seven)],
            buysUsed: 2,
            level: 10
        )
        s.currentTurnIndex = 1
        s.buyDecisionPlayerId = me.id

        XCTAssertEqual(
            CPUPlayer.nextAction(for: me.id, in: s),
            .passBuyOffer(playerId: me.id)
        )
    }

    func testBuysDiscardThatCompletesExactSizeContract() {
        let hand = [
            c(.hearts, .king),
            c(.spades, .king),
            c(.diamonds, .king),
            c(.hearts, .seven),
            c(.spades, .seven),
        ]
        var (s, me) = state(
            hand: hand,
            discard: [c(.diamonds, .seven)],
            buysUsed: 1
        )
        s.currentTurnIndex = 1
        s.buyDecisionPlayerId = me.id

        XCTAssertEqual(
            CPUPlayer.nextAction(for: me.id, in: s),
            .acceptBuyOffer(playerId: me.id)
        )
    }

    // MARK: - Discard selection

    func testDiscardsHighestPenaltyNonWild() {
        // Ace(15), 5(5), King(10). Should discard the Ace.
        let hand = [c(.hearts, .ace), c(.spades, .five), c(.clubs, .king)]
        let (s, me) = state(hand: hand, phase: .awaitingMeldOrDiscard)
        let action = CPUPlayer.nextAction(for: me.id, in: s)
        guard case .discard(_, let card) = action else {
            return XCTFail("Expected .discard, got \(action)")
        }
        XCTAssertEqual(card.rank, .ace)
    }

    func testKeepsWildsPreferringNonWildDiscard() {
        // Joker (wild) + a low card. Bot must NOT discard the joker.
        let hand = [joker(), c(.clubs, .three)]
        let (s, me) = state(hand: hand, phase: .awaitingMeldOrDiscard)
        let action = CPUPlayer.nextAction(for: me.id, in: s)
        guard case .discard(_, let card) = action else {
            return XCTFail("Expected .discard, got \(action)")
        }
        XCTAssertFalse(card.isWild)
        XCTAssertEqual(card.rank, .three)
    }

    func testPreservesContractPairsInsteadOfDiscardingHighestPoints() {
        let hand = [
            c(.hearts, .ace),
            c(.spades, .ace),
            c(.hearts, .king),
            c(.spades, .king),
            c(.hearts, .queen),
            c(.diamonds, .three),
            c(.clubs, .four),
        ]
        let (s, me) = state(
            hand: hand,
            phase: .awaitingMeldOrDiscard
        )

        let action = CPUPlayer.nextAction(for: me.id, in: s)

        guard case .discard(_, let card) = action else {
            return XCTFail("Expected .discard, got \(action)")
        }
        XCTAssertEqual(card.rank, .queen)
    }

    func testAvoidsDiscardThatExtendsPublicMeldWhenAlternativesTie() {
        let publicQueens = Meld(
            kind: .triplet,
            cards: [
                c(.clubs, .queen),
                c(.diamonds, .queen),
                c(.spades, .queen),
            ],
            ownerId: UUID()
        )
        let hand = [
            c(.hearts, .ace),
            c(.spades, .ace),
            c(.hearts, .king),
            c(.spades, .king),
            c(.hearts, .queen),
            c(.clubs, .jack),
        ]
        let (s, me) = state(
            hand: hand,
            phase: .awaitingMeldOrDiscard,
            melds: [publicQueens]
        )

        let action = CPUPlayer.nextAction(for: me.id, in: s)

        guard case .discard(_, let card) = action else {
            return XCTFail("Expected .discard, got \(action)")
        }
        XCTAssertEqual(card.rank, .jack)
    }

    // MARK: - Contract search

    func testFindsTwoNaturalTripletsForRound1() {
        // Round 1 = triplet(3) + triplet(3). Give exactly two.
        let hand = [
            c(.hearts, .king), c(.spades, .king), c(.diamonds, .king),
            c(.hearts, .seven), c(.spades, .seven), c(.clubs, .seven),
            c(.diamonds, .three),
        ]
        let melds = CPUPlayer.findContractSatisfaction(
            hand: hand,
            contract: RoundSchedule.contract(forRound: 1)!
        )
        XCTAssertNotNil(melds)
        XCTAssertEqual(melds?.count, 2)
        XCTAssertEqual(melds?.flatMap { $0 }.count, 6)
    }

    func testUsesWildToCompleteTriplet() {
        // Only 2 natural Kings + a joker → 1 triplet.
        // Plus 3 natural Queens → 2nd triplet. Should still find.
        let hand = [
            c(.hearts, .king), c(.spades, .king), joker(),
            c(.hearts, .queen), c(.spades, .queen), c(.diamonds, .queen),
        ]
        let melds = CPUPlayer.findContractSatisfaction(
            hand: hand,
            contract: RoundSchedule.contract(forRound: 1)!
        )
        XCTAssertNotNil(melds)
        // Every returned meld must be a valid triplet per the actual validator.
        for m in melds ?? [] {
            switch MeldValidator.validateTriplet(m) {
            case .success: break
            case .failure(let e): XCTFail("Invalid triplet: \(e)")
            }
        }

        func testFindsNaturalTripletOfTwosForContract() {
            let hand = [
                c(.clubs, .two),
                c(.hearts, .two),
                c(.spades, .two),
                c(.clubs, .king),
                c(.hearts, .king),
                c(.spades, .king),
            ]

            let melds = CPUPlayer.findContractSatisfaction(
                hand: hand,
                contract: RoundSchedule.contract(forRound: 1)!
            )

            XCTAssertNotNil(melds)
            XCTAssertTrue(
                melds?.contains {
                    $0.allSatisfy { $0.rank == .two }
                } == true
            )
        }
    }

    func testTripletCandidatesNeverReuseANaturalSuit() {
        let hand = [
            c(.hearts, .king),
            c(.hearts, .king),
            c(.spades, .king),
            c(.diamonds, .king),
        ]
        let candidates = CPUPlayer.candidateTriplets(of: 3, from: hand)

        XCTAssertFalse(candidates.isEmpty)
        for candidate in candidates {
            let naturalSuits = candidate.compactMap {
                $0.isWild ? nil : $0.suit
            }
            XCTAssertEqual(Set(naturalSuits).count, naturalSuits.count)
        }
    }

    func testReturnsNilWhenContractImpossible() {
        // All different ranks & no wilds — no triplet possible.
        let hand = [
            c(.hearts, .three), c(.spades, .five), c(.diamonds, .seven),
            c(.clubs, .nine),
        ]
        let melds = CPUPlayer.findContractSatisfaction(
            hand: hand,
            contract: RoundSchedule.contract(forRound: 1)!
        )
        XCTAssertNil(melds)
    }

    func testFindsSequenceForRound3() {
        // Round 3 = sequence(4) + sequence(4). Two ready-made runs.
        let hand = [
            c(.hearts, .three), c(.hearts, .four), c(.hearts, .five), c(.hearts, .six),
            c(.spades, .eight), c(.spades, .nine), c(.spades, .ten), c(.spades, .jack),
        ]
        let melds = CPUPlayer.findContractSatisfaction(
            hand: hand,
            contract: RoundSchedule.contract(forRound: 3)!
        )
        XCTAssertNotNil(melds)
        XCTAssertEqual(melds?.count, 2)
        for m in melds ?? [] {
            switch MeldValidator.validateSequence(m) {
            case .success: break
            case .failure(let e): XCTFail("Invalid sequence: \(e)")
            }
        }
    }

    func testFindsAceHighSequencesForRound3() {
        let hand = [
            c(.hearts, .jack),
            c(.hearts, .queen),
            c(.hearts, .king),
            c(.hearts, .ace),
            c(.spades, .jack),
            c(.spades, .queen),
            c(.spades, .king),
            c(.spades, .ace),
        ]

        let melds = CPUPlayer.findContractSatisfaction(
            hand: hand,
            contract: RoundSchedule.contract(forRound: 3)!
        )

        XCTAssertEqual(melds?.count, 2)
        for meld in melds ?? [] {
            XCTAssertEqual(
                meld.compactMap(\.rank),
                [.jack, .queen, .king, .ace]
            )
            if case .failure(let error) =
                MeldValidator.validateSequence(meld) {
                XCTFail("Invalid Ace-high sequence: \(error)")
            }
        }
    }

    // MARK: - End-to-end action selection

    func testGoesDownWhenContractSatisfied() {
        let hand = [
            c(.hearts, .king), c(.spades, .king), c(.diamonds, .king),
            c(.hearts, .seven), c(.spades, .seven), c(.clubs, .seven),
            c(.diamonds, .three), c(.diamonds, .four),
        ]
        let (s, me) = state(hand: hand,
                            phase: .awaitingMeldOrDiscard,
                            hasGoneDown: false)
        let action = CPUPlayer.nextAction(for: me.id, in: s)
        guard case .goDown(_, let contract) = action else {
            return XCTFail("Expected .goDown, got \(action)")
        }
        XCTAssertEqual(contract.count, 2)
    }

    func testKeepsADiscardWhenContractWouldConsumeTheWholeHand() {
        let hand = [
            c(.hearts, .king), c(.spades, .king), c(.diamonds, .king),
            c(.hearts, .seven), c(.spades, .seven), c(.clubs, .seven),
        ]
        let (state, _) = state(
            hand: hand,
            phase: .awaitingMeldOrDiscard,
            hasGoneDown: false
        )

        let action = CPUPlayer.nextAction(
            for: state.currentPlayerId,
            in: state
        )

        guard case .discard = action else {
            return XCTFail("The bot must retain a card when first going down")
        }
    }

    func testLaysOffAfterGoingDown() {
        // A matching rank can extend a laid triplet even when its suit repeats.
        let ownerId = UUID()
        let existing = Meld(
            kind: .triplet,
            cards: [c(.hearts, .king), c(.spades, .king), c(.diamonds, .king)],
            ownerId: ownerId
        )
        let repeatedSuit = c(.hearts, .king)
        let hand = [repeatedSuit, c(.hearts, .three)]
        let (s, me) = state(hand: hand,
                            phase: .awaitingMeldOrDiscard,
                            melds: [existing],
                            hasGoneDown: true,
                            laidDownThisTurn: false)
        let action = CPUPlayer.nextAction(for: me.id, in: s)
        guard case .addToMeld(_, let meldId, let atStart, let atEnd) = action else {
            return XCTFail("Expected .addToMeld, got \(action)")
        }
        XCTAssertEqual(meldId, existing.id)
        let added = atStart + atEnd
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.id, repeatedSuit.id)
    }

    func testLaysOffHighestPenaltyPlayableCardFirst() {
        let ownerId = UUID()
        let aceMeld = Meld(
            kind: .triplet,
            cards: [
                c(.hearts, .ace),
                c(.spades, .ace),
                c(.diamonds, .ace),
            ],
            ownerId: ownerId
        )
        let kingMeld = Meld(
            kind: .triplet,
            cards: [
                c(.hearts, .king),
                c(.spades, .king),
                c(.diamonds, .king),
            ],
            ownerId: ownerId
        )
        let ace = c(.clubs, .ace)
        let king = c(.clubs, .king)
        let (s, me) = state(
            hand: [king, ace, c(.clubs, .three)],
            phase: .awaitingMeldOrDiscard,
            melds: [kingMeld, aceMeld],
            hasGoneDown: true
        )

        let action = CPUPlayer.nextAction(for: me.id, in: s)

        guard case .addToMeld(_, _, let atStart, let atEnd) = action else {
            return XCTFail("Expected .addToMeld, got \(action)")
        }
        XCTAssertEqual((atStart + atEnd).first?.id, ace.id)
    }

    func testRedeemsWildWhenItCanBeImmediatelyReplayed() throws {
        let wild = joker()
        let replacement = c(.clubs, .seven)
        let sequence = Meld(
            kind: .sequence,
            cards: [
                c(.clubs, .five),
                c(.clubs, .six),
                wild,
                c(.clubs, .eight),
            ],
            ownerId: UUID()
        )
        let (s, me) = state(
            hand: [replacement, c(.diamonds, .three)],
            phase: .awaitingMeldOrDiscard,
            melds: [sequence],
            hasGoneDown: true
        )

        let redemption = CPUPlayer.nextAction(for: me.id, in: s)

        guard case .redeemWild(
            _,
            let meldId,
            let wildCardId,
            let replacementCard
        ) = redemption else {
            return XCTFail("Expected .redeemWild, got \(redemption)")
        }
        XCTAssertEqual(meldId, sequence.id)
        XCTAssertEqual(wildCardId, wild.id)
        XCTAssertEqual(replacementCard.id, replacement.id)

        let redeemedState = try TurnEngine.apply(redemption, to: s).get()
        let replay = CPUPlayer.nextAction(for: me.id, in: redeemedState)
        guard case .addToMeld(_, _, let atStart, let atEnd) = replay else {
            return XCTFail("Expected immediate wild layoff, got \(replay)")
        }
        XCTAssertEqual((atStart + atEnd).first?.id, wild.id)
    }

    func testDiscardsWhenGoneDownAndNoLayoff() {
        let hand = [c(.diamonds, .three), c(.diamonds, .four)]
        let (s, me) = state(hand: hand,
                            phase: .awaitingMeldOrDiscard,
                            hasGoneDown: true,
                            laidDownThisTurn: true) // cannot lay off this turn
        let action = CPUPlayer.nextAction(for: me.id, in: s)
        guard case .discard = action else {
            return XCTFail("Expected .discard, got \(action)")
        }
    }

    func testTwoPlayerSeed591CompletesWithoutStalling() throws {
        var state = GameFactory.newGame(
            playerNames: ["Bot 1", "Bot 2"],
            seed: 2_000_591
        )

        for _ in 0..<3_000 {
            if state.phase == .gameEnded {
                return
            }
            let action: TurnEngine.Action
            if state.phase == .roundEnded {
                action = .advanceHand(playerId: state.nextDealer.id)
            } else {
                action = CPUPlayer.nextAction(
                    for: state.activePlayerId,
                    in: state
                )
            }
            state = try TurnEngine.apply(action, to: state).get()
        }

        XCTFail(
            "Seed 591 stalled at hand \(state.currentRound), "
                + "levels \(state.players.map(\.currentLevel))"
        )
    }

    // MARK: - VM integration

    func testDefaultBotActionBeatIsReadable() {
        XCTAssertEqual(
            GameViewModel.defaultCPUActionDelay,
            .milliseconds(900)
        )
    }

    @MainActor
    func testAssigningCPUPlayersPacesPendingBotBuyOffer() {
        var state = GameFactory.newGame(
            playerNames: ["You", "Bot"],
            seed: 71
        )
        state.currentTurnIndex = 0
        state.buyDecisionPlayerId = state.players[1].id
        state.discard = [c(.hearts, .five)]
        let humanId = state.players[0].id
        let botId = state.players[1].id
        let humanHandCount = state.players[0].hand.count
        let vm = GameViewModel(state: state, localPlayerId: humanId)

        vm.cpuPlayerIds = [botId]

        XCTAssertEqual(vm.state.phase, .awaitingDraw)
        XCTAssertEqual(vm.state.buyDecisionPlayerId, botId)
        XCTAssertEqual(vm.botTurnActivityText, "Considering the discard…")

        vm.runAllCPUTurns()

        XCTAssertEqual(vm.state.currentPlayerId, humanId)
        XCTAssertEqual(vm.state.phase, .awaitingMeldOrDiscard)
        XCTAssertNil(vm.state.buyDecisionPlayerId)
        XCTAssertEqual(vm.state.players[0].hand.count, humanHandCount + 1)
        XCTAssertEqual(vm.state.players[1].buysUsedThisRound, 0)
    }

    @MainActor
    func testHumanPassLetsBotMakeItsOwnBuyDecision() {
        var state = GameFactory.newGame(
            playerNames: ["You", "Bot"],
            seed: 72
        )
        state.currentTurnIndex = 0
        state.buyDecisionPlayerId = state.players[0].id
        state.discard = [joker()]
        let humanId = state.players[0].id
        let botId = state.players[1].id
        let humanHandCount = state.players[0].hand.count
        let botHandCount = state.players[1].hand.count
        let vm = GameViewModel(state: state, localPlayerId: humanId)
        vm.cpuPlayerIds = [botId]

        vm.passBuyOffer()
        vm.runAllCPUTurns()

        XCTAssertEqual(vm.state.currentPlayerId, humanId)
        XCTAssertEqual(vm.state.phase, .awaitingMeldOrDiscard)
        XCTAssertNil(vm.state.buyDecisionPlayerId)
        XCTAssertEqual(vm.state.players[0].hand.count, humanHandCount + 1)
        XCTAssertEqual(vm.state.players[1].hand.count, botHandCount + 2)
        XCTAssertEqual(vm.state.players[1].buysUsedThisRound, 1)
    }

    @MainActor
    func testHumanPassLetsBotBuyUsefulNonWildDiscard() {
        var state = GameFactory.newGame(
            playerNames: ["You", "Bot"],
            seed: 73
        )
        state.currentTurnIndex = 0
        state.buyDecisionPlayerId = state.players[0].id
        state.players[1].hand = [
            c(.hearts, .king),
            c(.spades, .king),
        ]
        state.discard = [c(.diamonds, .king)]
        let humanId = state.players[0].id
        let botId = state.players[1].id
        let humanHandCount = state.players[0].hand.count
        let botHandCount = state.players[1].hand.count
        let vm = GameViewModel(state: state, localPlayerId: humanId)
        vm.cpuPlayerIds = [botId]

        vm.passBuyOffer()
        vm.runAllCPUTurns()

        XCTAssertEqual(vm.state.currentPlayerId, humanId)
        XCTAssertEqual(vm.state.phase, .awaitingMeldOrDiscard)
        XCTAssertNil(vm.state.buyDecisionPlayerId)
        XCTAssertEqual(vm.state.players[0].hand.count, humanHandCount + 1)
        XCTAssertEqual(vm.state.players[1].hand.count, botHandCount + 2)
        XCTAssertEqual(vm.state.players[1].buysUsedThisRound, 1)
        XCTAssertTrue(
            vm.state.players[1].hand.contains {
                $0.suit == .diamonds && $0.rank == .king
            }
        )
    }

    @MainActor
    func testViewModelStepPumpsCPUTurn() {
        let built = GameFactory.newVsCPU(you: "You",
                                         cpuNames: ["Bot"],
                                         seed: 7)
        var initial = built.state
        let youId = built.localPlayerId
        let botId = built.cpuIds.first!
        let youIndex = initial.players.firstIndex {
            $0.id == youId
        }!
        let botIndex = initial.players.firstIndex {
            $0.id == botId
        }!
        initial.dealerIndex = youIndex
        initial.currentTurnIndex = botIndex
        initial.buyDecisionPlayerId = botId
        let vm = GameViewModel(state: initial)
        vm.cpuPlayerIds = built.cpuIds
        // Put the Bot up first. A non-wild discard pauses its turn to offer
        // You a buy.
        vm.runAllCPUTurns()
        if vm.state.currentPlayerId != youId {
            XCTAssertEqual(
                vm.state.buyDecisionPlayerId,
                youId
            )
            vm.passBuyOffer()
            vm.runAllCPUTurns()
        }
        XCTAssertEqual(vm.state.currentPlayerId, youId)
        XCTAssertFalse(vm.isCurrentPlayerCPU)

        // Resolve You's purchase round, discard, and decline any buy offered
        // during the Bot's following turn.
        let you = vm.currentPlayer
        _ = vm.dispatch(.draw(playerId: you.id, source: .stock))
        vm.runAllCPUTurns()
        let card = vm.currentPlayer.hand.max(by: { $0.points < $1.points })!
        _ = vm.dispatch(.discard(playerId: you.id, card: card))
        vm.runAllCPUTurns()
        if vm.state.buyDecisionPlayerId == you.id {
            vm.passBuyOffer()
            vm.runAllCPUTurns()
        }
        XCTAssertTrue(
            vm.state.currentPlayerId == you.id
            || vm.state.phase == .roundEnded
            || vm.state.phase == .gameEnded,
            "After You's discard the auto-pump should have played the Bot's turn"
        )
    }

    @MainActor
    func testOpeningDrawCeremonyMovesThroughBothStages() {
        let built = GameFactory.newVsCPU(
            you: "You",
            cpuNames: ["Bot"],
            seed: 7
        )
        let vm = GameViewModel(
            state: built.state,
            localPlayerId: built.localPlayerId,
            presentsOpeningDraw: true
        )

        XCTAssertEqual(vm.openingDrawStage, .drawing)
        vm.showOpeningSeatOrder()
        XCTAssertEqual(vm.openingDrawStage, .seating)
        vm.completeOpeningDrawCeremony()
        XCTAssertNil(vm.openingDrawStage)
    }

    @MainActor
    func testOpeningDrawDoesNotReplayAfterPlayHasStarted() {
        let built = GameFactory.newVsCPU(
            you: "You",
            cpuNames: ["Bot"],
            seed: 7
        )
        var progressed = built.state
        progressed.currentTurnIndex = 1
        progressed.buyDecisionPlayerId = progressed.players[1].id

        let vm = GameViewModel(
            state: progressed,
            localPlayerId: built.localPlayerId,
            presentsOpeningDraw: true
        )

        XCTAssertNil(vm.openingDrawStage)
    }

    func testVsCPUTracksHumanIdentityAfterOpeningDrawReordersSeats() {
        let built = GameFactory.newVsCPU(
            you: "You",
            cpuNames: ["Bot 1", "Bot 2", "Bot 3"],
            seed: 7
        )

        XCTAssertEqual(
            built.state.players.first {
                $0.id == built.localPlayerId
            }?.name,
            "You"
        )
        XCTAssertEqual(
            Set(
                built.state.players
                    .filter { built.cpuIds.contains($0.id) }
                    .map(\.name)
            ),
            Set(["Bot 1", "Bot 2", "Bot 3"])
        )
    }
}
