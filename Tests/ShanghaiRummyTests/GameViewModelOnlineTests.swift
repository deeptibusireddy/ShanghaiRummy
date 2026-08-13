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
        XCTAssertFalse(viewModel.isLocalBuyDecision)
        XCTAssertFalse(viewModel.canAcceptBuyOffer)
        XCTAssertFalse(viewModel.canPassBuyOffer)
    }

    func testOnlineBuyerCanRespondOnlyAfterOfferReachesThem() {
        var state = GameFactory.newGame(
            playerNames: ["Local", "Remote"],
            seed: 12
        )
        let localId = state.players[0].id
        let remoteId = state.players[1].id
        state = try! TurnEngine.apply(
            .passBuyOffer(playerId: remoteId),
            to: state
        ).get()
        let viewModel = GameViewModel(state: state, localPlayerId: localId)
        var submittedAction: TurnEngine.Action?
        viewModel.configureOnlineActionSubmitter {
            submittedAction = $0
            return true
        }

        XCTAssertTrue(viewModel.isLocalBuyDecision)
        XCTAssertTrue(viewModel.canAcceptBuyOffer)
        XCTAssertTrue(viewModel.canPassBuyOffer)

        viewModel.acceptBuyOffer()
        XCTAssertEqual(
            submittedAction,
            .acceptBuyOffer(playerId: localId)
        )
        XCTAssertTrue(viewModel.isSubmittingOnlineAction)
    }

    func testOnlineTurnAdvanceDoesNotShowPassDeviceSheet() {
        var state = GameFactory.newGame(
            playerNames: ["Local", "Remote"],
            seed: 13
        )
        state.currentTurnIndex = 0
        let localId = state.players[0].id
        state.buyDecisionPlayerId = localId
        state.players[1].hasGoneDownThisRound = true
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
        state.buyDecisionPlayerId = localId
        state.players[1].hasGoneDownThisRound = true
        let viewModel = GameViewModel(state: state, localPlayerId: localId)
        var submittedAction: TurnEngine.Action?
        viewModel.configureOnlineActionSubmitter {
            submittedAction = $0
            return true
        }

        viewModel.passBuyOffer()

        XCTAssertEqual(
            submittedAction,
            .passBuyOffer(playerId: localId)
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
        state.buyDecisionPlayerId = localId
        let viewModel = GameViewModel(state: state, localPlayerId: localId)
        viewModel.configureOnlineActionSubmitter { _ in true }
        viewModel.passBuyOffer()

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

    func testHotSeatPurchaseOfferRequiresDeviceHandoff() {
        let state = GameFactory.newGame(
            playerNames: ["Buyer", "Turn Player"],
            seed: 16
        )
        let turnPlayerId = state.currentPlayerId
        let buyerId = state.players[0].id
        let viewModel = GameViewModel(state: state)

        viewModel.passBuyOffer()

        XCTAssertEqual(viewModel.state.buyDecisionPlayerId, buyerId)
        XCTAssertEqual(viewModel.currentPlayer.id, buyerId)
        XCTAssertTrue(viewModel.isBetweenTurns)

        viewModel.acknowledgeTurnPassed()
        viewModel.acceptBuyOffer()

        XCTAssertEqual(viewModel.state.currentPlayerId, turnPlayerId)
        XCTAssertEqual(viewModel.state.phase, .awaitingMeldOrDiscard)
        XCTAssertEqual(viewModel.currentPlayer.id, turnPlayerId)
        XCTAssertTrue(viewModel.isBetweenTurns)
    }

    func testHotSeatTimeoutPassesNonTurnBuyerOffer() {
        let state = GameFactory.newGame(
            playerNames: ["Buyer", "Turn Player"],
            seed: 17
        )
        let turnPlayerId = state.currentPlayerId
        let buyerId = state.players[0].id
        let turnHandBefore = state.players[1].hand.count
        let viewModel = GameViewModel(state: state)
        viewModel.passBuyOffer()
        viewModel.acknowledgeTurnPassed()

        XCTAssertTrue(
            viewModel.passTimedOutLocalBuyOffer(
                expectedPlayerId: buyerId
            )
        )
        XCTAssertEqual(viewModel.state.currentPlayerId, turnPlayerId)
        XCTAssertEqual(viewModel.state.phase, .awaitingMeldOrDiscard)
        XCTAssertEqual(viewModel.state.players[1].hand.count, turnHandBefore + 1)
    }

    func testHotSeatTimeoutNeverPassesCurrentPlayersFirstRefusal() {
        let state = GameFactory.newGame(
            playerNames: ["Buyer", "Turn Player"],
            seed: 18
        )
        let viewModel = GameViewModel(state: state)

        XCTAssertFalse(
            viewModel.passTimedOutLocalBuyOffer(
                expectedPlayerId: state.currentPlayerId
            )
        )
        XCTAssertEqual(viewModel.state, state)
    }
}
