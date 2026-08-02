import Foundation

/// A meld laid on the table — either a triplet or a sequence.
///
/// Storage rules:
/// - `cards` is stored in *display order*.
/// - For sequences, cards are ordered by ascending rank position (lowest → highest).
///   The rank a wild card represents is inferred from its position in the sequence.
/// - For triplets, order is not semantically meaningful; store as laid.
public struct Meld: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public var kind: Kind
    public var cards: [Card]
    /// Player who originally laid this meld (for future rule extensions).
    public let ownerId: UUID

    public enum Kind: String, Codable, Sendable {
        case triplet, sequence
    }

    public init(id: UUID = UUID(), kind: Kind, cards: [Card], ownerId: UUID) {
        self.id = id
        self.kind = kind
        self.cards = cards
        self.ownerId = ownerId
    }

    public var size: Int { cards.count }
    public var wildCount: Int { cards.filter(\.isWild).count }
}
