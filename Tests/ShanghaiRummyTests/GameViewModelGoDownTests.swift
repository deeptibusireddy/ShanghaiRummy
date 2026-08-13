import XCTest
@testable import ShanghaiRummy

/// Covers M2d-c: the go-down contract-draft flow and single-tap lay-off
/// on the meld overlay / hand fan.
@MainActor
final class GameViewModelGoDownTests: XCTestCase {

    private func c(_ suit: Suit, _ rank: Rank) -> Card { Card(suit: suit, rank: rank) }

    /// Construct a VM with a rigged hand for the current turn player, on the
    /// requested phase / round. Player index 0 is the acting player.
    private func vm(hand: [Card],
                    phase: GameState.Phase = .awaitingMeldOrDiscard,
                    level: Int = 1,
                    melds: [Meld] = [],
                    hasGoneDown: Bool = false,
                    laidDownThisTurn: Bool = false,
                    meldsOwnedByCurrentPlayer: Bool = false) -> GameViewModel {
        let me = Player(name: "You",
                       hand: hand,
                       hasGoneDownThisRound: hasGoneDown,
                       laidDownThisTurn: laidDownThisTurn,
                       currentLevel: level)
        let other = Player(name: "Bot", hand: [], currentLevel: level)
        let tableMelds = meldsOwnedByCurrentPlayer
            ? melds.map {
                Meld(id: $0.id, kind: $0.kind, cards: $0.cards, ownerId: me.id)
            }
            : melds
        let stock = Array(repeating: c(.clubs, .four), count: 20)
        let s = GameState(
            players: [me, other],
            currentRound: 1,
            currentTurnIndex: 0,
            dealerIndex: 1,
            stock: stock,
            discard: [c(.hearts, .three)],
            melds: tableMelds,
            phase: phase,
            stockReshufflesUsed: 0,
            randomSeed: 1
        )
        return GameViewModel(state: s)
    }

    // MARK: - Draft mechanics

    func testSaveStagedRequiresValidMeld() {
        let hand = [c(.hearts, .king), c(.spades, .queen)]
        let v = vm(hand: hand)
        // Stage two mismatched cards → invalid → save should fail.
        v.toggleStaged(cardId: hand[0].id)
        v.toggleStaged(cardId: hand[1].id)
        XCTAssertFalse(v.saveStagedAsMeld())
        XCTAssertTrue(v.contractDraft.isEmpty)
    }

    func testSaveStagedMovesValidMeldIntoDraft() {
        let hand = [c(.hearts, .king), c(.spades, .king), c(.diamonds, .king),
                    c(.clubs, .three)]
        let v = vm(hand: hand)
        for card in hand.prefix(3) { v.toggleStaged(cardId: card.id) }
        XCTAssertTrue(v.saveStagedAsMeld())
        XCTAssertEqual(v.contractDraft.count, 1)
        XCTAssertEqual(v.contractDraft[0].count, 3)
        XCTAssertTrue(v.stagedCardIds.isEmpty,
                      "Save should clear the staging tray")
        XCTAssertFalse(v.unstagedCards.contains(where: {
            Set(hand.prefix(3).map(\.id)).contains($0.id)
        }), "Saved draft cards must not reappear in the hand fan")
    }

    func testRemoveDraftMeldUndoes() {
        let hand = [c(.hearts, .king), c(.spades, .king), c(.diamonds, .king)]
        let v = vm(hand: hand)
        for card in hand { v.toggleStaged(cardId: card.id) }
        _ = v.saveStagedAsMeld()
        XCTAssertEqual(v.contractDraft.count, 1)
        v.removeDraftMeld(at: 0)
        XCTAssertTrue(v.contractDraft.isEmpty)
        XCTAssertEqual(Set(v.unstagedCards.map(\.id)), Set(hand.map(\.id)))
    }

    // MARK: - Contract shape

