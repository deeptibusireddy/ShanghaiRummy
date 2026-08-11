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
            .requestBuy(playerId: current),
            .cancelBuyRequest(playerId: current),
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
            action: .draw(playerId: currentId, source: .stock)
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

    func testAuthorityAcceptsOutOfTurnBuyRequestFromItsOwner() {
        let fixture = fixture()
        let requester = fixture.snapshot.participants.first {
            $0.playerId != fixture.snapshot.state.currentPlayerId
        }!
        var authority = RealtimeGameAuthority(snapshot: fixture.snapshot)
        let request = RealtimeActionRequest(
            expectedRevision: 0,
            action: .requestBuy(playerId: requester.playerId)
        )

        let updated = try! authority.apply(
            request,
            fromGamePlayerId: requester.gamePlayerId
        ).get()

        XCTAssertEqual(updated.state.buyRequestPlayerIds, [requester.playerId])
    }

    func testAuthorityMergesSimultaneousBuyRequestsThenUsesSeatPriority() {
        let state = GameFactory.newGame(
            playerNames: ["Farther", "Turn", "Nearest"],
            seed: 18
        )
        XCTAssertEqual(state.currentTurnIndex, 1)
        let bindings = zip(
            ["gc-farther", "gc-turn", "gc-nearest"],
            state.players
        ).map {
            RealtimeParticipantBinding(
                gamePlayerId: $0.0,
                playerId: $0.1.id,
                displayName: $0.1.name
            )
        }
        let snapshot = RealtimeGameSnapshot(
            revision: 0,
            state: state,
            participants: bindings,
            hostGamePlayerId: "gc-turn"
        )
        var authority = RealtimeGameAuthority(snapshot: snapshot)
        let fartherRequest = RealtimeActionRequest(
            expectedRevision: 0,
            action: .requestBuy(playerId: state.players[0].id)
        )
        let nearestRequest = RealtimeActionRequest(
            expectedRevision: 0,
            action: .requestBuy(playerId: state.players[2].id)
        )

        _ = try! authority.apply(
            fartherRequest,
            fromGamePlayerId: "gc-farther"
        ).get()
        let merged = try! authority.apply(
            nearestRequest,
            fromGamePlayerId: "gc-nearest"
        ).get()

        XCTAssertEqual(merged.revision, 2)
        XCTAssertEqual(merged.state.buyRequestPlayerIds.count, 2)
        XCTAssertEqual(
            merged.state.prioritizedBuyRequesterId,
            state.players[2].id
        )
    }

    func testAuthorityDoesNotRebaseRequestFromAnEarlierBuyWindow() {
        let state = GameFactory.newGame(
            playerNames: ["One", "Two", "Three"],
            seed: 19
        )
        let bindings = zip(
            ["gc-one", "gc-two", "gc-three"],
            state.players
        ).map {
            RealtimeParticipantBinding(
                gamePlayerId: $0.0,
                playerId: $0.1.id,
                displayName: $0.1.name
            )
        }
        var authority = RealtimeGameAuthority(
            snapshot: RealtimeGameSnapshot(
                revision: 0,
                state: state,
                participants: bindings,
                hostGamePlayerId: "gc-two"
            )
        )
        let turnPlayer = state.players[1]
        let drawn = try! authority.apply(
            RealtimeActionRequest(
                expectedRevision: 0,
                action: .draw(playerId: turnPlayer.id, source: .stock)
            ),
            fromGamePlayerId: "gc-two"
        ).get()
        _ = try! authority.apply(
            RealtimeActionRequest(
                expectedRevision: drawn.revision,
                action: .discard(
                    playerId: turnPlayer.id,
                    card: drawn.state.players[1].hand[0]
                )
            ),
            fromGamePlayerId: "gc-two"
        ).get()
        let delayed = RealtimeActionRequest(
            expectedRevision: 0,
            action: .requestBuy(playerId: state.players[0].id)
        )

        let result = authority.apply(
            delayed,
            fromGamePlayerId: "gc-one"
        )

        guard case .failure(let rejection) = result else {
            return XCTFail("Expected the old buy request to be stale")
        }
        XCTAssertEqual(rejection.reason, .staleState)
    }
}
