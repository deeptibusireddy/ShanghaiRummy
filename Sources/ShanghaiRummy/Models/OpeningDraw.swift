import Foundation

/// The card a player drew to determine the match's clockwise seating order.
public struct OpeningDraw: Codable, Sendable, Equatable, Identifiable {
    public let playerId: UUID
    public let card: Card

    public var id: UUID { playerId }

    /// Opening draws treat Ace as the highest rank. Jokers are never used.
    public var seatingValue: Int {
        guard let rank = card.rank else { return 0 }
        return rank == .ace ? 14 : rank.rawValue
    }

    public init(playerId: UUID, card: Card) {
        self.playerId = playerId
        self.card = card
    }
}
