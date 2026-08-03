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
        // Cards get fresh UUIDs on each Deck() build, so IDs will never match.
        // What we care about is that the *permutation of card identities*
        // (suit+rank+joker flag) is identical between two identically-seeded
        // shuffles of two freshly-built decks.
        func signature(_ c: Card) -> String {
            if c.isPrintedJoker { return "J" }
            return "\(c.suit!.rawValue)-\(c.rank!.rawValue)"
        }
        var d1 = Deck(playerCount: 4)
        var d2 = Deck(playerCount: 4)
        var r1 = SeededRNG(seed: 12345)
        var r2 = SeededRNG(seed: 12345)
        d1.shuffle(using: &r1)
        d2.shuffle(using: &r2)
        XCTAssertEqual(d1.cards.map(signature), d2.cards.map(signature))
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
        // (two triplets of 3). Bind cards to variables so the contract
        // references the SAME Card instances (same UUIDs) as the hand.
        let s7 = c(.spades, .seven); let h7 = c(.hearts, .seven); let d7 = c(.diamonds, .seven)
        let sK = c(.spades, .king);  let hK = c(.hearts, .king);  let dK = c(.diamonds, .king)
        let filler = [
            c(.clubs, .three), c(.clubs, .four), c(.clubs, .five),
            c(.clubs, .six),   c(.clubs, .eight)
        ]
        let p1 = Player(name: "A", hand: [s7, h7, d7, sK, hK, dK] + filler)
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
        let contract: [[Card]] = [[s7, h7, d7], [sK, hK, dK]]
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
        let s7 = c(.spades, .seven); let h7 = c(.hearts, .seven); let d7 = c(.diamonds, .seven)
        let p1 = Player(name: "A", hand: [s7, h7, d7])
        let p2 = Player(name: "B", hand: [])
        let state = GameState(
            players: [p1, p2], currentRound: 1, currentTurnIndex: 0, dealerIndex: 1,
            stock: [c(.clubs, .nine)], discard: [c(.clubs, .ten)], melds: [],
            phase: .awaitingMeldOrDiscard, stockReshufflesUsed: 0, randomSeed: 0
        )
        let result = TurnEngine.apply(
            .goDown(playerId: p1.id, contract: [[s7, h7, d7]]),
            to: state
        )
        if case .failure(let e) = result {
            if case .invalidContract = e { /* ok */ } else { XCTFail("expected invalidContract, got \(e)") }
        } else { XCTFail("expected failure") }
    }
}

// MARK: - Dead 2 rules

final class Dead2Tests: XCTestCase {
    func testFreshTwoIsWildAndWorth20() {
        let two = c(.hearts, .two)
        XCTAssertTrue(two.isWild)
        XCTAssertEqual(two.points, 20)
    }

    func testMarkedDead2IsNotWildAndWorth5() {
        let dead = c(.hearts, .two).markedDeadIfTwo()
        XCTAssertFalse(dead.isWild)
        XCTAssertEqual(dead.points, 5)
    }

    func testMarkedDeadIsIdempotentAndPreservesId() {
        let two = c(.hearts, .two)
        let dead = two.markedDeadIfTwo().markedDeadIfTwo()
        XCTAssertTrue(dead.isDead2)
        XCTAssertEqual(dead.id, two.id)
    }

    func testMarkedDeadIsNoopForNonTwos() {
        let ace = c(.hearts, .ace)
        let joker = Card.joker()
        XCTAssertFalse(ace.markedDeadIfTwo().isDead2)
        XCTAssertTrue(joker.markedDeadIfTwo().isWild) // jokers stay wild
    }

