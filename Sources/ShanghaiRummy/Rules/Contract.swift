import Foundation

/// A component of a round's contract — either a triplet requirement or a
/// sequence requirement. See `docs/rules.md` for the full spec.
public enum ContractComponent: Codable, Sendable, Equatable {
    case triplet(size: Int)   // e.g. .triplet(size: 3)
    case sequence(size: Int)  // e.g. .sequence(size: 4)

    public var cardCount: Int {
        switch self {
        case .triplet(let n), .sequence(let n): return n
        }
    }

    public var displayName: String {
        switch self {
        case .triplet: return "triplet"
        case .sequence(let n): return "sequence of \(n)"
        }
    }
}

/// A round's contract: the specific combination of triplets/sequences that
/// must be laid down in a single turn to "go down" that round.
public struct Contract: Codable, Sendable, Equatable {
    public let roundNumber: Int
    public let components: [ContractComponent]

    public var totalCards: Int {
        components.reduce(0) { $0 + $1.cardCount }
    }

    public var displayName: String {
        var grouped: [String: Int] = [:]
        var order: [String] = []
        for c in components {
            let key = c.displayName
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: 0] += 1
        }
        return order.map { key -> String in
            let count = grouped[key]!
            return count == 1 ? "1 \(key)" : "\(count) \(pluralize(key))"
        }.joined(separator: " + ")
    }

    private func pluralize(_ s: String) -> String {
        if s == "triplet" { return "triplets" }
        return s.replacingOccurrences(of: "triplet of", with: "triplets of")
            .replacingOccurrences(of: "sequence of", with: "sequences of")
    }
}

/// The 10 rounds of the game as agreed with the family. This is the source of
/// truth in code — keep in sync with `docs/rules.md`.
public enum RoundSchedule {
    public static let all: [Contract] = [
        Contract(roundNumber: 1,  components: [.triplet(size: 3), .triplet(size: 3)]),
        Contract(roundNumber: 2,  components: [.triplet(size: 3), .sequence(size: 4)]),
        Contract(roundNumber: 3,  components: [.sequence(size: 4), .sequence(size: 4)]),
        Contract(roundNumber: 4,  components: [.triplet(size: 3), .triplet(size: 3), .triplet(size: 3)]),
        Contract(roundNumber: 5,  components: [.triplet(size: 3), .sequence(size: 7)]),
        Contract(roundNumber: 6,  components: [.triplet(size: 3), .triplet(size: 3), .sequence(size: 5)]),
        Contract(roundNumber: 7,  components: [.sequence(size: 4), .sequence(size: 4), .sequence(size: 4)]),
        Contract(roundNumber: 8,  components: [.triplet(size: 3), .sequence(size: 10)]),
        Contract(roundNumber: 9,  components: [.triplet(size: 3), .triplet(size: 3), .triplet(size: 3), .sequence(size: 5)]),
        Contract(roundNumber: 10, components: [.sequence(size: 5), .sequence(size: 5), .sequence(size: 5)]),
    ]

    public static func contract(forRound r: Int) -> Contract? {
        all.first(where: { $0.roundNumber == r })
    }
}

/// Game-wide invariants agreed with the family. Change these here rather than
/// scattering magic numbers through the rules engine.
public enum RulesConfig {
    public static let minPlayers = 2
    public static let maxPlayers = 6
    public static let handSizeAtDeal = 11
    public static let maxBuysPerRound = 3
    public static let penaltyCardsOnBuy = 1
    public static let buyOfferTimeoutSeconds = 20
    public static let minTripletSize = 3
    public static let minSequenceSize = 4
    /// Highest contract level. A player who completes level 10 wins the game.
    public static let maxLevel = 10

    /// Maximum wild cards allowed in a meld of the given size (floor(size/2)).
    public static func maxWilds(inMeldOfSize size: Int) -> Int {
        size / 2
    }
}
