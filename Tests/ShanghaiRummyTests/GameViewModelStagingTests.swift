import XCTest
@testable import ShanghaiRummy

/// Covers M2d staging state on `GameViewModel`. The staging tray is a
/// UI-side working set the player uses to build a candidate meld before
/// committing it via `.goDown` or `.addToMeld`.
@MainActor
final class GameViewModelStagingTests: XCTestCase {

    private func makeVM() -> GameViewModel {
        GameViewModel.newHotSeat(playerNames: ["A", "B"], seed: 42)
    }

    private func makeVM(hand: [Card]) -> GameViewModel {
        let players = [Player(name: "A", hand: hand), Player(name: "B")]
        let state = GameState(
            players: players,
            currentRound: 1,
            currentTurnIndex: 0,
            dealerIndex: 1,
            stock: [Card(suit: .clubs, rank: .four)],
            discard: [Card(suit: .hearts, rank: .three)],
            melds: [],
            phase: .awaitingMeldOrDiscard,
            stockReshufflesUsed: 0,
            randomSeed: 1
        )
        return GameViewModel(state: state)
    }

    func testInitialStagingIsEmpty() {
        let vm = makeVM()
        XCTAssertTrue(vm.stagedCardIds.isEmpty)
        XCTAssertTrue(vm.stagedCards.isEmpty)
        XCTAssertEqual(vm.unstagedCards.count, vm.currentPlayer.hand.count)
    }

    func testToggleStagedAddsAndRemoves() {
        let vm = makeVM()
        guard let first = vm.currentPlayer.hand.first else {
            return XCTFail("expected a non-empty hand")
        }
        vm.toggleStaged(cardId: first.id)
        XCTAssertTrue(vm.stagedCardIds.contains(first.id))
        XCTAssertEqual(vm.stagedCards.map(\.id), [first.id])
        XCTAssertFalse(vm.unstagedCards.contains(where: { $0.id == first.id }))

        vm.toggleStaged(cardId: first.id)
        XCTAssertFalse(vm.stagedCardIds.contains(first.id))
    }

    func testToggleIgnoresCardsNotInHand() {
        let vm = makeVM()
        let bogus = UUID()
        vm.toggleStaged(cardId: bogus)
        XCTAssertFalse(vm.stagedCardIds.contains(bogus))
    }

    func testStagingClearsOnTurnAdvance() {
        let vm = makeVM()
        // Stage a card, then complete the purchase round and discard.
        guard let first = vm.currentPlayer.hand.first else {
            return XCTFail("expected a non-empty hand")
        }
        vm.toggleStaged(cardId: first.id)
        XCTAssertFalse(vm.stagedCardIds.isEmpty)

        vm.drawFromStock()
        vm.acknowledgeTurnPassed()
        vm.passBuyOffer()
        vm.acknowledgeTurnPassed()

        guard let toss = vm.currentPlayer.hand.first else {
            return XCTFail("no card to discard")
        }
        vm.discard(toss)
        // Successful discard should advance the turn and clear staging.
        XCTAssertTrue(vm.stagedCardIds.isEmpty)
    }

    func testRankSortPutsNaturalCardsInRankOrderAndWildsLast() {
        let king = Card(suit: .hearts, rank: .king)
        let three = Card(suit: .clubs, rank: .three)
        let ace = Card(suit: .spades, rank: .ace)
        let joker = Card.joker()
        let five = Card(suit: .diamonds, rank: .five)
        let vm = makeVM(hand: [king, three, ace, joker, five])

        vm.sortHandByRank()

        XCTAssertEqual(vm.orderedHand.map(\.id),
                       [ace.id, three.id, five.id, king.id, joker.id])
    }

    func testSuitSortUsesConsistentSuitGroupsAndWildsLast() {
        let king = Card(suit: .hearts, rank: .king)
        let three = Card(suit: .clubs, rank: .three)
        let ace = Card(suit: .spades, rank: .ace)
        let joker = Card.joker()
        let five = Card(suit: .diamonds, rank: .five)
        let vm = makeVM(hand: [king, three, ace, joker, five])

        vm.sortHandBySuit()

        XCTAssertEqual(vm.orderedHand.map(\.id),
                       [three.id, five.id, king.id, ace.id, joker.id])
    }

    func testRelativeReorderRemainsCorrectWhileAnotherCardIsStaged() {
        let cards = [
            Card(suit: .clubs, rank: .three),
            Card(suit: .diamonds, rank: .four),
            Card(suit: .hearts, rank: .five),
            Card(suit: .spades, rank: .six),
        ]
        let vm = makeVM(hand: cards)
        vm.toggleStaged(cardId: cards[1].id)

        vm.moveHandCard(cards[3].id, before: cards[0].id)

        XCTAssertEqual(vm.orderedHand.map(\.id),
                       [cards[3].id, cards[0].id, cards[1].id, cards[2].id])
        XCTAssertEqual(vm.stagedCards.map(\.id), [cards[1].id])
    }

    func testStagingArrangesNineQueenAndTwoJokersBeforeSaving() throws {
        let nine = Card(suit: .diamonds, rank: .nine)
        let queen = Card(suit: .diamonds, rank: .queen)
        let firstJoker = Card.joker()
        let secondJoker = Card.joker()
        let vm = makeVM(hand: [nine, queen, firstJoker, secondJoker])
        for card in vm.currentPlayer.hand {
            vm.toggleStaged(cardId: card.id)
        }

        let kind = try vm.stagedValidation?.get()
        XCTAssertEqual(kind, .sequence)
        XCTAssertEqual(vm.stagedCards.first?.id, nine.id)
        XCTAssertEqual(vm.stagedCards.last?.id, queen.id)
        XCTAssertTrue(vm.saveStagedAsMeld())
        XCTAssertNoThrow(
            try MeldValidator.validateSequence(vm.contractDraft[0]).get()
        )
    }
}