    func testDiscardingATwoMakesItDeadInThePile() {
        // Player draws, then discards a 2. It should land on the pile dead.
        let two = c(.hearts, .two)
        let filler = c(.spades, .five)
        let p1 = Player(name: "A", hand: [two, filler])
        let p2 = Player(name: "B", hand: [c(.clubs, .three)])
        var g = GameState(
            players: [p1, p2], currentRound: 1, currentTurnIndex: 0, dealerIndex: 1,
            stock: [c(.clubs, .four)], discard: [c(.clubs, .ten)], melds: [],
            phase: .awaitingMeldOrDiscard, stockReshufflesUsed: 0, randomSeed: 0
        )
        g = try! TurnEngine.apply(.discard(playerId: p1.id, card: two), to: g).get()
        let top = g.discard.last!
        XCTAssertEqual(top.rank, .two)
        XCTAssertTrue(top.isDead2)
        XCTAssertFalse(top.isWild)
        XCTAssertEqual(top.points, 5)
    }

    func testDrawingDead2FromDiscardKeepsItDead() {
        // Discard pile top is a dead 2. Next player draws it. It stays dead in hand.
        let dead2 = c(.hearts, .two).markedDeadIfTwo()
        let p1 = Player(name: "A", hand: [c(.clubs, .three)])
        let p2 = Player(name: "B", hand: [])
        var g = GameState(
            players: [p1, p2], currentRound: 1, currentTurnIndex: 0, dealerIndex: 1,
            stock: [c(.clubs, .four)], discard: [dead2], melds: [],
            phase: .awaitingDraw, stockReshufflesUsed: 0, randomSeed: 0
        )
        g = try! TurnEngine.apply(.draw(playerId: p1.id, source: .discard), to: g).get()
        let drawn = g.players[0].hand.last!
        XCTAssertEqual(drawn.id, dead2.id)
        XCTAssertTrue(drawn.isDead2)
        XCTAssertFalse(drawn.isWild)
    }

    func testBuyingDead2KeepsItDead() {
        let dead2 = c(.hearts, .two).markedDeadIfTwo()
        let p1 = Player(name: "A", hand: [])          // turn player
        let p2 = Player(name: "B", hand: [])          // buyer
        var g = GameState(
            players: [p1, p2], currentRound: 1, currentTurnIndex: 0, dealerIndex: 1,
            stock: [c(.clubs, .four), c(.clubs, .five)], // enough for buy + penalty
            discard: [dead2], melds: [],
            phase: .awaitingDraw, stockReshufflesUsed: 0, randomSeed: 0
        )
        g = try! TurnEngine.apply(.buy(playerId: p2.id), to: g).get()
        // Buyer received the dead 2 plus penalty; the dead 2 should still be dead.
        let received = g.players[1].hand.first(where: { $0.id == dead2.id })!
        XCTAssertTrue(received.isDead2)
        XCTAssertFalse(received.isWild)
    }

    func testDead2ScoredAsFiveInHand() {
        let dead2 = c(.hearts, .two).markedDeadIfTwo()
        let ace = c(.spades, .ace)
        XCTAssertEqual(Scoring.penalty(for: [dead2, ace]), 5 + 15)
    }

    func testDead2InSequenceAtFacePositionIsLegal() {
        // ♥A-(dead♥2)-♥3-♥4 : dead 2 sits at its natural rank slot in a heart run.
        let dead2 = c(.hearts, .two).markedDeadIfTwo()
        let cards = [c(.hearts, .ace), dead2, c(.hearts, .three), c(.hearts, .four)]
        XCTAssertNoThrow(try MeldValidator.validateSequence(cards).get())
    }

    func testDead2CannotSubstituteForOtherPositionInSequence() {
        // Try ♥5-♥6-(dead♥2)-♥8. Dead 2 is treated as its natural rank (2),
        // which breaks the run. Must fail.
        let dead2 = c(.hearts, .two).markedDeadIfTwo()
        let cards = [c(.hearts, .five), c(.hearts, .six), dead2, c(.hearts, .eight)]
        if case .failure(let e) = MeldValidator.validateSequence(cards) {
            XCTAssertEqual(e, .sequenceNotConsecutive)
        } else { XCTFail("expected sequenceNotConsecutive") }
    }

    func testDead2CannotJoinTripletOfSevens() {
        // A dead 2 has rank 2 and is not wild — mixed ranks in a triplet of 7s.
        let dead2 = c(.spades, .two).markedDeadIfTwo()
        let cards = [c(.spades, .seven), c(.hearts, .seven), dead2]
        if case .failure(let e) = MeldValidator.validateTriplet(cards) {
            XCTAssertEqual(e, .tripletMixedRanks)
        } else { XCTFail("expected tripletMixedRanks") }
    }
}

