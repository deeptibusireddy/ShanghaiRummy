import XCTest
@testable import ShanghaiRummy

final class RealtimeGameProtocolTests: XCTestCase {
    private func fixture() -> (
        snapshot: RealtimeGameSnapshot,
        local: RealtimeParticipantBinding,
        remote: RealtimeParticipantBinding
    ) {
        var state = GameFactory.newGame(
            playerNames: ["Local", "Remote"],
            seed: 17
        )
        state.dealerIndex = 0
        state.currentTurnIndex = 1
        state.buyDecisionPlayerId = state.players[1].id
        let local = RealtimeParticipantBinding(
            gamePlayerId: "gc-local",
            playerId: state.players[0].id,
            displayName: "Local"
        )
        let remote = RealtimeParticipantBinding(
            gamePlayerId: "gc-remote",
            playerId: state.players[1].id,
            displayName: "Remote"
        )
        return (
            RealtimeGameSnapshot(
                revision: 0,
                state: state,
                participants: [local, remote],
                hostGamePlayerId: local.gamePlayerId
            ),
            local,
            remote
        )
    }

    func testCodecRoundTripsEveryActionShape() throws {
        let fixture = fixture()
        let current = fixture.snapshot.state.currentPlayerId
        let cards = fixture.snapshot.state.players[0].hand
        let meldId = UUID()
        let actions: [TurnEngine.Action] = [
            .draw(playerId: current, source: .stock),
            .goDown(playerId: current, contract: [[cards[0], cards[1]]]),
            .addToMeld(
                playerId: current,
                meldId: meldId,
                cardsAtStart: [cards[0]],
                cardsAtEnd: [cards[1]]
            ),
            .redeemWild(
                playerId: current,
                meldId: meldId,
                wildCardId: UUID(),
                replacementCard: cards[0]
            ),
            .discard(playerId: current, card: cards[0]),
            .acceptBuyOffer(playerId: current),
            .passBuyOffer(playerId: current),
            .advanceHand(playerId: current),
        ]

        for action in actions {
            let message = RealtimeGameMessage.action(
                RealtimeActionRequest(expectedRevision: 4, action: action)
            )
            let encoded = try RealtimeMessageCodec.encode(message)

            XCTAssertEqual(try RealtimeMessageCodec.decode(encoded), message)
        }
    }

    func testCodecRoundTripsOnlineBotSetup() throws {
        let setup = RealtimeGameSetup(botCount: 3)

        XCTAssertEqual(
            try RealtimeMessageCodec.decode(
                RealtimeMessageCodec.encode(.setup(setup))
            ),
            .setup(setup)
        )
        XCTAssertEqual(
            try RealtimeMessageCodec.decode(
                RealtimeMessageCodec.encode(.setupRequest)
            ),
            .setupRequest
        )
    }

    func testMatchmakingGroupsSeparateBotCounts() {
        XCTAssertEqual(
            RealtimeMessageCodec.playerGroup(botCount: 0),
            RealtimeMessageCodec.protocolVersion * 10
        )
        XCTAssertNotEqual(
            RealtimeMessageCodec.playerGroup(botCount: 0),
            RealtimeMessageCodec.playerGroup(botCount: 4)
        )
    }

    func testSixPlayerMixedSnapshotFitsReliablePacketBudget() throws {
        let state = GameFactory.newGame(
            playerNames: (1...6).map { "Player \($0)" },
            seed: 17
        )
        let participants = state.players.prefix(2).enumerated().map {
            RealtimeParticipantBinding(
                gamePlayerId: "gc-player-\($0.offset)",
                playerId: $0.element.id,
                displayName: $0.element.name
            )
        }
        let snapshot = RealtimeGameSnapshot(
            revision: 0,
            state: state,
            participants: participants,
            botPlayerIds: state.players.dropFirst(2).map(\.id),
            hostGamePlayerId: participants[0].gamePlayerId
        )

        let encoded = try RealtimeMessageCodec.encode(.start(snapshot))

        XCTAssertTrue(snapshot.hasValidPlayerIdentityLayout())
        XCTAssertLessThan(encoded.count, 80_000)
    }

