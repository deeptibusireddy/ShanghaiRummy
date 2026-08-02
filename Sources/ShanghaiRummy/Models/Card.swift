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
    /// A 2 that has been placed on the discard pile is permanently dead for
    /// the round: it can no longer be used as a wild by whoever picks it up
    /// (draw or buy), and its penalty in hand drops to face value (5 pts).
    /// See `docs/rules.md` "Discarded 2s are dead".
    public var isDead2: Bool

    public init(suit: Suit, rank: Rank) {
        self.id = UUID()
        self.suit = suit
        self.rank = rank
        self.isPrintedJoker = false
        self.isDead2 = false
    }

    public static func joker() -> Card { Card(joker: true) }

    private init(joker: Bool) {
        self.id = UUID()
        self.suit = nil
        self.rank = nil
        self.isPrintedJoker = true
        self.isDead2 = false
    }

    /// True if this card is currently a wild. Jokers are always wild.
    /// A 2 is wild only until it hits the discard pile (see `isDead2`).
    public var isWild: Bool {
        if isPrintedJoker { return true }
        return rank == .two && !isDead2
    }

    /// Penalty points if left in hand at end of a round.
    /// - Joker: 20
    /// - Live wild 2: 20
    /// - Dead 2: 5 (face value; no longer wild)
    /// - Everything else: see `Rank.points`
    public var points: Int {
        if isPrintedJoker { return 20 }
        if rank == .two { return isDead2 ? 5 : 20 }
        return rank?.points ?? 0
    }

    /// Returns a copy of this card marked dead if it is a 2. No-op otherwise.
    /// Used by TurnEngine when discarding a 2 — the dead status persists on
    /// the card and follows it into whoever's hand picks it up next.
    public func markedDeadIfTwo() -> Card {
        guard rank == .two, !isDead2 else { return self }
        var copy = self
        copy.isDead2 = true
        return copy
    }
}

