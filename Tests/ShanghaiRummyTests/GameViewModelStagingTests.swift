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
        // Stage a card, then complete a draw + discard cycle to advance turn.
        guard let first = vm.currentPlayer.hand.first else {
            return XCTFail("expected a non-empty hand")
        }
        vm.toggleStaged(cardId: first.id)
        XCTAssertFalse(vm.stagedCardIds.isEmpty)

        vm.drawFromStock()
        // After drawing we're in the discard phase; pick a card to discard.
        guard let toss = vm.currentPlayer.hand.first else {
            return XCTFail("no card to discard")
        }
        vm.discard(toss)
        // Successful discard should advance the turn and clear staging.
        XCTAssertTrue(vm.stagedCardIds.isEmpty)
    }
}
