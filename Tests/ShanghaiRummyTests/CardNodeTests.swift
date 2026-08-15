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
        let highlight = node.childNode(withName: "new-card-highlight")
        XCTAssertNotNil(highlight)
        let badge = highlight?.childNode(
            withName: "new-card-badge"
        )
        XCTAssertNotNil(badge)
        XCTAssertEqual(
            (badge?.childNode(
                withName: "new-card-badge-label"
            ) as? SKLabelNode)?.text,
            "NEW"
        )
        XCTAssertNil(
            highlight?.childNode(withName: "new-card-arrival-glow")
        )

        node.setNewCardHighlighted(false)
        XCTAssertNil(node.childNode(withName: "new-card-highlight"))
    }

    func testNewCardArrivalAddsTemporaryGlow() {
        let node = CardNode(card: Card(suit: .clubs, rank: .queen))

        node.setNewCardHighlighted(true, animateArrival: true)

        let highlight = node.childNode(withName: "new-card-highlight")
        XCTAssertNotNil(
            highlight?.childNode(withName: "new-card-badge")
        )
        XCTAssertNotNil(
            highlight?.childNode(withName: "new-card-arrival-glow")
        )
    }
}
