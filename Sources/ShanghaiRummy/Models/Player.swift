import Foundation

/// A single player at the table.
public struct Player: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    /// Cards currently held privately by this player.
    public var hand: [Card]
    /// Cumulative score across all rounds played so far. Lower is better.
    public var totalScore: Int
    /// Buys used in the current round (max = RulesConfig.maxBuysPerRound).
    public var buysUsedThisRound: Int
    /// True once this player has laid their contract for the current round.
    public var hasGoneDownThisRound: Bool
    /// True only for the interval between going down and the end of that
    /// same turn. Used to reject `addToMeld` and `redeemWild` on the go-down
    /// turn. Reset to false when the turn advances.
    public var laidDownThisTurn: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        hand: [Card] = [],
        totalScore: Int = 0,
        buysUsedThisRound: Int = 0,
        hasGoneDownThisRound: Bool = false,
        laidDownThisTurn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.hand = hand
        self.totalScore = totalScore
        self.buysUsedThisRound = buysUsedThisRound
        self.hasGoneDownThisRound = hasGoneDownThisRound
        self.laidDownThisTurn = laidDownThisTurn
    }
}