// MARK: - Wild redemption from sequences

final class WildRedemptionTests: XCTestCase {

    /// Build a two-player state where p1 has already gone down (on an earlier
    /// turn) and the table has a single sequence meld with the given cards.
    /// p1 holds `handExtras` plus we place them in `awaitingMeldOrDiscard`
    /// with `laidDownThisTurn: false` — i.e., this is a *later* turn.
    private func stateWithSequence(
        meldCards: [Card],
        p1Hand: [Card]
    ) -> (GameState, Player, Player, Meld) {
        let p1 = Player(
            name: "A", hand: p1Hand,
            hasGoneDownThisRound: true, laidDownThisTurn: false
        )
        let p2 = Player(name: "B", hand: [])
        let meld = Meld(kind: .sequence, cards: meldCards, ownerId: p2.id)
        let state = GameState(
            players: [p1, p2], currentRound: 1, currentTurnIndex: 0, dealerIndex: 1,
            stock: [c(.clubs, .nine)], discard: [c(.clubs, .ten)],
            melds: [meld],
            phase: .awaitingMeldOrDiscard,
            stockReshufflesUsed: 0, randomSeed: 0
        )
        return (state, p1, p2, meld)
    }

    func testRedeemJokerWithExactPositionalCardSucceeds() {
        // ♣5 ♣6 🃏 ♣8 → hand ♣7 → redeem joker.
        let joker = Card.joker()
        let c7 = c(.clubs, .seven)
        let (g, p1, _, meld) = stateWithSequence(
            meldCards: [c(.clubs, .five), c(.clubs, .six), joker, c(.clubs, .eight)],
            p1Hand: [c7]
        )
        let result = TurnEngine.apply(
            .redeemWild(playerId: p1.id, meldId: meld.id,
                        wildCardId: joker.id, replacementCard: c7),
            to: g
        )
        let new = try! result.get()
        XCTAssertEqual(new.melds[0].cards[2].id, c7.id)
        XCTAssertEqual(new.melds[0].wildCount, 0)
        XCTAssertTrue(new.players[0].hand.contains(where: { $0.id == joker.id }))
        XCTAssertFalse(new.players[0].hand.contains(where: { $0.id == c7.id }))
    }

    func testRedeemLiveWildTwoFromSequenceSucceeds() {
        // ♣5 ♣6 (♠2 wild for ♣7) ♣8 → redeem with ♣7.
        let wild2 = c(.spades, .two) // live wild 2 (never touched discard)
        let c7 = c(.clubs, .seven)
        let (g, p1, _, meld) = stateWithSequence(
            meldCards: [c(.clubs, .five), c(.clubs, .six), wild2, c(.clubs, .eight)],
            p1Hand: [c7]
        )
        let new = try! TurnEngine.apply(
            .redeemWild(playerId: p1.id, meldId: meld.id,
                        wildCardId: wild2.id, replacementCard: c7),
            to: g
        ).get()
        XCTAssertEqual(new.melds[0].cards[2].id, c7.id)
        XCTAssertTrue(new.players[0].hand.contains(where: { $0.id == wild2.id }))
    }

    func testRedeemWithWrongPositionalCardFails() {
        // Player tries to hand ♣3 for the joker in ♣5 ♣6 🃏 ♣8.
        let joker = Card.joker()
        let wrong = c(.clubs, .three)
        let (g, p1, _, meld) = stateWithSequence(
            meldCards: [c(.clubs, .five), c(.clubs, .six), joker, c(.clubs, .eight)],
            p1Hand: [wrong]
        )
        let result = TurnEngine.apply(
            .redeemWild(playerId: p1.id, meldId: meld.id,
                        wildCardId: joker.id, replacementCard: wrong),
            to: g
        )
        if case .failure(let e) = result {
            if case .invalidRedemption = e { /* ok */ } else { XCTFail("expected invalidRedemption, got \(e)") }
        } else { XCTFail("expected failure") }
    }

