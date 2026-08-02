import XCTest
@testable import ShanghaiRummy

// MARK: - Card helpers

private func c(_ suit: Suit, _ rank: Rank) -> Card { Card(suit: suit, rank: rank) }
private func j() -> Card { .joker() }
private func w(_ suit: Suit) -> Card { Card(suit: suit, rank: .two) } // wild 2

// MARK: - MeldValidator: Triplets

final class MeldValidatorTripletTests: XCTestCase {
    func testValidTripletOfThreeSameRank() {
        let cards = [c(.spades, .seven), c(.hearts, .seven), c(.diamonds, .seven)]
        XCTAssertNoThrow(try MeldValidator.validateTriplet(cards).get())
    }

    func testValidTripletWithOneJoker() {
        let cards = [c(.spades, .seven), c(.hearts, .seven), j()]
        XCTAssertNoThrow(try MeldValidator.validateTriplet(cards).get())
    }

    func testValidTripletWithOneWildTwo() {
        let cards = [c(.spades, .seven), c(.hearts, .seven), w(.diamonds)]
        XCTAssertNoThrow(try MeldValidator.validateTriplet(cards).get())
    }

    func testTripletTooFewCards() {
        let cards = [c(.spades, .seven), c(.hearts, .seven)]
        if case .failure(let e) = MeldValidator.validateTriplet(cards) {
            XCTAssertEqual(e, .tooFewCards(min: 3, got: 2))
        } else { XCTFail("expected tooFewCards") }
    }

    func testTripletMixedRanksFails() {
        let cards = [c(.spades, .seven), c(.hearts, .seven), c(.diamonds, .eight)]
        if case .failure(let e) = MeldValidator.validateTriplet(cards) {
            XCTAssertEqual(e, .tripletMixedRanks)
        } else { XCTFail("expected tripletMixedRanks") }
    }

    func testTripletTooManyWilds() {
        // Triplet of 3 allows max 1 wild.
        let cards = [c(.spades, .seven), j(), j()]
        if case .failure(let e) = MeldValidator.validateTriplet(cards) {
            XCTAssertEqual(e, .tooManyWilds(max: 1, got: 2))
        } else { XCTFail("expected tooManyWilds") }
    }

    func testTripletOfFourWithTwoWilds() {
        // Triplet of 4 allows max 2 wilds.
        let cards = [c(.spades, .seven), c(.hearts, .seven), j(), w(.clubs)]
        XCTAssertNoThrow(try MeldValidator.validateTriplet(cards).get())
    }
}

// MARK: - MeldValidator: Sequences

final class MeldValidatorSequenceTests: XCTestCase {
    func testValidSequenceOfFour() {
        let cards = [c(.clubs, .five), c(.clubs, .six), c(.clubs, .seven), c(.clubs, .eight)]
        XCTAssertNoThrow(try MeldValidator.validateSequence(cards).get())
    }

    func testValidSequenceWithMiddleJoker() {
        let cards = [c(.clubs, .five), c(.clubs, .six), j(), c(.clubs, .eight)]
        XCTAssertNoThrow(try MeldValidator.validateSequence(cards).get())
    }

    func testValidSequenceWithLeadingJoker() {
        // 🃏-♠6-♠7-♠8 → wild = ♠5
        let cards = [j(), c(.spades, .six), c(.spades, .seven), c(.spades, .eight)]
        XCTAssertNoThrow(try MeldValidator.validateSequence(cards).get())
    }

    func testValidSequenceAceLow() {
        let cards = [c(.hearts, .ace), c(.hearts, .two), c(.hearts, .three), c(.hearts, .four)]
        // NOTE: the 2 is wild in this variant. But when presented as the natural
        // ♥2 in a run starting at Ace, positional logic accepts it (its slot is 2).
        // Wild-count-check: only ♥2 is wild → 1 wild in 4-card seq → allowed.
        XCTAssertNoThrow(try MeldValidator.validateSequence(cards).get())
    }

    func testValidSequenceAceHigh() {
        let cards = [c(.hearts, .jack), c(.hearts, .queen), c(.hearts, .king), c(.hearts, .ace)]
        XCTAssertNoThrow(try MeldValidator.validateSequence(cards).get())
    }

    func testSequenceWrapAroundIllegal() {
        // Q-K-A-2 attempted — 2 is wild, so effectively Q-K-A-🃏(wild-3?). Ace high
        // makes end = 14 (A) + 1 = 15 → out of range. Ace low makes A=1, so cards
        // would be 12-13-1-2 (non-monotonic). Both fail.
        let cards = [c(.hearts, .queen), c(.hearts, .king), c(.hearts, .ace), c(.hearts, .two)]
        if case .failure(let e) = MeldValidator.validateSequence(cards) {
            XCTAssertEqual(e, .sequenceNotConsecutive)
        } else { XCTFail("expected sequenceNotConsecutive") }
    }