    func testCannotConfirmWithPartialDraft() {
        // Round 1 = 2 triplets. One saved triplet is not enough.
        let hand = [c(.hearts, .king), c(.spades, .king), c(.diamonds, .king)]
        let v = vm(hand: hand)
        for card in hand { v.toggleStaged(cardId: card.id) }
        _ = v.saveStagedAsMeld()
        XCTAssertFalse(v.canConfirmGoDown)
    }

    func testCanConfirmWithFullDraftForRound1() {
        // 2 triplets ready.
        let hand = [
            c(.hearts, .king), c(.spades, .king), c(.diamonds, .king),
            c(.hearts, .seven), c(.spades, .seven), c(.clubs, .seven),
        ]
        let v = vm(hand: hand)
        for card in hand.prefix(3) { v.toggleStaged(cardId: card.id) }
        _ = v.saveStagedAsMeld()
        for card in hand.suffix(3) { v.toggleStaged(cardId: card.id) }
        _ = v.saveStagedAsMeld()
        XCTAssertTrue(v.canConfirmGoDown)
    }

    // MARK: - Commit

    func testConfirmGoDownDispatchesAndClears() {
        let hand = [
            c(.hearts, .king), c(.spades, .king), c(.diamonds, .king),
            c(.hearts, .seven), c(.spades, .seven), c(.clubs, .seven),
            c(.clubs, .three), // penalty card left in hand
        ]
        let v = vm(hand: hand)
        for card in hand.prefix(3) { v.toggleStaged(cardId: card.id) }
        _ = v.saveStagedAsMeld()
        for card in hand[3..<6] { v.toggleStaged(cardId: card.id) }
        _ = v.saveStagedAsMeld()
        XCTAssertTrue(v.confirmGoDown())
        XCTAssertTrue(v.currentPlayer.hasGoneDownThisRound)
        XCTAssertEqual(v.state.melds.count, 2)
        XCTAssertTrue(v.contractDraft.isEmpty)
    }

    func testConfirmGoDownNoOpWhenIncomplete() {
        let hand = [c(.hearts, .king), c(.spades, .king), c(.diamonds, .king)]
        let v = vm(hand: hand)
        for card in hand { v.toggleStaged(cardId: card.id) }
        _ = v.saveStagedAsMeld()
        XCTAssertFalse(v.confirmGoDown())
        XCTAssertFalse(v.currentPlayer.hasGoneDownThisRound)
    }

    // MARK: - Lay-off

    func testLayoffAppendsToExistingTriplet() {
        let owner = UUID()
        let existing = Meld(
            kind: .triplet,
            cards: [c(.hearts, .king), c(.spades, .king), c(.diamonds, .king)],
            ownerId: owner
        )
        let extra = c(.clubs, .king)
        let v = vm(hand: [extra, c(.hearts, .three)],
                   melds: [existing],
                   hasGoneDown: true,
                   laidDownThisTurn: false)
        XCTAssertTrue(v.layoffTappedHandCard(extra))
        // The card is gone from hand and meld now has 4 cards.
        XCTAssertFalse(v.currentPlayer.hand.contains { $0.id == extra.id })
        let updated = v.state.melds.first { $0.id == existing.id }
        XCTAssertEqual(updated?.cards.count, 4)
    }

    func testLayoffAllowsNaturalSuitAlreadyInTriplet() {
        let existing = Meld(
            kind: .triplet,
            cards: [
                c(.hearts, .king),
                c(.spades, .king),
                c(.diamonds, .king),
            ],
            ownerId: UUID()
        )
        let duplicateSuit = c(.hearts, .king)
        let v = vm(
            hand: [duplicateSuit],
            melds: [existing],
            hasGoneDown: true,
            laidDownThisTurn: false
        )

        XCTAssertTrue(v.canLayOff(duplicateSuit, to: existing))
        XCTAssertTrue(v.canPlayAnyHandCard(to: existing))
        XCTAssertTrue(v.layoffHandCard(duplicateSuit, to: existing.id))
        XCTAssertFalse(v.currentPlayer.hand.contains { $0.id == duplicateSuit.id })
        XCTAssertEqual(v.state.melds.first?.cards.count, 4)
    }