    func testRedeemFromTripletIsRejected() {
        // Even a valid-looking swap on a triplet must be rejected.
        let joker = Card.joker()
        let c7natural = c(.clubs, .seven)
        let p1 = Player(name: "A", hand: [c7natural],
                        hasGoneDownThisRound: true, laidDownThisTurn: false)
        let p2 = Player(name: "B", hand: [])
        let meld = Meld(kind: .triplet,
                        cards: [c(.spades, .seven), c(.hearts, .seven), joker],
                        ownerId: p2.id)
        let g = GameState(
            players: [p1, p2], currentRound: 1, currentTurnIndex: 0, dealerIndex: 1,
            stock: [c(.clubs, .nine)], discard: [c(.clubs, .ten)],
            melds: [meld], phase: .awaitingMeldOrDiscard,
            stockReshufflesUsed: 0, randomSeed: 0
        )
        let result = TurnEngine.apply(
            .redeemWild(playerId: p1.id, meldId: meld.id,
                        wildCardId: joker.id, replacementCard: c7natural),
            to: g
        )
        if case .failure(let e) = result {
            XCTAssertEqual(e, .notASequence)
        } else { XCTFail("expected notASequence") }
    }

    func testRedeemBeforeGoingDownIsRejected() {
        let joker = Card.joker()
        let c7 = c(.clubs, .seven)
        let p1 = Player(name: "A", hand: [c7],
                        hasGoneDownThisRound: false, laidDownThisTurn: false)
        let p2 = Player(name: "B", hand: [])
        let meld = Meld(kind: .sequence,
                        cards: [c(.clubs, .five), c(.clubs, .six), joker, c(.clubs, .eight)],
                        ownerId: p2.id)
        let g = GameState(
            players: [p1, p2], currentRound: 1, currentTurnIndex: 0, dealerIndex: 1,
            stock: [c(.clubs, .nine)], discard: [c(.clubs, .ten)],
            melds: [meld], phase: .awaitingMeldOrDiscard,
            stockReshufflesUsed: 0, randomSeed: 0
        )
        let result = TurnEngine.apply(
            .redeemWild(playerId: p1.id, meldId: meld.id,
                        wildCardId: joker.id, replacementCard: c7),
            to: g
        )
        if case .failure(let e) = result {
            XCTAssertEqual(e, .notYetWentDown)
        } else { XCTFail("expected notYetWentDown") }
    }

    func testRedeemOnGoDownTurnIsRejected() {
        let joker = Card.joker()
        let c7 = c(.clubs, .seven)
        // Simulate having just gone down this turn.
        let p1 = Player(name: "A", hand: [c7],
                        hasGoneDownThisRound: true, laidDownThisTurn: true)
        let p2 = Player(name: "B", hand: [])
        let meld = Meld(kind: .sequence,
                        cards: [c(.clubs, .five), c(.clubs, .six), joker, c(.clubs, .eight)],
                        ownerId: p2.id)
        let g = GameState(
            players: [p1, p2], currentRound: 1, currentTurnIndex: 0, dealerIndex: 1,
            stock: [c(.clubs, .nine)], discard: [c(.clubs, .ten)],
            melds: [meld], phase: .awaitingMeldOrDiscard,
            stockReshufflesUsed: 0, randomSeed: 0
        )
        let result = TurnEngine.apply(
            .redeemWild(playerId: p1.id, meldId: meld.id,
                        wildCardId: joker.id, replacementCard: c7),
            to: g
        )
        if case .failure(let e) = result {
            XCTAssertEqual(e, .cannotActOnGoDownTurn)
        } else { XCTFail("expected cannotActOnGoDownTurn") }
    }