    func testSequenceMixedSuitsIllegal() {
        let cards = [c(.clubs, .five), c(.hearts, .six), c(.clubs, .seven), c(.clubs, .eight)]
        if case .failure(let e) = MeldValidator.validateSequence(cards) {
            XCTAssertEqual(e, .sequenceMixedSuits)
        } else { XCTFail("expected sequenceMixedSuits") }
    }

    func testSequenceTooShort() {
        let cards = [c(.clubs, .five), c(.clubs, .six), c(.clubs, .seven)]
        if case .failure(let e) = MeldValidator.validateSequence(cards) {
            XCTAssertEqual(e, .tooFewCards(min: 4, got: 3))
        } else { XCTFail("expected tooFewCards") }
    }

    func testSequenceTooManyWilds() {
        // Seq of 4 allows max 2 wilds.
        let cards = [c(.clubs, .five), j(), j(), j()]
        if case .failure(let e) = MeldValidator.validateSequence(cards) {
            XCTAssertEqual(e, .tooManyWilds(max: 2, got: 3))
        } else { XCTFail("expected tooManyWilds") }
    }

    func testSequenceOfSevenWithMultipleWilds() {
        // 5-6-🃏-🃏-9-10-J, all clubs → wilds at 7, 8 positions. 2 wilds; max 3.
        let cards = [
            c(.clubs, .five), c(.clubs, .six), j(), j(),
            c(.clubs, .nine), c(.clubs, .ten), c(.clubs, .jack)
        ]
        XCTAssertNoThrow(try MeldValidator.validateSequence(cards).get())
    }

    func testNonConsecutiveNaturalRanks() {
        let cards = [c(.clubs, .five), c(.clubs, .seven), c(.clubs, .eight), c(.clubs, .nine)]
        if case .failure(let e) = MeldValidator.validateSequence(cards) {
            XCTAssertEqual(e, .sequenceNotConsecutive)
        } else { XCTFail("expected sequenceNotConsecutive") }
    }
}

// MARK: - Scoring

final class ScoringTests: XCTestCase {
    func testPenaltyOfEmptyHandIsZero() {
        XCTAssertEqual(Scoring.penalty(for: []), 0)
    }

    func testPenaltyMixedHand() {
        let hand = [
            c(.hearts, .ace),      // 15
            c(.spades, .king),     // 10
            c(.clubs, .three),     // 5
            w(.diamonds),          // 20
            .joker(),              // 20
        ]
        XCTAssertEqual(Scoring.penalty(for: hand), 70)
    }

    func testEndOfRoundGoOutPlayerScoresZero() {
        let p1 = Player(name: "A", hand: [c(.hearts, .ace)])
        let p2 = Player(name: "B", hand: [c(.hearts, .king)])
        let out = p2.id
        let scores = Scoring.endOfRound(players: [p1, p2], wentOutPlayerId: out)
        XCTAssertEqual(scores[p1.id], 15)
        XCTAssertEqual(scores[p2.id], 0)
    }
}

// MARK: - SeededRNG determinism

final class SeededRNGTests: XCTestCase {
    func testSameSeedProducesSameSequence() {
        var a = SeededRNG(seed: 42)
        var b = SeededRNG(seed: 42)
        for _ in 0..<100 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testDifferentSeedsDiverge() {
        var a = SeededRNG(seed: 42)
        var b = SeededRNG(seed: 43)
        XCTAssertNotEqual(a.next(), b.next())
    }

    func testDeterministicDeckShuffle() {
        var d1 = Deck(playerCount: 4)
        var d2 = Deck(playerCount: 4)
        var r1 = SeededRNG(seed: 12345)
        var r2 = SeededRNG(seed: 12345)
        d1.shuffle(using: &r1)
        d2.shuffle(using: &r2)
        XCTAssertEqual(d1.cards.map(\.id), d2.cards.map(\.id))
    }
}

// MARK: - TurnEngine happy path

final class TurnEngineTests: XCTestCase {
    private func makeGame() -> GameState {
        GameFactory.newGame(playerNames: ["Alice", "Bob", "Carol"], seed: 42)
    }

    func testInitialGameShape() {
        let g = makeGame()
        XCTAssertEqual(g.players.count, 3)
        XCTAssertEqual(g.currentRound, 1)
        XCTAssertEqual(g.phase, .awaitingDraw)
        XCTAssertEqual(g.dealerIndex, 0)
        XCTAssertEqual(g.currentTurnIndex, 1) // player to dealer's left
        for p in g.players {
            XCTAssertEqual(p.hand.count, RulesConfig.handSizeAtDeal)
        }
        XCTAssertEqual(g.discard.count, 1)
    }

    func testDrawFromStock() {
        var g = makeGame()
        let before = g.players[g.currentTurnIndex].hand.count
        let stockBefore = g.stock.count
        let result = TurnEngine.apply(
            .draw(playerId: g.currentPlayerId, source: .stock),
            to: g
        )
        g = try! result.get()
        XCTAssertEqual(g.players[g.currentTurnIndex].hand.count, before + 1)
        XCTAssertEqual(g.stock.count, stockBefore - 1)
        XCTAssertEqual(g.phase, .awaitingMeldOrDiscard)
    }

