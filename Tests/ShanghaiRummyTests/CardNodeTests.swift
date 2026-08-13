import SpriteKit
import XCTest
@testable import ShanghaiRummy

final class CardNodeTests: XCTestCase {
    func testPrintedJokerUsesJesterArtworkAndWordmark() {
        let node = CardNode(card: .joker())

        XCTAssertNotNil(node.childNode(withName: "joker-jester"))
        XCTAssertEqual(
            (node.childNode(withName: "joker-wordmark") as? SKLabelNode)?.text,
            "JOKER"
        )
        XCTAssertEqual(CardNode.shortName(.joker()), "JOKER")
    }

    func testNewCardHighlightCanBeAppliedAndCleared() {
        let node = CardNode(card: Card(suit: .hearts, rank: .ace))

        node.setNewCardHighlighted(true)
        XCTAssertNotNil(node.childNode(withName: "new-card-highlight"))

        node.setNewCardHighlighted(false)
        XCTAssertNil(node.childNode(withName: "new-card-highlight"))
    }
}