    func testMixedSnapshotRequiresEverySeatToBeExactlyOneHumanOrBot() {
        let state = GameFactory.newGame(
            playerNames: ["Human 1", "Human 2", "Bot 1"],
            seed: 18
        )
        let participants = state.players.prefix(2).enumerated().map {
            RealtimeParticipantBinding(
                gamePlayerId: "gc-player-\($0.offset)",
                playerId: $0.element.id,
                displayName: $0.element.name
            )
        }
        let valid = RealtimeGameSnapshot(
            revision: 0,
            state: state,
            participants: participants,
            botPlayerIds: [state.players[2].id],
            hostGamePlayerId: participants[0].gamePlayerId
        )
        let overlapping = RealtimeGameSnapshot(
            revision: 0,
            state: state,
            participants: participants,
            botPlayerIds: [state.players[0].id, state.players[2].id],
            hostGamePlayerId: participants[0].gamePlayerId
        )
        let missingBot = RealtimeGameSnapshot(
            revision: 0,
            state: state,
            participants: participants,
            hostGamePlayerId: participants[0].gamePlayerId
        )

        XCTAssertTrue(valid.hasValidPlayerIdentityLayout())
        XCTAssertFalse(overlapping.hasValidPlayerIdentityLayout())
        XCTAssertFalse(missingBot.hasValidPlayerIdentityLayout())
    }

    func testAuthorityAcceptsCurrentPlayersActionAndIncrementsRevision() {
        let fixture = fixture()
        let currentId = fixture.snapshot.state.currentPlayerId
        let sender = fixture.snapshot.participants.first {
            $0.playerId == currentId
        }!
        var authority = RealtimeGameAuthority(snapshot: fixture.snapshot)
        let request = RealtimeActionRequest(
            expectedRevision: 0,
            action: .acceptBuyOffer(playerId: currentId)
        )

        let updated = try! authority.apply(
            request,
            fromGamePlayerId: sender.gamePlayerId
        ).get()

        XCTAssertEqual(updated.revision, 1)
        XCTAssertEqual(updated.lastAppliedRequestId, request.id)
        XCTAssertEqual(updated.state.phase, .awaitingMeldOrDiscard)
        XCTAssertEqual(authority.snapshot, updated)
    }

    func testAuthorityRejectsPlayerImpersonation() {
        let fixture = fixture()
        var authority = RealtimeGameAuthority(snapshot: fixture.snapshot)
        let request = RealtimeActionRequest(
            expectedRevision: 0,
            action: .draw(
                playerId: fixture.snapshot.state.currentPlayerId,
                source: .stock
            )
        )

        let result = authority.apply(
            request,
            fromGamePlayerId: fixture.local.gamePlayerId
        )

        guard case .failure(let rejection) = result else {
            return XCTFail("Expected an actor mismatch")
        }
        XCTAssertEqual(rejection.reason, .actorMismatch)
        XCTAssertEqual(rejection.currentSnapshot, fixture.snapshot)
    }

    func testAuthorityAppliesHostControlledBotAction() {
        var state = GameFactory.newGame(
            playerNames: ["Human 1", "Human 2", "Bot 1"],
            seed: 19
        )
        state.currentTurnIndex = 2
        state.buyDecisionPlayerId = state.players[2].id
        let participants = state.players.prefix(2).enumerated().map {
            RealtimeParticipantBinding(
                gamePlayerId: "gc-human-\($0.offset)",
                playerId: $0.element.id,
                displayName: $0.element.name
            )
        }
        let botId = state.players[2].id
        let snapshot = RealtimeGameSnapshot(
            revision: 4,
            state: state,
            participants: participants,
            botPlayerIds: [botId],
            hostGamePlayerId: participants[0].gamePlayerId
        )
        var authority = RealtimeGameAuthority(snapshot: snapshot)

        let updated = try! authority.applyBotAction(
            .passBuyOffer(playerId: botId)
        ).get()

        XCTAssertEqual(updated.revision, 5)
        XCTAssertNil(updated.lastAppliedRequestId)
        XCTAssertNotEqual(updated.state.buyDecisionPlayerId, botId)
    }

