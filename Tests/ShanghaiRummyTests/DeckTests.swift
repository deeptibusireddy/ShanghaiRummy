import XCTest
@testable import ShanghaiRummy

final class DeckTests: XCTestCase {
    func testStandardDeckHas108Cards() {
        let deck = Deck(standardTwoDecksWithJokers: true)
        XCTAssertEqual(deck.count, 108)
    }

    func testJokerPointValue() {
        XCTAssertEqual(Card.joker().points, 25)
    }

    func testAcePointValue() {
        XCTAssertEqual(Card(suit: .spades, rank: .ace).points, 15)
    }

    func testFacePointValues() {
        XCTAssertEqual(Card(suit: .hearts, rank: .king).points, 10)
        XCTAssertEqual(Card(suit: .hearts, rank: .queen).points, 10)
        XCTAssertEqual(Card(suit: .hearts, rank: .jack).points, 10)
    }
}
