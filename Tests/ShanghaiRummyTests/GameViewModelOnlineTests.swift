import XCTest
@testable import ShanghaiRummy

@MainActor
final class GameViewModelOnlineTests: XCTestCase {
    private func c(_ suit: Suit, _ rank: Rank) -> Card {
        Card(suit: suit, rank: rank)
    }

    func testOnlineViewModelKeepsLocalHandWhenAnotherPlayerHasTurn() {
        var state = GameFactory.newGame(
            playerNames: ["Local", "Remote"],
            seed: 11
        )
        state.currentTurnIndex = 1
        state.buyDecisionPlayerId = state.players[1].id
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
        XCTAssertEqual(viewModel.buyDecisionTitle, "Waiting for Remote")
        XCTAssertEqual(
            viewModel.buyDecisionInstruction,
            "Remote is choosing the discard or passing"
        )
    }

    func testOnlineLocalPlayerCanOrganizeHandDuringRemoteBuyDecision() {
        var state = GameFactory.newGame(
            playerNames: ["Local", "Remote"],
            seed: 11
        )
        let cards = [
            c(.hearts, .king),
            c(.clubs, .three),
            c(.spades, .ace),
            Card.joker(),
            c(.diamonds, .five),
        ]
        state.players[0].hand = cards
        state.currentTurnIndex = 1
        state.buyDecisionPlayerId = state.players[1].id
        let local = state.players[0]
        let viewModel = GameViewModel(
            state: state,
            localPlayerId: local.id
        )

        XCTAssertTrue(viewModel.isBuyDecisionActive)
        XCTAssertFalse(viewModel.isLocalBuyDecision)
        XCTAssertFalse(viewModel.isLocalPlayersTurn)

        viewModel.moveHandCard(cards[3].id, before: cards[0].id)
        XCTAssertEqual(viewModel.orderedHand.first?.id, cards[3].id)

        viewModel.sortHandByRank()
        XCTAssertEqual(
            viewModel.orderedHand.map(\.id),
            [cards[2].id, cards[1].id, cards[4].id, cards[0].id, cards[3].id]
        )

        viewModel.toggleStaged(cardId: cards[0].id)
        XCTAssertTrue(viewModel.stagedCardIds.isEmpty)
    }

    func testOnlineStatusKeepsLocalAndTurnPlayerContractsDistinct() {
        var state = GameFactory.newGame(
            playerNames: ["Local", "Remote"],
            seed: 113
        )
        state.players[0].currentLevel = 5
        state.players[1].currentLevel = 2
        state.currentTurnIndex = 1
        state.buyDecisionPlayerId = state.players[1].id
        let local = state.players[0]
        let remote = state.players[1]
        XCTAssertEqual(state.currentPlayerId, remote.id)

        let viewModel = GameViewModel(
            state: state,
            localPlayerId: local.id
        )

        XCTAssertEqual(
            viewModel.currentContractDescription,
            "1 triplet + 1 sequence of 7"
        )
        XCTAssertEqual(
            viewModel.turnPlayerContractDescription,
            "1 triplet + 1 sequence of 4"
        )
        XCTAssertEqual(viewModel.turnPlayer.hand.count, remote.hand.count)
    }

    func testOnlineTurnPlayerSeesYourDrawInsteadOfPurchaseRound() {
        let state = GameFactory.newGame(
            playerNames: ["Remote", "Local"],
            seed: 111
        )
        let localId = state.currentPlayerId
        let viewModel = GameViewModel(
            state: state,
            localPlayerId: localId
        )

        XCTAssertTrue(viewModel.isLocalBuyDecision)
        XCTAssertTrue(viewModel.isTurnPlayersFirstRefusal)
        XCTAssertEqual(viewModel.buyDecisionTitle, "Your Draw")
        XCTAssertEqual(
            viewModel.buyDecisionInstruction,
            "Take the discard or pass"
        )
    }