    func testBotDriverActsOnlyWhenABotOwnsTheLiveDecision() {
        var state = GameFactory.newGame(
            playerNames: ["Human 1", "Human 2", "Bot 1"],
            seed: 22
        )
        state.currentTurnIndex = 2
        state.buyDecisionPlayerId = state.players[2].id
        let participants = state.players.prefix(2).enumerated().map {
            RealtimeParticipantBinding(
                gamePlayerId: "gc-human-\($0.offset)",
                playerId: $0.element.id,
                displayName: $0.element.name
            )
        }
        let botId = state.players[2].id
        var snapshot = RealtimeGameSnapshot(
            revision: 0,
            state: state,
            participants: participants,
            botPlayerIds: [botId],
            hostGamePlayerId: participants[0].gamePlayerId
        )

        XCTAssertEqual(
            RealtimeBotDriver.nextAction(in: snapshot)?.actorPlayerId,
            botId
        )

        state.buyDecisionPlayerId = state.players[0].id
        snapshot = RealtimeGameSnapshot(
            revision: 0,
            state: state,
            participants: participants,
            botPlayerIds: [botId],
            hostGamePlayerId: participants[0].gamePlayerId
        )
        XCTAssertNil(RealtimeBotDriver.nextAction(in: snapshot))

        state.phase = .roundEnded
        state.buyDecisionPlayerId = nil
        snapshot = RealtimeGameSnapshot(
            revision: 0,
            state: state,
            participants: participants,
            botPlayerIds: [botId],
            hostGamePlayerId: participants[0].gamePlayerId
        )
        XCTAssertNil(RealtimeBotDriver.nextAction(in: snapshot))
    }

    func testHostedBotStopsAfterLayingOffItsLastCard() {
        let lastCard = Card(suit: .clubs, rank: .king)
        let human1 = Player(
            name: "Human 1",
            hand: [Card(suit: .clubs, rank: .three)]
        )
        let human2 = Player(
            name: "Human 2",
            hand: [Card(suit: .diamonds, rank: .four)]
        )
        let bot = Player(
            name: "Bot 1",
            hand: [lastCard],
            hasGoneDownThisRound: true,
            laidDownThisTurn: false
        )
        let meld = Meld(
            kind: .triplet,
            cards: [
                Card(suit: .spades, rank: .king),
                Card(suit: .hearts, rank: .king),
                Card(suit: .diamonds, rank: .king),
            ],
            ownerId: human1.id
        )
        let state = GameState(
            players: [human1, human2, bot],
            currentRound: 1,
            currentTurnIndex: 2,
            dealerIndex: 1,
            stock: [Card(suit: .clubs, rank: .five)],
            discard: [Card(suit: .clubs, rank: .six)],
            melds: [meld],
            phase: .awaitingMeldOrDiscard,
            stockReshufflesUsed: 0,
            randomSeed: 23
        )
        let participants = state.players.prefix(2).enumerated().map {
            RealtimeParticipantBinding(
                gamePlayerId: "gc-human-\($0.offset)",
                playerId: $0.element.id,
                displayName: $0.element.name
            )
        }
        let snapshot = RealtimeGameSnapshot(
            revision: 0,
            state: state,
            participants: participants,
            botPlayerIds: [bot.id],
            hostGamePlayerId: participants[0].gamePlayerId
        )
        var authority = RealtimeGameAuthority(snapshot: snapshot)
        let action = try! XCTUnwrap(
            RealtimeBotDriver.nextAction(in: snapshot)
        )

        let updated = try! authority.applyBotAction(action).get()

        XCTAssertEqual(updated.state.phase, .roundEnded)
        XCTAssertTrue(updated.state.players[2].hand.isEmpty)
        XCTAssertNil(RealtimeBotDriver.nextAction(in: updated))
    }

