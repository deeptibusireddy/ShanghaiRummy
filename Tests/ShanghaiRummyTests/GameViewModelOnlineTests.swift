import XCTest
@testable import ShanghaiRummy

@MainActor
final class GameViewModelOnlineTests: XCTestCase {
    func testOnlineViewModelKeepsLocalHandWhenAnotherPlayerHasTurn() {
        let state = GameFactory.newGame(
            playerNames: ["Local", "Remote"],
            seed: 11
        )
        let local = state.players[0]
        XCTAssertNotEqual(state.currentPlayerId, local.id)

        let viewModel = GameViewModel(
            state: state,
            localPlayerId: local.id
        )

        XCTAssertEqual(viewModel.currentPlayer.id, local.id)
        XCTAssertEqual(viewModel.currentPlayerName, "Remote")
        XCTAssertEqual(viewModel.displayedPlayerIndex, 0)
        XCTAssertFalse(viewModel.isLocalPlayersTurn)
        XCTAssertFalse(viewModel.canDrawFromStock)
        XCTAssertTrue(viewModel.canRequestBuy)
    }

    func testOnlineBuyButtonTogglesRequestAndCancellation() {
        let state = GameFactory.newGame(
            playerNames: ["Local", "Remote"],
            seed: 12
        )
        let localId = state.players[0].id
        let viewModel = GameViewModel(state: state, localPlayerId: localId)

        viewModel.toggleLocalBuyRequest()

        XCTAssertTrue(viewModel.hasRequestedBuy)
        XCTAssertFalse(viewModel.canRequestBuy)

        viewModel.toggleLocalBuyRequest()

        XCTAssertFalse(viewModel.hasRequestedBuy)
        XCTAssertTrue(viewModel.canRequestBuy)
    }

    func testOnlineTurnAdvanceDoesNotShowPassDeviceSheet() {
        var state = GameFactory.newGame(
            playerNames: ["Local", "Remote"],
            seed: 13
        )
        state.currentTurnIndex = 0
        let localId = state.players[0].id
        let viewModel = GameViewModel(state: state, localPlayerId: localId)

        viewModel.drawFromStock()
        let discard = viewModel.currentPlayer.hand[0]
        viewModel.discard(discard)

        XCTAssertFalse(viewModel.isBetweenTurns)
        XCTAssertEqual(viewModel.currentPlayer.id, localId)
        XCTAssertFalse(viewModel.isLocalPlayersTurn)
    }

    func testOnlineSubmissionWaitsForAuthoritativeSnapshot() {
        var state = GameFactory.newGame(
            playerNames: ["Local", "Remote"],
            seed: 14
        )
        state.currentTurnIndex = 0
        let localId = state.players[0].id
        let viewModel = GameViewModel(state: state, localPlayerId: localId)
        var submittedAction: TurnEngine.Action?
        viewModel.configureOnlineActionSubmitter {
            submittedAction = $0
            return true
        }

        viewModel.drawFromStock()

        XCTAssertEqual(
            submittedAction,
            .draw(playerId: localId, source: .stock)
        )
        XCTAssertTrue(viewModel.isSubmittingOnlineAction)
        XCTAssertEqual(viewModel.state.phase, .awaitingDraw)

        let authoritative = try! TurnEngine.apply(
            submittedAction!,
            to: state
        ).get()
        viewModel.receiveAuthoritativeState(authoritative)

        XCTAssertFalse(viewModel.isSubmittingOnlineAction)
        XCTAssertEqual(viewModel.state.phase, .awaitingMeldOrDiscard)
    }

    func testUnrelatedSnapshotDoesNotCompletePendingOnlineAction() {
        var state = GameFactory.newGame(
            playerNames: ["Local", "Remote"],
            seed: 14
        )
        state.currentTurnIndex = 0
        let localId = state.players[0].id
        let viewModel = GameViewModel(state: state, localPlayerId: localId)
        viewModel.configureOnlineActionSubmitter { _ in true }
        viewModel.drawFromStock()

        viewModel.receiveAuthoritativeState(
            state,
            completesPendingAction: false
        )

        XCTAssertTrue(viewModel.isSubmittingOnlineAction)
        XCTAssertEqual(viewModel.state.phase, .awaitingDraw)
    }

    func testNonTurnOnlinePlayerCannotStageCards() {
        let state = GameFactory.newGame(
            playerNames: ["Local", "Remote"],
            seed: 15
        )
        let local = state.players[0]
        let viewModel = GameViewModel(
            state: state,
            localPlayerId: local.id
        )

        viewModel.toggleStaged(cardId: local.hand[0].id)

        XCTAssertTrue(viewModel.stagedCardIds.isEmpty)
    }
}
