import Foundation

public enum Suit: String, CaseIterable, Codable, Sendable {
    case clubs, diamonds, hearts, spades
}

public enum Rank: Int, CaseIterable, Codable, Sendable, Comparable {
    case ace = 1, two, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king

    public static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Points against you if this rank is left unmelded in your hand at end
    /// of round. Note: 2s are ALWAYS wild in this variant, so a 2 in hand
    /// scores 20 (see `Card.points`), not 5.
    public var points: Int {
        switch self {
        case .ace: return 15
        case .two: return 20 // wild — see docs/rules.md
        case .three, .four, .five, .six, .seven, .eight, .nine: return 5
        case .ten, .jack, .queen, .king: return 10
        }
    }
}

public struct Card: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let suit: Suit?
    public let rank: Rank?
    public let isPrintedJoker: Bool

    public init(suit: Suit, rank: Rank) {
        self.id = UUID()
        self.suit = suit
        self.rank = rank
        self.isPrintedJoker = false
    }

    public static func joker() -> Card { Card(joker: true) }

    private init(joker: Bool) {
        self.id = UUID()
        self.suit = nil
        self.rank = nil
        self.isPrintedJoker = true
    }

    /// True if this card is wild (joker or any 2). Wild cards may substitute
    /// for any card in a meld, subject to the per-meld wild limit.
    public var isWild: Bool {
        isPrintedJoker || rank == .two
    }

    /// Penalty points if left in hand at end of a round.
    /// - Joker: 20
    /// - Wild 2: 20 (per family rule)
    /// - Everything else: see `Rank.points`
    public var points: Int {
        if isPrintedJoker { return 20 }
        return rank?.points ?? 0
    }
}