    func testAuthorityDoesNotLetHumanSubmitBotsNormalTurnAction() {
        var state = GameFactory.newGame(
            playerNames: ["Human 1", "Human 2", "Bot 1"],
            seed: 20
        )
        state.currentTurnIndex = 2
        state.buyDecisionPlayerId = state.players[2].id
        let participants = state.players.prefix(2).enumerated().map {
            RealtimeParticipantBinding(
                gamePlayerId: "gc-human-\($0.offset)",
                playerId: $0.element.id,
                displayName: $0.element.name
            )
        }
        let botId = state.players[2].id
        let snapshot = RealtimeGameSnapshot(
            revision: 0,
            state: state,
            participants: participants,
            botPlayerIds: [botId],
            hostGamePlayerId: participants[0].gamePlayerId
        )
        var authority = RealtimeGameAuthority(snapshot: snapshot)

        let result = authority.apply(
            RealtimeActionRequest(
                expectedRevision: 0,
                action: .passBuyOffer(playerId: botId)
            ),
            fromGamePlayerId: participants[0].gamePlayerId
        )

        guard case .failure(let rejection) = result else {
            return XCTFail("A human must not control a bot's live turn")
        }
        XCTAssertEqual(rejection.reason, .actorMismatch)
    }

    func testBotAuthorityRejectsAnActionForAHumanSeat() {
        let fixture = fixture()
        var authority = RealtimeGameAuthority(snapshot: fixture.snapshot)

        let result = authority.applyBotAction(
            .acceptBuyOffer(playerId: fixture.remote.playerId)
        )

        guard case .failure(let error) = result else {
            return XCTFail("Bot authority must reject a human actor")
        }
        XCTAssertEqual(error, .actorIsNotBot)
        XCTAssertEqual(authority.snapshot, fixture.snapshot)
    }

    func testHumanCanRequestNextHandWhenBotIsDealer() {
        var state = GameFactory.newGame(
            playerNames: ["Human 1", "Human 2", "Bot 1"],
            seed: 21
        )
        state.phase = .roundEnded
        state.dealerIndex = 1
        state.currentTurnIndex = 0
        state.buyDecisionPlayerId = nil
        state.players[0].hasGoneDownThisRound = true
        state.players[0].hand = []
        let participants = state.players.prefix(2).enumerated().map {
            RealtimeParticipantBinding(
                gamePlayerId: "gc-human-\($0.offset)",
                playerId: $0.element.id,
                displayName: $0.element.name
            )
        }
        let botId = state.players[2].id
        let snapshot = RealtimeGameSnapshot(
            revision: 0,
            state: state,
            participants: participants,
            botPlayerIds: [botId],
            hostGamePlayerId: participants[0].gamePlayerId
        )
        var authority = RealtimeGameAuthority(snapshot: snapshot)
        let request = RealtimeActionRequest(
            expectedRevision: 0,
            action: .advanceHand(playerId: botId)
        )

        let updated = try! authority.apply(
            request,
            fromGamePlayerId: participants[0].gamePlayerId
        ).get()

        XCTAssertEqual(updated.state.dealerIndex, 2)
        XCTAssertEqual(updated.lastAppliedRequestId, request.id)
    }