    func testWildLayoffPromptsWhenBothSequenceEndsAreValid() {
        let wild = Card.joker()
        let existing = Meld(
            kind: .sequence,
            cards: [
                c(.clubs, .five),
                c(.clubs, .six),
                c(.clubs, .seven),
                c(.clubs, .eight),
            ],
            ownerId: UUID()
        )
        let v = vm(
            hand: [wild],
            melds: [existing],
            hasGoneDown: true,
            laidDownThisTurn: false
        )

        XCTAssertTrue(v.layoffHandCard(wild, to: existing.id))
        let pending = v.pendingSequenceEndChoice
        XCTAssertEqual(pending?.card.id, wild.id)
        XCTAssertEqual(pending?.meldId, existing.id)
        XCTAssertEqual(pending?.startRepresentation?.suit, .clubs)
        XCTAssertEqual(pending?.startRepresentation?.rank, .four)
        XCTAssertEqual(pending?.endRepresentation?.suit, .clubs)
        XCTAssertEqual(pending?.endRepresentation?.rank, .nine)
        XCTAssertTrue(v.currentPlayer.hand.contains(where: { $0.id == wild.id }))

        XCTAssertTrue(v.chooseSequenceEnd(.start))
        XCTAssertNil(v.pendingSequenceEndChoice)
        XCTAssertEqual(v.state.melds.first?.cards.first?.id, wild.id)
        XCTAssertFalse(v.currentPlayer.hand.contains(where: { $0.id == wild.id }))
    }

    func testWildLayoffCanExceedInitialWildLimit() {
        let firstWild = Card.joker()
        let secondWild = Card.joker()
        let newWild = Card.joker()
        let existing = Meld(
            kind: .sequence,
            cards: [
                c(.clubs, .five),
                c(.clubs, .six),
                firstWild,
                secondWild,
            ],
            ownerId: UUID()
        )
        let v = vm(
            hand: [newWild],
            melds: [existing],
            hasGoneDown: true,
            laidDownThisTurn: false
        )

        XCTAssertTrue(v.canLayOff(newWild, to: existing))
        XCTAssertTrue(v.canPlayAnyHandCard(to: existing))
        XCTAssertTrue(v.layoffHandCard(newWild, to: existing.id))
        XCTAssertNotNil(v.pendingSequenceEndChoice)
        XCTAssertTrue(v.chooseSequenceEnd(.end))
        XCTAssertEqual(v.state.melds.first?.wildCount, 3)
    }

    func testWildLayoffUsesOnlyValidSequenceEndWithoutPrompting() {
        let existingWild = Card.joker()
        let newWild = Card.joker()
        let existing = Meld(
            kind: .sequence,
            cards: [
                c(.clubs, .ace),
                existingWild,
                c(.clubs, .three),
                c(.clubs, .four),
            ],
            ownerId: UUID()
        )
        let v = vm(
            hand: [newWild],
            melds: [existing],
            hasGoneDown: true,
            laidDownThisTurn: false
        )

        XCTAssertTrue(v.layoffHandCard(newWild, to: existing.id))
        XCTAssertNil(v.pendingSequenceEndChoice)
        XCTAssertEqual(v.state.melds.first?.cards.last?.id, newWild.id)
    }

    func testLayoffRejectsWhenNotGoneDown() {
        let owner = UUID()
        let existing = Meld(
            kind: .triplet,
            cards: [c(.hearts, .king), c(.spades, .king), c(.diamonds, .king)],
            ownerId: owner
        )
        let extra = c(.clubs, .king)
        let v = vm(hand: [extra], melds: [existing], hasGoneDown: false)
        XCTAssertFalse(v.layoffTappedHandCard(extra))
    }

