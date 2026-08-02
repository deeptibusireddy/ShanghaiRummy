import Foundation

public struct Deck: Codable, Sendable {
    public private(set) var cards: [Card]

    /// Shanghai Rummy deck. Uses 2 standard 52-card decks + 4 jokers (108 cards)
    /// for 2–4 players, or 3 decks + 6 jokers (162 cards) for 5–6 players.
    public init(playerCount: Int) {
        let deckCount: Int
        let jokerCount: Int
        if playerCount >= 5 {
            deckCount = 3
            jokerCount = 6
        } else {
            deckCount = 2
            jokerCount = 4
        }
        var cards: [Card] = []
        for _ in 0..<deckCount {
            for suit in Suit.allCases {
                for rank in Rank.allCases {
                    cards.append(Card(suit: suit, rank: rank))
                }
            }
        }
        for _ in 0..<jokerCount {
            cards.append(.joker())
        }
        self.cards = cards
    }

    /// Fisher-Yates shuffle using a seedable RNG so multiplayer clients can
    /// reproduce the same shuffle from a shared seed (for GameKit sync).
    public mutating func shuffle<G: RandomNumberGenerator>(using rng: inout G) {
        cards.shuffle(using: &rng)
    }

    public mutating func draw() -> Card? { cards.popLast() }

    public var count: Int { cards.count }
}