    func testRedeemWithWildReplacementRejected() {
        // Trying to hand another joker as the "replacement" for a wild — no.
        let jokerInMeld = Card.joker()
        let jokerInHand = Card.joker()
        let (g, p1, _, meld) = stateWithSequence(
            meldCards: [c(.clubs, .five), c(.clubs, .six), jokerInMeld, c(.clubs, .eight)],
            p1Hand: [jokerInHand]
        )
        let result = TurnEngine.apply(
            .redeemWild(playerId: p1.id, meldId: meld.id,
                        wildCardId: jokerInMeld.id, replacementCard: jokerInHand),
            to: g
        )
        if case .failure(let e) = result {
            if case .invalidRedemption = e { /* ok */ } else { XCTFail("expected invalidRedemption, got \(e)") }
        } else { XCTFail("expected failure") }
    }

    func testAddToMeldRejectedOnGoDownTurn() {
        // Verify the new laidDownThisTurn flag also blocks addToMeld.
        let joker = Card.joker()
        _ = joker
        let extra = c(.clubs, .four)
        let p1 = Player(name: "A", hand: [extra],
                        hasGoneDownThisRound: true, laidDownThisTurn: true)
        let p2 = Player(name: "B", hand: [])
        let meld = Meld(kind: .sequence,
                        cards: [c(.clubs, .five), c(.clubs, .six), c(.clubs, .seven), c(.clubs, .eight)],
                        ownerId: p1.id)
        let g = GameState(
            players: [p1, p2], currentRound: 1, currentTurnIndex: 0, dealerIndex: 1,
            stock: [c(.clubs, .nine)], discard: [c(.clubs, .ten)],
            melds: [meld], phase: .awaitingMeldOrDiscard,
            stockReshufflesUsed: 0, randomSeed: 0
        )
        let result = TurnEngine.apply(
            .addToMeld(playerId: p1.id, meldId: meld.id,
                       cardsAtStart: [extra], cardsAtEnd: []),
            to: g
        )
        if case .failure(let e) = result {
            XCTAssertEqual(e, .cannotActOnGoDownTurn)
        } else { XCTFail("expected cannotActOnGoDownTurn") }
    }
}

// MARK: - Independent contracts (per-player levels)

final class IndependentContractTests: XCTestCase {

    // Build a minimal roundEnded state for two players. `p1WentDown` and
    // `p2WentDown` control who completed their contract this hand.
    // p1Hand and p2Hand are whatever is left in hand (for scoring).
    private func endedHand(
        p1Level: Int, p1WentDown: Bool, p1Hand: [Card], p1Total: Int,
        p2Level: Int, p2WentDown: Bool, p2Hand: [Card], p2Total: Int,
        seed: UInt64 = 42,
        handNumber: Int = 1
    ) -> GameState {
        let p1 = Player(name: "A", hand: p1Hand,
                        totalScore: p1Total,
                        hasGoneDownThisRound: p1WentDown,
                        laidDownThisTurn: false,
                        currentLevel: p1Level)
        let p2 = Player(name: "B", hand: p2Hand,
                        totalScore: p2Total,
                        hasGoneDownThisRound: p2WentDown,
                        laidDownThisTurn: false,
                        currentLevel: p2Level)
        return GameState(
            players: [p1, p2],
            currentRound: handNumber,
            currentTurnIndex: 0,
            dealerIndex: 1,
            stock: [], discard: [c(.clubs, .four)],
            melds: [],
            phase: .roundEnded,
            stockReshufflesUsed: 0,
            randomSeed: seed
        )
    }

    func testCurrentContractDependsOnCurrentPlayerLevel() {
        var p1 = Player(name: "A", hand: [])
        p1.currentLevel = 5
        var p2 = Player(name: "B", hand: [])
        p2.currentLevel = 8
        let g = GameState(
            players: [p1, p2], currentRound: 1, currentTurnIndex: 0, dealerIndex: 1,
            stock: [], discard: [], melds: [],
            phase: .awaitingDraw, stockReshufflesUsed: 0, randomSeed: 0
        )
        XCTAssertEqual(g.currentContract?.roundNumber, 5)
        XCTAssertEqual(g.contract(forPlayer: p2.id)?.roundNumber, 8)
    }