    func testOnlineBuyerCanRespondOnlyAfterOfferReachesThem() {
        var state = GameFactory.newGame(
            playerNames: ["Local", "Remote"],
            seed: 12
        )
        let localId = state.players[0].id
        let remoteId = state.players[1].id
        state.currentTurnIndex = 1
        state.buyDecisionPlayerId = remoteId
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
        XCTAssertEqual(viewModel.buyDecisionTitle, "Buy Opportunity")
        XCTAssertEqual(
            viewModel.buyDecisionInstruction,
            "Buy the discard or pass"
        )

        viewModel.acceptBuyOffer()
        XCTAssertEqual(
            submittedAction,
            .acceptBuyOffer(playerId: localId)
        )
        XCTAssertTrue(viewModel.isSubmittingOnlineAction)
    }

    func testOnlineObserverSeesWhoHasTheBuyOpportunity() {
        var state = GameFactory.newGame(
            playerNames: ["Observer", "Turn Player", "Buyer"],
            seed: 112
        )
        let observerId = state.players[0].id
        state.currentTurnIndex = 1
        let turnPlayerId = state.players[1].id
        state.buyDecisionPlayerId = turnPlayerId
        state = try! TurnEngine.apply(
            .passBuyOffer(playerId: turnPlayerId),
            to: state
        ).get()
        let viewModel = GameViewModel(
            state: state,
            localPlayerId: observerId
        )

        XCTAssertEqual(state.buyDecisionPlayer?.name, "Buyer")
        XCTAssertEqual(viewModel.buyDecisionTitle, "Waiting for Buyer")
        XCTAssertEqual(
            viewModel.buyDecisionInstruction,
            "Buyer is deciding whether to buy the discard"
        )
    }

    func testOnlineNextDealerControlsHandAdvanceRegardlessOfWinner() {
        var state = GameFactory.newGame(
            playerNames: ["Winner", "Next Dealer"],
            seed: 114
        )
        state.phase = .roundEnded
        state.dealerIndex = 0
        state.currentTurnIndex = 0
        state.buyDecisionPlayerId = nil
        state.players[0].hasGoneDownThisRound = true
        state.players[0].hand = []

        let winnerViewModel = GameViewModel(
            state: state,
            localPlayerId: state.players[0].id
        )
        let dealerViewModel = GameViewModel(
            state: state,
            localPlayerId: state.players[1].id
        )

        XCTAssertEqual(winnerViewModel.nextDealerName, "Next Dealer")
        XCTAssertFalse(winnerViewModel.canAdvanceHand)
        XCTAssertTrue(dealerViewModel.canAdvanceHand)
        winnerViewModel.advanceHand()
        XCTAssertNotNil(winnerViewModel.lastError)

        var submittedAction: TurnEngine.Action?
        dealerViewModel.configureOnlineActionSubmitter {
            submittedAction = $0
            return true
        }
        dealerViewModel.advanceHand()
        XCTAssertEqual(
            submittedAction,
            .advanceHand(playerId: state.players[1].id)
        )
    }

    func testOnlineHumanCanDealWhenNextDealerIsABot() {
        var state = GameFactory.newGame(
            playerNames: ["Local", "Remote", "Bot 1"],
            seed: 115
        )
        state.phase = .roundEnded
        state.dealerIndex = 1
        state.currentTurnIndex = 0
        state.buyDecisionPlayerId = nil
        state.players[0].hasGoneDownThisRound = true
        state.players[0].hand = []
        let botId = state.players[2].id
        let viewModel = GameViewModel(
            state: state,
            localPlayerId: state.players[0].id
        )
        viewModel.cpuPlayerIds = [botId]
        var submittedAction: TurnEngine.Action?
        viewModel.configureOnlineActionSubmitter {
            submittedAction = $0
            return true
        }

        XCTAssertTrue(viewModel.canAdvanceHand)
        viewModel.advanceHand()

        XCTAssertEqual(
            submittedAction,
            .advanceHand(playerId: botId)
        )
    }

