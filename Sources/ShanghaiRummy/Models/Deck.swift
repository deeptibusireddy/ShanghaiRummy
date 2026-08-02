import Foundation

public struct Deck: Codable, Sendable {
    public private(set) var cards: [Card]

    /// Two 52-card decks + 4 jokers = 108 cards.
    public init(standardTwoDecksWithJokers: Bool = true) {
        var cards: [Card] = []
        let deckCount = standardTwoDecksWithJokers ? 2 : 1
        for _ in 0..<deckCount {
            for suit in Suit.allCases {
                for rank in Rank.allCases {
                    cards.append(Card(suit: suit, rank: rank))
                }
            }
        }
        if standardTwoDecksWithJokers {
            cards.append(.joker())
            cards.append(.joker())
            cards.append(.joker())
            cards.append(.joker())
        }
        self.cards = cards
    }

    public mutating func shuffle<G: RandomNumberGenerator>(using rng: inout G) {
        cards.shuffle(using: &rng)
    }

    public mutating func draw() -> Card? { cards.popLast() }

    public var count: Int { cards.count }
}