    func testDrawByWrongPlayerFails() {
        let g = makeGame()
        let wrong = g.players[(g.currentTurnIndex + 1) % g.players.count].id
        let result = TurnEngine.apply(.draw(playerId: wrong, source: .stock), to: g)
        if case .failure(let e) = result {
            XCTAssertEqual(e, .notYourTurn)
        } else { XCTFail("expected notYourTurn") }
    }

    func testDiscardAdvancesTurn() {
        var g = makeGame()
        let pid = g.currentPlayerId
        g = try! TurnEngine.apply(.draw(playerId: pid, source: .stock), to: g).get()
        let toDiscard = g.players[g.currentTurnIndex].hand.first!
        let before = g.currentTurnIndex
        g = try! TurnEngine.apply(.discard(playerId: pid, card: toDiscard), to: g).get()
        XCTAssertEqual(g.currentTurnIndex, (before + 1) % g.players.count)
        XCTAssertEqual(g.phase, .awaitingDraw)
        XCTAssertEqual(g.discard.last?.id, toDiscard.id)
    }

    func testBuyByTurnPlayerFails() {
        let g = makeGame()
        let result = TurnEngine.apply(.buy(playerId: g.currentPlayerId), to: g)
        if case .failure(let e) = result {
            XCTAssertEqual(e, .buyNotAllowedByTurnPlayer)
        } else { XCTFail("expected buyNotAllowedByTurnPlayer") }
    }

    func testBuyByOtherPlayerSucceeds() {
        var g = makeGame()
        let buyerIdx = (g.currentTurnIndex + 1) % g.players.count
        let buyerId = g.players[buyerIdx].id
        let handBefore = g.players[buyerIdx].hand.count
        let discardBefore = g.discard.count
        let stockBefore = g.stock.count
        g = try! TurnEngine.apply(.buy(playerId: buyerId), to: g).get()
        XCTAssertEqual(g.players[buyerIdx].hand.count, handBefore + 1 + RulesConfig.penaltyCardsOnBuy)
        XCTAssertEqual(g.discard.count, discardBefore - 1)
        XCTAssertEqual(g.stock.count, stockBefore - RulesConfig.penaltyCardsOnBuy)
        XCTAssertEqual(g.players[buyerIdx].buysUsedThisRound, 1)
    }

    func testGoingDownRound1Succeeds() {
        // Manufacture a state where player has a valid contract for round 1
        // (two triplets of 3). Bypass random dealing by constructing directly.
        let p1 = Player(name: "A", hand: [
            c(.spades, .seven), c(.hearts, .seven), c(.diamonds, .seven),
            c(.spades, .king), c(.hearts, .king), c(.diamonds, .king),
            c(.clubs, .three), c(.clubs, .four), c(.clubs, .five),
            c(.clubs, .six), c(.clubs, .eight)
        ])
        let p2 = Player(name: "B", hand: [])
        let state = GameState(
            players: [p1, p2],
            currentRound: 1,
            currentTurnIndex: 0,
            dealerIndex: 1,
            stock: [c(.clubs, .nine)],
            discard: [c(.clubs, .ten)],
            melds: [],
            phase: .awaitingMeldOrDiscard, // pretend we already drew
            stockReshufflesUsed: 0,
            randomSeed: 0
        )
        let contract: [[Card]] = [
            [c(.spades, .seven), c(.hearts, .seven), c(.diamonds, .seven)],
            [c(.spades, .king), c(.hearts, .king), c(.diamonds, .king)]
        ]
        let result = TurnEngine.apply(
            .goDown(playerId: p1.id, contract: contract),
            to: state
        )
        let newState = try! result.get()
        XCTAssertTrue(newState.players[0].hasGoneDownThisRound)
        XCTAssertEqual(newState.melds.count, 2)
        XCTAssertEqual(newState.players[0].hand.count, 11 - 6)
    }

    func testGoingDownWithWrongShapeFails() {
        // Round 1 requires 2 triplets. Player attempts 1 triplet only.
        let p1 = Player(name: "A", hand: [
            c(.spades, .seven), c(.hearts, .seven), c(.diamonds, .seven)
        ])
        let p2 = Player(name: "B", hand: [])
        let state = GameState(
            players: [p1, p2], currentRound: 1, currentTurnIndex: 0, dealerIndex: 1,
            stock: [c(.clubs, .nine)], discard: [c(.clubs, .ten)], melds: [],
            phase: .awaitingMeldOrDiscard, stockReshufflesUsed: 0, randomSeed: 0
        )
        let result = TurnEngine.apply(
            .goDown(playerId: p1.id, contract: [
                [c(.spades, .seven), c(.hearts, .seven), c(.diamonds, .seven)]
            ]),
            to: state
        )
        if case .failure(let e) = result {
            if case .invalidContract = e { /* ok */ } else { XCTFail("expected invalidContract, got \(e)") }
        } else { XCTFail("expected failure") }
    }
}