    func testOnlineViewModelDoesNotRunHostsBotActions() {
        var state = GameFactory.newGame(
            playerNames: ["Local", "Bot 1"],
            seed: 116
        )
        state.currentTurnIndex = 0
        state.buyDecisionPlayerId = state.players[0].id
        let localId = state.players[0].id
        let botId = state.players[1].id
        let viewModel = GameViewModel(
            state: state,
            localPlayerId: localId
        )
        viewModel.cpuPlayerIds = [botId]
        var submittedAction: TurnEngine.Action?
        viewModel.configureOnlineActionSubmitter {
            submittedAction = $0
            return true
        }

        XCTAssertTrue(
            viewModel.applyAuthoritative(
                .passBuyOffer(playerId: localId)
            )
        )

        XCTAssertEqual(viewModel.state.activePlayerId, botId)
        XCTAssertNil(submittedAction)
        XCTAssertFalse(viewModel.isSubmittingOnlineAction)
    }

    func testOnlineGoDownSnapshotCanRenderOnOpponentsTable() {
        let firstTriplet = [
            c(.hearts, .king),
            c(.spades, .king),
            c(.diamonds, .king),
        ]
        let secondTriplet = [
            c(.hearts, .seven),
            c(.spades, .seven),
            c(.clubs, .seven),
        ]
        let actor = Player(
            name: "Actor",
            hand: firstTriplet + secondTriplet + [c(.clubs, .three)],
            currentLevel: 1
        )
        let observer = Player(
            name: "Observer",
            hand: [c(.hearts, .four)],
            currentLevel: 1
        )
        let state = GameState(
            players: [actor, observer],
            currentRound: 1,
            currentTurnIndex: 0,
            dealerIndex: 1,
            stock: [c(.clubs, .four), c(.diamonds, .five)],
            discard: [c(.hearts, .three)],
            melds: [],
            phase: .awaitingMeldOrDiscard,
            stockReshufflesUsed: 0,
            randomSeed: 113
        )
        let actorViewModel = GameViewModel(
            state: state,
            localPlayerId: actor.id
        )
        var submittedAction: TurnEngine.Action?
        actorViewModel.configureOnlineActionSubmitter {
            submittedAction = $0
            return true
        }

        actorViewModel.goDown(contract: [firstTriplet, secondTriplet])

        guard let submittedAction else {
            return XCTFail("Going down should submit an online action")
        }
        let authoritative = try! TurnEngine.apply(
            submittedAction,
            to: state
        ).get()
        let observerViewModel = GameViewModel(
            state: state,
            localPlayerId: observer.id
        )
        observerViewModel.receiveAuthoritativeState(authoritative)

        XCTAssertEqual(observerViewModel.state.melds.count, 2)
        XCTAssertTrue(
            observerViewModel.state.players[0].hasGoneDownThisRound
        )

        let scene = GameScene(
            size: CGSize(width: 1, height: 1),
            viewModel: observerViewModel
        )
        scene.size = CGSize(width: 874, height: 402)
        XCTAssertEqual(scene.size, CGSize(width: 874, height: 402))
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
        var state = GameFactory.newGame(
            playerNames: ["Local", "Remote"],
            seed: 15
        )
        state.currentTurnIndex = 1
        state.buyDecisionPlayerId = state.players[1].id
        let local = state.players[0]
        let viewModel = GameViewModel(
            state: state,
            localPlayerId: local.id
        )

        viewModel.toggleStaged(cardId: local.hand[0].id)

        XCTAssertTrue(viewModel.stagedCardIds.isEmpty)
    }

    func testHotSeatPurchaseOfferRequiresDeviceHandoff() {
        var state = GameFactory.newGame(
            playerNames: ["Buyer", "Turn Player"],
            seed: 16
        )
        state.currentTurnIndex = 1
        state.buyDecisionPlayerId = state.players[1].id
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
        var state = GameFactory.newGame(
            playerNames: ["Buyer", "Turn Player"],
            seed: 17
        )
        state.currentTurnIndex = 1
        state.buyDecisionPlayerId = state.players[1].id
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
