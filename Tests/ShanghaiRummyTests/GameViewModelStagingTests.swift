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

    private func makeVM(hand: [Card], level: Int = 1) -> GameViewModel {
        let players = [
            Player(name: "A", hand: hand, currentLevel: level),
            Player(name: "B", currentLevel: level),
        ]
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

    func testCanSaveTripletOfTwosToContractDraft() {
        let twos = [
            Card(suit: .clubs, rank: .two),
            Card(suit: .hearts, rank: .two),
            Card(suit: .spades, rank: .two),
        ]
        let vm = makeVM(hand: twos + [
            Card(suit: .diamonds, rank: .three),
        ])
        for card in twos {
            vm.toggleStaged(cardId: card.id)
        }

        XCTAssertTrue(vm.saveStagedAsMeld())
        XCTAssertEqual(vm.contractDraft.first?.map(\.id), twos.map(\.id))
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

    func testRankSortPutsAceAfterKingAndWildsLast() {
        let king = Card(suit: .hearts, rank: .king)
        let three = Card(suit: .clubs, rank: .three)
        let ace = Card(suit: .spades, rank: .ace)
        let joker = Card.joker()
        let five = Card(suit: .diamonds, rank: .five)
        let vm = makeVM(hand: [king, three, ace, joker, five])

        vm.sortHandByRank()

        XCTAssertEqual(vm.orderedHand.map(\.id),
                       [three.id, five.id, king.id, ace.id, joker.id])
    }

    func testSuitSortKeepsAceAboveKingAndWildsLast() {
        let heartKing = Card(suit: .hearts, rank: .king)
        let heartAce = Card(suit: .hearts, rank: .ace)
        let three = Card(suit: .clubs, rank: .three)
        let spadeAce = Card(suit: .spades, rank: .ace)
        let joker = Card.joker()
        let five = Card(suit: .diamonds, rank: .five)
        let vm = makeVM(
            hand: [
                heartAce,
                spadeAce,
                heartKing,
                three,
                joker,
                five,
            ]
        )

        vm.sortHandBySuit()

        XCTAssertEqual(
            vm.orderedHand.map(\.id),
            [
                three.id,
                heartKing.id,
                heartAce.id,
                spadeAce.id,
                five.id,
                joker.id,
            ]
        )
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

    func testSavingAmbiguousSequenceRequestsWildPlacement() throws {
        let nine = Card(suit: .diamonds, rank: .nine)
        let ten = Card(suit: .diamonds, rank: .ten)
        let jack = Card(suit: .diamonds, rank: .jack)
        let joker = Card.joker()
        let vm = makeVM(hand: [nine, ten, jack, joker])
        for card in vm.currentPlayer.hand {
            vm.toggleStaged(cardId: card.id)
        }

        XCTAssertTrue(vm.saveStagedAsMeld())
        XCTAssertTrue(vm.contractDraft.isEmpty)
        let options = try XCTUnwrap(vm.pendingInitialSequenceChoice?.options)
        XCTAssertEqual(options.count, 2)
        let lowOption = try XCTUnwrap(options.firstIndex {
            $0.first?.id == joker.id
        })

        XCTAssertTrue(vm.chooseInitialSequenceArrangement(at: lowOption))
        XCTAssertNil(vm.pendingInitialSequenceChoice)
        XCTAssertEqual(vm.contractDraft.count, 1)
        XCTAssertEqual(vm.contractDraft[0].first?.id, joker.id)
        XCTAssertTrue(vm.stagedCardIds.isEmpty)
    }

    func testFinalAmbiguousSequenceChoicePresentsContractReadyPrompt() throws {
        let triplet = [
            Card(suit: .hearts, rank: .king),
            Card(suit: .spades, rank: .king),
            Card(suit: .diamonds, rank: .king),
        ]
        let sequence = [
            Card(suit: .diamonds, rank: .nine),
            Card(suit: .diamonds, rank: .ten),
            Card(suit: .diamonds, rank: .jack),
            Card.joker(),
        ]
        let leftover = Card(suit: .clubs, rank: .three)
        let vm = makeVM(
            hand: triplet + sequence + [leftover],
            level: 2
        )
        for card in triplet {
            vm.toggleStaged(cardId: card.id)
        }
        XCTAssertTrue(vm.saveStagedAsMeld())
        XCTAssertNil(vm.contractReadyPrompt)
        for card in sequence {
            vm.toggleStaged(cardId: card.id)
        }

        XCTAssertTrue(vm.saveStagedAsMeld())
        XCTAssertNil(vm.contractReadyPrompt)
        let options = try XCTUnwrap(vm.pendingInitialSequenceChoice?.options)

        XCTAssertTrue(vm.chooseInitialSequenceArrangement(at: options.startIndex))
        XCTAssertEqual(vm.contractReadyPrompt, .readyToPutDown)
    }
}
