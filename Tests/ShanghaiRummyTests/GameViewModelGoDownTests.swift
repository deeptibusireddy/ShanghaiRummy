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
                    laidDownThisTurn: Bool = false) -> GameViewModel {
        let me = Player(name: "You",
                        hand: hand,
                        hasGoneDownThisRound: hasGoneDown,
                        laidDownThisTurn: laidDownThisTurn,
                        currentLevel: level)
        let other = Player(name: "Bot", hand: [], currentLevel: level)
        let stock = Array(repeating: c(.clubs, .four), count: 20)
        let s = GameState(
            players: [me, other],
            currentRound: 1,
            currentTurnIndex: 0,
            dealerIndex: 1,
            stock: stock,
            discard: [c(.hearts, .three)],
            melds: melds,
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
    }

    func testRemoveDraftMeldUndoes() {
        let hand = [c(.hearts, .king), c(.spades, .king), c(.diamonds, .king)]
        let v = vm(hand: hand)
        for card in hand { v.toggleStaged(cardId: card.id) }
        _ = v.saveStagedAsMeld()
        XCTAssertEqual(v.contractDraft.count, 1)
        v.removeDraftMeld(at: 0)
        XCTAssertTrue(v.contractDraft.isEmpty)
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
        XCTAssertFalse(v.isMeldOverlayOpen)
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
}
