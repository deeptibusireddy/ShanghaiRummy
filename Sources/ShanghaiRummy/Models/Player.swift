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
    /// The contract level this player is currently attempting (1...10).
    /// Advances by 1 at the end of each hand ONLY if they went down.
    /// The first player to complete level 10 wins the game.
    public var currentLevel: Int

    public init(
        id: UUID = UUID(),
        name: String,
        hand: [Card] = [],
        totalScore: Int = 0,
        buysUsedThisRound: Int = 0,
        hasGoneDownThisRound: Bool = false,
        laidDownThisTurn: Bool = false,
        currentLevel: Int = 1
    ) {
        self.id = id
        self.name = name
        self.hand = hand
        self.totalScore = totalScore
        self.buysUsedThisRound = buysUsedThisRound
        self.hasGoneDownThisRound = hasGoneDownThisRound
        self.laidDownThisTurn = laidDownThisTurn
        self.currentLevel = currentLevel
    }
}
