import XCTest
@testable import ShanghaiRummy

final class DeckTests: XCTestCase {
    func test108CardsFor4Players() {
        let deck = Deck(playerCount: 4)
        XCTAssertEqual(deck.count, 108, "2 decks + 4 jokers = 108")
    }

    func test162CardsFor5Players() {
        let deck = Deck(playerCount: 5)
        XCTAssertEqual(deck.count, 162, "3 decks + 6 jokers = 162")
    }

    func test162CardsFor6Players() {
        let deck = Deck(playerCount: 6)
        XCTAssertEqual(deck.count, 162)
    }

    func testJokerPoints() {
        XCTAssertEqual(Card.joker().points, 20, "Joker is worth 20 in hand")
    }

    func testWild2Points() {
        XCTAssertEqual(Card(suit: .spades, rank: .two).points, 20, "Wild 2 is worth 20")
    }

    func testAcePoints() {
        XCTAssertEqual(Card(suit: .spades, rank: .ace).points, 15)
    }

    func testFacePoints() {
        XCTAssertEqual(Card(suit: .hearts, rank: .king).points, 10)
        XCTAssertEqual(Card(suit: .hearts, rank: .queen).points, 10)
        XCTAssertEqual(Card(suit: .hearts, rank: .jack).points, 10)
        XCTAssertEqual(Card(suit: .hearts, rank: .ten).points, 10)
    }

    func testSmallNumberPoints() {
        XCTAssertEqual(Card(suit: .diamonds, rank: .three).points, 5)
        XCTAssertEqual(Card(suit: .diamonds, rank: .nine).points, 5)
    }

    func testIsWild() {
        XCTAssertTrue(Card.joker().isWild)
        XCTAssertTrue(Card(suit: .hearts, rank: .two).isWild)
        XCTAssertFalse(Card(suit: .hearts, rank: .three).isWild)
        XCTAssertFalse(Card(suit: .hearts, rank: .ace).isWild)
    }
}

final class ContractTests: XCTestCase {
    func testAllTenRoundsDefined() {
        XCTAssertEqual(RoundSchedule.all.count, 10)
        for i in 1...10 {
            XCTAssertNotNil(RoundSchedule.contract(forRound: i), "Round \(i) missing")
        }
    }

    func testCardCountsPerRound() {
        // Card counts from docs/rules.md
        let expected: [Int: Int] = [
            1: 6, 2: 7, 3: 8, 4: 9, 5: 10,
            6: 11, 7: 12, 8: 13, 9: 14, 10: 15,
        ]
        for (round, cards) in expected {
            let contract = RoundSchedule.contract(forRound: round)!
            XCTAssertEqual(contract.totalCards, cards, "Round \(round) should need \(cards) cards")
        }
    }

    func testRound10IsThreeSequencesOfFive() {
        let r10 = RoundSchedule.contract(forRound: 10)!
        XCTAssertEqual(r10.components, [.sequence(size: 5), .sequence(size: 5), .sequence(size: 5)])
    }

    func testRound8HasSequenceOfTen() {
        let r8 = RoundSchedule.contract(forRound: 8)!
        XCTAssertTrue(r8.components.contains(.sequence(size: 10)))
    }

    func testContractDisplayNamesDoNotRepeatTripletSize() {
        XCTAssertEqual(
            ContractComponent.triplet(size: 3).displayName,
            "triplet"
        )
        XCTAssertEqual(
            RoundSchedule.contract(forRound: 1)?.displayName,
            "2 triplets"
        )
        XCTAssertEqual(
            RoundSchedule.contract(forRound: 2)?.displayName,
            "1 triplet + 1 sequence of 4"
        )
    }
}

final class RulesConfigTests: XCTestCase {
    func testMaxWildsFloorHalf() {
        XCTAssertEqual(RulesConfig.maxWilds(inMeldOfSize: 3), 1)
        XCTAssertEqual(RulesConfig.maxWilds(inMeldOfSize: 4), 2)
        XCTAssertEqual(RulesConfig.maxWilds(inMeldOfSize: 5), 2)
        XCTAssertEqual(RulesConfig.maxWilds(inMeldOfSize: 6), 3)
        XCTAssertEqual(RulesConfig.maxWilds(inMeldOfSize: 7), 3)
        XCTAssertEqual(RulesConfig.maxWilds(inMeldOfSize: 10), 5)
    }

    func testHandSizeAndBuyLimits() {
        XCTAssertEqual(RulesConfig.handSizeAtDeal, 11)
        XCTAssertEqual(RulesConfig.maxBuysPerRound, 3)
        XCTAssertEqual(RulesConfig.penaltyCardsOnBuy, 1)
    }
}