    func testAdvanceHandOnlyPromotesGoDowners() {
        let g = endedHand(
            p1Level: 5, p1WentDown: true,  p1Hand: [],                     p1Total: 20,
            p2Level: 5, p2WentDown: false, p2Hand: [c(.clubs, .ace)],       p2Total: 20
        )
        guard case .success(let next) = TurnEngine.advanceHand(state: g) else {
            return XCTFail("advanceHand should succeed")
        }
        XCTAssertEqual(next.players[0].currentLevel, 6, "p1 went down → level 6")
        XCTAssertEqual(next.players[1].currentLevel, 5, "p2 stuck on 5")
    }

    func testAdvanceHandAddsScoresToTotal() {
        // p2 has an Ace in hand → 15 pts penalty. p1 went out (empty hand).
        let g = endedHand(
            p1Level: 3, p1WentDown: true,  p1Hand: [],               p1Total: 10,
            p2Level: 3, p2WentDown: false, p2Hand: [c(.clubs, .ace)], p2Total: 30
        )
        guard case .success(let next) = TurnEngine.advanceHand(state: g) else {
            return XCTFail("advanceHand should succeed")
        }
        XCTAssertEqual(next.players[0].totalScore, 10, "p1 went out, +0")
        XCTAssertEqual(next.players[1].totalScore, 45, "p2 +15 for the Ace")
    }

    func testAdvanceHandDealsNextHandWithFreshFlags() {
        let g = endedHand(
            p1Level: 2, p1WentDown: true,  p1Hand: [], p1Total: 0,
            p2Level: 2, p2WentDown: true,  p2Hand: [], p2Total: 0
        )
        guard case .success(let next) = TurnEngine.advanceHand(state: g) else {
            return XCTFail("advanceHand should succeed")
        }
        XCTAssertEqual(next.currentRound, 2, "hand number increments")
        XCTAssertEqual(next.phase, .awaitingDraw, "new hand starts with draw")
        XCTAssertEqual(next.dealerIndex, 0, "dealer rotates from 1 → 0 (2-player)")
        XCTAssertEqual(next.currentTurnIndex, 1, "player after new dealer acts first")
        XCTAssertEqual(next.melds.count, 0, "table clears")
        XCTAssertEqual(next.players[0].hand.count, 11, "fresh 11-card deal")
        XCTAssertEqual(next.players[1].hand.count, 11)
        XCTAssertFalse(next.players[0].hasGoneDownThisRound)
        XCTAssertFalse(next.players[0].laidDownThisTurn)
        XCTAssertEqual(next.players[0].buysUsedThisRound, 0)
    }

    func testAdvanceHandCarriesForwardLevelAndScore() {
        let g = endedHand(
            p1Level: 2, p1WentDown: true,  p1Hand: [], p1Total: 25,
            p2Level: 2, p2WentDown: false, p2Hand: [c(.hearts, .four)], p2Total: 40
        )
        guard case .success(let next) = TurnEngine.advanceHand(state: g) else {
            return XCTFail("advanceHand should succeed")
        }
        XCTAssertEqual(next.players[0].currentLevel, 3)
        XCTAssertEqual(next.players[0].totalScore, 25)
        XCTAssertEqual(next.players[1].currentLevel, 2)
        XCTAssertEqual(next.players[1].totalScore, 45) // +5 for the 4
    }

    func testGameEndsWhenSoloFinisherReachesLevel10() {
        // p1 was on level 10 and went down/out → advances past 10 → wins.
        let g = endedHand(
            p1Level: 10, p1WentDown: true,  p1Hand: [], p1Total: 100,
            p2Level:  6, p2WentDown: false, p2Hand: [c(.clubs, .ace)], p2Total: 40
        )
        guard case .success(let next) = TurnEngine.advanceHand(state: g) else {
            return XCTFail("advanceHand should succeed")
        }
        XCTAssertEqual(next.phase, .gameEnded)
        XCTAssertEqual(next.gameWinnerIds.count, 1)
        XCTAssertEqual(next.gameWinnerIds.first, g.players[0].id)
    }

