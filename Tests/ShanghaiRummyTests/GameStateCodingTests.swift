import XCTest
@testable import ShanghaiRummy

final class GameStateCodingTests: XCTestCase {
    func testDecodesSnapshotCreatedBeforePurchaseStateWasAdded() throws {
        let state = GameFactory.newGame(
            playerNames: ["One", "Two"],
            seed: 17
        )
        let encoded = try JSONEncoder().encode(state)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "buyRequestPlayerIds")
        object.removeValue(forKey: "buyDecisionPlayerId")
        object.removeValue(forKey: "highlightedCardIdsByPlayer")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(GameState.self, from: legacyData)

        XCTAssertTrue(decoded.buyRequestPlayerIds.isEmpty)
        XCTAssertEqual(decoded.buyDecisionPlayerId, decoded.currentPlayerId)
        XCTAssertTrue(decoded.highlightedCardIdsByPlayer.isEmpty)
        XCTAssertEqual(decoded.players, state.players)
    }

    func testRoundTripsHighlightedCardsByPlayer() throws {
        var state = GameFactory.newGame(
            playerNames: ["One", "Two"],
            seed: 23
        )
        let player = state.players[state.currentTurnIndex]
        let card = player.hand[0]
        state.replaceHighlightedCards(for: player.id, with: [card])

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)

        XCTAssertEqual(decoded, state)
        XCTAssertEqual(
            decoded.highlightedCardIds(for: player.id),
            Set([card.id])
        )
    }
}