    func testAuthorityAllowsOnlyNextDealerToAdvanceHand() {
        let fixture = fixture()
        var state = fixture.snapshot.state
        state.phase = .roundEnded
        state.dealerIndex = 0
        state.currentTurnIndex = 0
        state.buyDecisionPlayerId = nil
        state.players[0].hasGoneDownThisRound = true
        state.players[0].hand = []
        let snapshot = RealtimeGameSnapshot(
            revision: 0,
            state: state,
            participants: fixture.snapshot.participants,
            hostGamePlayerId: fixture.snapshot.hostGamePlayerId
        )
        let request = RealtimeActionRequest(
            expectedRevision: 0,
            action: .advanceHand(playerId: fixture.remote.playerId)
        )

        var rejectedAuthority = RealtimeGameAuthority(snapshot: snapshot)
        let rejected = rejectedAuthority.apply(
            request,
            fromGamePlayerId: fixture.local.gamePlayerId
        )
        guard case .failure(let rejection) = rejected else {
            return XCTFail("The hand winner must not impersonate the next dealer")
        }
        XCTAssertEqual(rejection.reason, .actorMismatch)

        var acceptedAuthority = RealtimeGameAuthority(snapshot: snapshot)
        let accepted = try! acceptedAuthority.apply(
            request,
            fromGamePlayerId: fixture.remote.gamePlayerId
        ).get()
        XCTAssertEqual(accepted.state.dealerIndex, 1)
        XCTAssertEqual(accepted.state.currentTurnIndex, 0)
    }

    func testAuthorityRejectsStaleActionWithLatestSnapshot() {
        let fixture = fixture()
        var authority = RealtimeGameAuthority(snapshot: fixture.snapshot)
        let request = RealtimeActionRequest(
            expectedRevision: 99,
            action: .draw(
                playerId: fixture.snapshot.state.currentPlayerId,
                source: .stock
            )
        )

        let result = authority.apply(
            request,
            fromGamePlayerId: fixture.remote.gamePlayerId
        )

        guard case .failure(let rejection) = result else {
            return XCTFail("Expected a stale-state rejection")
        }
        XCTAssertEqual(rejection.reason, .staleState)
        XCTAssertEqual(rejection.currentSnapshot.revision, 0)
    }

    func testAuthorityAdvancesOfferAfterCurrentPlayerPasses() {
        let fixture = fixture()
        let current = fixture.snapshot.participants.first {
            $0.playerId == fixture.snapshot.state.currentPlayerId
        }!
        let buyer = fixture.snapshot.participants.first {
            $0.playerId != fixture.snapshot.state.currentPlayerId
        }!
        var authority = RealtimeGameAuthority(snapshot: fixture.snapshot)
        let request = RealtimeActionRequest(
            expectedRevision: 0,
            action: .passBuyOffer(playerId: current.playerId)
        )

        let updated = try! authority.apply(
            request,
            fromGamePlayerId: current.gamePlayerId
        ).get()

        XCTAssertEqual(updated.revision, 1)
        XCTAssertEqual(updated.state.buyDecisionPlayerId, buyer.playerId)
        XCTAssertEqual(updated.state.phase, .awaitingDraw)
    }

    func testAuthorityAcceptsOfferFromCurrentDecisionOwner() {
        let fixture = fixture()
        let current = fixture.snapshot.participants.first {
            $0.playerId == fixture.snapshot.state.currentPlayerId
        }!
        let buyer = fixture.snapshot.participants.first {
            $0.playerId != fixture.snapshot.state.currentPlayerId
        }!
        var authority = RealtimeGameAuthority(snapshot: fixture.snapshot)

        let passed = try! authority.apply(
            RealtimeActionRequest(
                expectedRevision: 0,
                action: .passBuyOffer(playerId: current.playerId)
            ),
            fromGamePlayerId: current.gamePlayerId
        ).get()
        let accepted = try! authority.apply(
            RealtimeActionRequest(
                expectedRevision: passed.revision,
                action: .acceptBuyOffer(playerId: buyer.playerId)
            ),
            fromGamePlayerId: buyer.gamePlayerId
        ).get()

        XCTAssertEqual(accepted.revision, 2)
        XCTAssertEqual(accepted.state.phase, .awaitingMeldOrDiscard)
        XCTAssertNil(accepted.state.buyDecisionPlayerId)
        XCTAssertEqual(
            accepted.state.players.first(where: {
                $0.id == buyer.playerId
            })?.buysUsedThisRound,
            1
        )
    }

