import XCTest
@testable import ShanghaiRummy

final class RealtimeGameProtocolTests: XCTestCase {
    private func fixture() -> (
        snapshot: RealtimeGameSnapshot,
        local: RealtimeParticipantBinding,
        remote: RealtimeParticipantBinding
    ) {
        let state = GameFactory.newGame(
            playerNames: ["Local", "Remote"],
            seed: 17
        )
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

    func testSixPlayerSnapshotFitsReliablePacketBudget() throws {
        let state = GameFactory.newGame(
            playerNames: (1...6).map { "Player \($0)" },
            seed: 17
        )
        let participants = state.players.enumerated().map {
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
            hostGamePlayerId: participants[0].gamePlayerId
        )

        let encoded = try RealtimeMessageCodec.encode(.start(snapshot))

        XCTAssertLessThan(encoded.count, 80_000)
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