    func testTieBreakerByLowestCumulativeScore() {
        // Both p1 and p2 were on level 10 and completed it this hand.
        // p1 already had lower cumulative total → p1 wins on tiebreaker.
        let g = endedHand(
            p1Level: 10, p1WentDown: true, p1Hand: [], p1Total: 55,
            p2Level: 10, p2WentDown: true, p2Hand: [], p2Total: 90
        )
        guard case .success(let next) = TurnEngine.advanceHand(state: g) else {
            return XCTFail("advanceHand should succeed")
        }
        XCTAssertEqual(next.phase, .gameEnded)
        XCTAssertEqual(next.gameWinnerIds, [g.players[0].id])
    }

    func testTieBreakerCoWinnersOnEqualScore() {
        // Both finished level 10 in the same hand AND have identical cumulative
        // scores → both are winners.
        let g = endedHand(
            p1Level: 10, p1WentDown: true, p1Hand: [], p1Total: 60,
            p2Level: 10, p2WentDown: true, p2Hand: [], p2Total: 60
        )
        guard case .success(let next) = TurnEngine.advanceHand(state: g) else {
            return XCTFail("advanceHand should succeed")
        }
        XCTAssertEqual(next.phase, .gameEnded)
        XCTAssertEqual(Set(next.gameWinnerIds), Set([g.players[0].id, g.players[1].id]))
    }

    func testAdvanceHandFailsIfPhaseNotRoundEnded() {
        var g = endedHand(
            p1Level: 3, p1WentDown: false, p1Hand: [], p1Total: 0,
            p2Level: 3, p2WentDown: false, p2Hand: [], p2Total: 0
        )
        g.phase = .awaitingDraw
        if case .failure(let e) = TurnEngine.advanceHand(state: g) {
            if case .wrongPhase = e { /* ok */ } else { XCTFail("expected wrongPhase, got \(e)") }
        } else { XCTFail("expected failure") }
    }

    func testAllActionsRejectedAfterGameEnds() {
        // Force a gameEnded state and try to draw.
        let p1 = Player(name: "A", hand: [], currentLevel: 11)
        let p2 = Player(name: "B", hand: [], currentLevel: 5)
        let g = GameState(
            players: [p1, p2], currentRound: 5, currentTurnIndex: 0, dealerIndex: 1,
            stock: [c(.clubs, .four)], discard: [],
            melds: [], phase: .gameEnded,
            stockReshufflesUsed: 0, randomSeed: 0,
            gameWinnerIds: [p1.id]
        )
        let result = TurnEngine.apply(.draw(playerId: p1.id, source: .stock), to: g)
        if case .failure(let e) = result {
            XCTAssertEqual(e, .gameOver)
        } else { XCTFail("expected gameOver") }
    }

    func testGoDownUsesCurrentPlayerLevel() {
        // p1 is on level 3 (contract: 2 sequences of 4). Attempt a valid
        // round-3 contract to confirm the engine consults per-player level.
        let seqA = [c(.clubs, .three), c(.clubs, .four),
                    c(.clubs, .five),  c(.clubs, .six)]
        let seqB = [c(.hearts, .three), c(.hearts, .four),
                    c(.hearts, .five),  c(.hearts, .six)]
        var p1 = Player(name: "A", hand: seqA + seqB + [c(.diamonds, .king)])
        p1.currentLevel = 3
        var p2 = Player(name: "B", hand: [])
        p2.currentLevel = 1 // p2 is still on level 1 — irrelevant here.
        let g = GameState(
            players: [p1, p2], currentRound: 5, currentTurnIndex: 0, dealerIndex: 1,
            stock: [c(.spades, .two)], discard: [c(.spades, .four)],
            melds: [],
            phase: .awaitingMeldOrDiscard,
            stockReshufflesUsed: 0, randomSeed: 0
        )
        let result = TurnEngine.apply(
            .goDown(playerId: p1.id, contract: [seqA, seqB]),
            to: g
        )
        guard case .success(let next) = result else {
            return XCTFail("go down should succeed on p1's level-3 contract")
        }
        XCTAssertTrue(next.players[0].hasGoneDownThisRound)
    }
}
