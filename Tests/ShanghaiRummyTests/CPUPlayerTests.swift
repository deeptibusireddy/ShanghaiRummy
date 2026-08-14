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
                       level: Int = 1) -> (GameState, Player) {
        let me = Player(
            name: "Bot",
            hand: hand,
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

    // MARK: - VM integration

    @MainActor
    func testViewModelStepPumpsCPUTurn() {
        let built = GameFactory.newVsCPU(you: "You",
                                         cpuNames: ["Bot"],
                                         seed: 7)
        var initial = built.state
        initial.dealerIndex = 0
        initial.currentTurnIndex = 1
        initial.buyDecisionPlayerId = initial.players[1].id
        let vm = GameViewModel(state: initial)
        vm.cpuPlayerIds = built.cpuIds
        // Put the Bot up first. A non-wild discard pauses its turn to offer
        // You a buy.
        vm.runAllCPUTurns()
        if vm.state.currentPlayerId != built.state.players[0].id {
            XCTAssertEqual(
                vm.state.buyDecisionPlayerId,
                built.state.players[0].id
            )
            vm.passBuyOffer()
        }
        XCTAssertEqual(vm.state.currentPlayerId, built.state.players[0].id)
        XCTAssertFalse(vm.isCurrentPlayerCPU)

        // Resolve You's purchase round, discard, and decline any buy offered
        // during the Bot's following turn.
        let you = vm.currentPlayer
        _ = vm.dispatch(.draw(playerId: you.id, source: .stock))
        let card = vm.currentPlayer.hand.max(by: { $0.points < $1.points })!
        _ = vm.dispatch(.discard(playerId: you.id, card: card))
        if vm.state.buyDecisionPlayerId == you.id {
            vm.passBuyOffer()
        }
        XCTAssertTrue(
            vm.state.currentPlayerId == you.id
            || vm.state.phase == .roundEnded
            || vm.state.phase == .gameEnded,
            "After You's discard the auto-pump should have played the Bot's turn"
        )
    }
}