    func testLayoffRejectsOnGoDownTurn() {
        // A player who went down this turn cannot lay off same turn.
        let owner = UUID()
        let existing = Meld(
            kind: .triplet,
            cards: [c(.hearts, .king), c(.spades, .king), c(.diamonds, .king)],
            ownerId: owner
        )
        let extra = c(.clubs, .king)
        let v = vm(hand: [extra],
                   melds: [existing],
                   hasGoneDown: true,
                   laidDownThisTurn: true)
        XCTAssertFalse(v.layoffTappedHandCard(extra))
    }

    func testLayoffRejectsBeforeDrawing() {
        let owner = UUID()
        let existing = Meld(
            kind: .triplet,
            cards: [c(.hearts, .king), c(.spades, .king), c(.diamonds, .king)],
            ownerId: owner
        )
        let extra = c(.clubs, .king)
        let v = vm(hand: [extra],
                   phase: .awaitingDraw,
                   melds: [existing],
                   hasGoneDown: true)

        XCTAssertFalse(v.canLayOff(extra, to: existing))
        XCTAssertFalse(v.layoffHandCard(extra, to: existing.id))
    }

    func testLayoffReturnsFalseWhenNoMatch() {
        let owner = UUID()
        let existing = Meld(
            kind: .triplet,
            cards: [c(.hearts, .king), c(.spades, .king), c(.diamonds, .king)],
            ownerId: owner
        )
        let mismatch = c(.hearts, .three)
        let v = vm(hand: [mismatch],
                   melds: [existing],
                   hasGoneDown: true)
        XCTAssertFalse(v.layoffTappedHandCard(mismatch))
    }

    func testLayoffCanTargetTheSpecificVisibleMeld() {
        let owner = UUID()
        let kings = Meld(
            kind: .triplet,
            cards: [c(.hearts, .king), c(.spades, .king), c(.diamonds, .king)],
            ownerId: owner
        )
        let sevens = Meld(
            kind: .triplet,
            cards: [c(.hearts, .seven), c(.spades, .seven), c(.diamonds, .seven)],
            ownerId: owner
        )
        let extraKing = c(.clubs, .king)
        let v = vm(hand: [extraKing],
                   melds: [sevens, kings],
                   hasGoneDown: true)

        XCTAssertFalse(v.layoffHandCard(extraKing, to: sevens.id))
        XCTAssertTrue(v.canLayOff(extraKing, to: kings))
        XCTAssertTrue(v.layoffHandCard(extraKing, to: kings.id))
        XCTAssertEqual(v.state.melds.first(where: { $0.id == kings.id })?.cards.count, 4)
    }

    func testLayoffCanTargetCurrentPlayersOwnMeld() {
        let existing = Meld(
            kind: .triplet,
            cards: [c(.hearts, .king), c(.spades, .king), c(.diamonds, .king)],
            ownerId: UUID()
        )
        let extraKing = c(.clubs, .king)
        let v = vm(
            hand: [extraKing],
            melds: [existing],
            hasGoneDown: true,
            meldsOwnedByCurrentPlayer: true
        )

        XCTAssertEqual(v.state.melds.first?.ownerId, v.currentPlayer.id)
        XCTAssertTrue(v.layoffHandCard(extraKing, to: existing.id))
        XCTAssertEqual(v.state.melds.first?.cards.count, 4)
        XCTAssertTrue(v.currentPlayer.hand.isEmpty)
    }

    // MARK: - Wild redemption