    func testAuthorityRejectsResponseFromPlayerWithoutTheOffer() {
        let fixture = fixture()
        let buyer = fixture.snapshot.participants.first {
            $0.playerId != fixture.snapshot.state.currentPlayerId
        }!
        var authority = RealtimeGameAuthority(snapshot: fixture.snapshot)
        let result = authority.apply(
            RealtimeActionRequest(
                expectedRevision: 0,
                action: .acceptBuyOffer(playerId: buyer.playerId)
            ),
            fromGamePlayerId: buyer.gamePlayerId
        )

        guard case .failure(let rejection) = result else {
            return XCTFail("Expected the non-owner response to fail")
        }
        XCTAssertEqual(rejection.reason, .illegalAction)
        XCTAssertEqual(rejection.currentSnapshot, fixture.snapshot)
    }

    func testAuthorityTimeoutPassesNonTurnBuyerOffer() {
        let fixture = fixture()
        let current = fixture.snapshot.participants.first {
            $0.playerId == fixture.snapshot.state.currentPlayerId
        }!
        let buyer = fixture.snapshot.participants.first {
            $0.playerId != fixture.snapshot.state.currentPlayerId
        }!
        var authority = RealtimeGameAuthority(snapshot: fixture.snapshot)
        let turnHandBefore = fixture.snapshot.state.players.first(where: {
            $0.id == current.playerId
        })!.hand.count

        let passed = try! authority.apply(
            RealtimeActionRequest(
                expectedRevision: 0,
                action: .passBuyOffer(playerId: current.playerId)
            ),
            fromGamePlayerId: current.gamePlayerId
        ).get()
        let timedOut = authority.passTimedOutBuyOffer(
            playerId: buyer.playerId,
            expectedRevision: passed.revision
        )

        let updated = try! XCTUnwrap(timedOut)
        XCTAssertEqual(updated.revision, 2)
        XCTAssertNil(updated.lastAppliedRequestId)
        XCTAssertEqual(updated.state.phase, .awaitingMeldOrDiscard)
        XCTAssertNil(updated.state.buyDecisionPlayerId)
        XCTAssertEqual(
            updated.state.players.first(where: {
                $0.id == current.playerId
            })?.hand.count,
            turnHandBefore + 1
        )
    }

    func testAuthorityNeverTimesOutCurrentPlayersFirstRefusal() {
        let fixture = fixture()
        var authority = RealtimeGameAuthority(snapshot: fixture.snapshot)

        let result = authority.passTimedOutBuyOffer(
            playerId: fixture.snapshot.state.currentPlayerId,
            expectedRevision: fixture.snapshot.revision
        )

        XCTAssertNil(result)
        XCTAssertEqual(authority.snapshot, fixture.snapshot)
    }

    func testResponseArrivingAfterTimeoutIsRejectedAsStale() {
        let fixture = fixture()
        let current = fixture.snapshot.participants.first {
            $0.playerId == fixture.snapshot.state.currentPlayerId
        }!
        let buyer = fixture.snapshot.participants.first {
            $0.playerId != fixture.snapshot.state.currentPlayerId
        }!
        var authority = RealtimeGameAuthority(snapshot: fixture.snapshot)
        let passed = try! authority.apply(
            RealtimeActionRequest(
                expectedRevision: 0,
                action: .passBuyOffer(playerId: current.playerId)
            ),
            fromGamePlayerId: current.gamePlayerId
        ).get()
        let timedOut = authority.passTimedOutBuyOffer(
            playerId: buyer.playerId,
            expectedRevision: passed.revision
        )
        XCTAssertNotNil(timedOut)

        let result = authority.apply(
            RealtimeActionRequest(
                expectedRevision: passed.revision,
                action: .acceptBuyOffer(playerId: buyer.playerId)
            ),
            fromGamePlayerId: buyer.gamePlayerId
        )

        guard case .failure(let rejection) = result else {
            return XCTFail("Expected the late response to be stale")
        }
        XCTAssertEqual(rejection.reason, .staleState)
    }
}
