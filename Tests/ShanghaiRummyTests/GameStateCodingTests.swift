import XCTest
@testable import ShanghaiRummy

final class GameStateCodingTests: XCTestCase {
    func testDecodesSnapshotCreatedBeforeBuyRequestsWereAdded() throws {
        let state = GameFactory.newGame(
            playerNames: ["One", "Two"],
            seed: 17
        )
        let encoded = try JSONEncoder().encode(state)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "buyRequestPlayerIds")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(GameState.self, from: legacyData)

        XCTAssertTrue(decoded.buyRequestPlayerIds.isEmpty)
        XCTAssertEqual(decoded.players, state.players)
    }
}