    func testDroppingExactNaturalRedeemsJokerAndReturnsItToHand() {
        let joker = Card.joker()
        let replacement = c(.clubs, .seven)
        let sequence = Meld(
            kind: .sequence,
            cards: [
                c(.clubs, .five), c(.clubs, .six), joker, c(.clubs, .eight),
            ],
            ownerId: UUID()
        )
        let v = vm(
            hand: [replacement],
            melds: [sequence],
            hasGoneDown: true
        )

        XCTAssertEqual(
            v.redemptionWildCardId(for: replacement, in: sequence),
            joker.id
        )
        XCTAssertTrue(v.canPlay(replacement, to: sequence))
        XCTAssertTrue(v.playHandCard(replacement, to: sequence.id))

        let updated = v.state.melds[0]
        XCTAssertEqual(updated.cards[2].id, replacement.id)
        XCTAssertTrue(v.currentPlayer.hand.contains(where: { $0.id == joker.id }))
        XCTAssertFalse(
            v.currentPlayer.hand.contains(where: { $0.id == replacement.id })
        )
    }

    func testPlayHandCardPreservesNormalEndLayoff() {
        let nine = c(.clubs, .nine)
        let sequence = Meld(
            kind: .sequence,
            cards: [
                c(.clubs, .five), c(.clubs, .six),
                c(.clubs, .seven), c(.clubs, .eight),
            ],
            ownerId: UUID()
        )
        let v = vm(hand: [nine], melds: [sequence], hasGoneDown: true)

        XCTAssertNil(v.redemptionWildCardId(for: nine, in: sequence))
        XCTAssertTrue(v.canPlay(nine, to: sequence))
        XCTAssertTrue(v.playHandCard(nine, to: sequence.id))
        XCTAssertEqual(v.state.melds[0].cards.last?.id, nine.id)
        XCTAssertTrue(v.currentPlayer.hand.isEmpty)
    }

    func testRedemptionTargetsCorrectJokerInTwoWildSequence() {
        let tenSlot = Card.joker()
        let jackSlot = Card.joker()
        let jack = c(.diamonds, .jack)
        let sequence = Meld(
            kind: .sequence,
            cards: [
                c(.diamonds, .nine), tenSlot, jackSlot, c(.diamonds, .queen),
            ],
            ownerId: UUID()
        )
        let v = vm(hand: [jack], melds: [sequence], hasGoneDown: true)

        XCTAssertEqual(
            v.redemptionWildCardId(for: jack, in: sequence),
            jackSlot.id
        )
        XCTAssertTrue(v.playHandCard(jack, to: sequence.id))
        XCTAssertEqual(v.state.melds[0].cards[1].id, tenSlot.id)
        XCTAssertEqual(v.state.melds[0].cards[2].id, jack.id)
        XCTAssertTrue(
            v.currentPlayer.hand.contains(where: { $0.id == jackSlot.id })
        )
    }

    func testWrongNaturalDoesNotMakeMeldDroppable() {
        let joker = Card.joker()
        let wrongSuit = c(.hearts, .seven)
        let sequence = Meld(
            kind: .sequence,
            cards: [
                c(.clubs, .five), c(.clubs, .six), joker, c(.clubs, .eight),
            ],
            ownerId: UUID()
        )
        let v = vm(hand: [wrongSuit], melds: [sequence], hasGoneDown: true)

        XCTAssertNil(v.redemptionWildCardId(for: wrongSuit, in: sequence))
        XCTAssertFalse(v.canPlay(wrongSuit, to: sequence))
        XCTAssertFalse(v.playHandCard(wrongSuit, to: sequence.id))
    }

    func testRedemptionIsUnavailableOnGoDownTurn() {
        let joker = Card.joker()
        let replacement = c(.clubs, .seven)
        let sequence = Meld(
            kind: .sequence,
            cards: [
                c(.clubs, .five), c(.clubs, .six), joker, c(.clubs, .eight),
            ],
            ownerId: UUID()
        )
        let v = vm(
            hand: [replacement],
            melds: [sequence],
            hasGoneDown: true,
            laidDownThisTurn: true
        )

        XCTAssertNil(v.redemptionWildCardId(for: replacement, in: sequence))
        XCTAssertFalse(v.canPlay(replacement, to: sequence))
    }
}
