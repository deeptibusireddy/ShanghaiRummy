import Foundation

public enum Suit: String, CaseIterable, Codable, Sendable {
    case clubs, diamonds, hearts, spades
}

public enum Rank: Int, CaseIterable, Codable, Sendable, Comparable {
    case ace = 1, two, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king

    public static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Point value used for end-of-round scoring (unmelded cards in hand).
    public var points: Int {
        switch self {
        case .ace: return 15
        case .two, .three, .four, .five, .six, .seven, .eight, .nine: return 5
        case .ten, .jack, .queen, .king: return 10
        }
    }
}

public struct Card: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let suit: Suit?
    public let rank: Rank?
    public let isJoker: Bool

    public init(suit: Suit, rank: Rank) {
        self.id = UUID()
        self.suit = suit
        self.rank = rank
        self.isJoker = false
    }

    public static func joker() -> Card { Card(joker: true) }

    private init(joker: Bool) {
        self.id = UUID()
        self.suit = nil
        self.rank = nil
        self.isJoker = true
    }

    public var points: Int {
        if isJoker { return 25 }
        return rank?.points ?? 0
    }
}
