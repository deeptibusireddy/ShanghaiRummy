import Foundation

/// Validates whether a collection of cards forms a legal triplet or sequence
/// under Shanghai Rummy rules. See `docs/rules.md` for the source-of-truth spec.
///
/// This is a *pure* function — no side effects. Deterministic, easy to test,
/// safe to call from any thread.
public enum MeldValidator {

    // MARK: - Public API

    public enum ValidationError: Error, Equatable, CustomStringConvertible {
        case emptyMeld
        case tooFewCards(min: Int, got: Int)
        case tooManyWilds(max: Int, got: Int)
        case tripletMixedRanks
        case sequenceMixedSuits
        case sequenceNotConsecutive
        case sequenceOutOfRange   // e.g. K-A-2 wrap or start < ace
        case cannotDetermineNaturalRank // all wilds — impossible under rules but guard anyway

        public var description: String {
            switch self {
            case .emptyMeld: return "Meld has no cards"
            case .tooFewCards(let min, let got): return "Meld needs \(min) cards, got \(got)"
            case .tooManyWilds(let max, let got): return "Meld allows at most \(max) wild cards, got \(got)"
            case .tripletMixedRanks: return "Triplet cards must all be the same rank"
            case .sequenceMixedSuits: return "Sequence cards must all be the same suit"
            case .sequenceNotConsecutive: return "Sequence cards must be consecutive"
            case .sequenceOutOfRange: return "Sequence goes out of bounds (Ace does not wrap)"
            case .cannotDetermineNaturalRank: return "Cannot determine the natural rank of an all-wild meld"
            }
        }
    }

    /// Validate a proposed triplet — cards must be the same rank (with wild substitutes).
    public static func validateTriplet(_ cards: [Card]) -> Result<Void, ValidationError> {
        guard !cards.isEmpty else { return .failure(.emptyMeld) }
        guard cards.count >= RulesConfig.minTripletSize else {
            return .failure(.tooFewCards(min: RulesConfig.minTripletSize, got: cards.count))
        }
        let maxWilds = RulesConfig.maxWilds(inMeldOfSize: cards.count)
        let wilds = cards.filter(\.isWild).count
        if wilds > maxWilds { return .failure(.tooManyWilds(max: maxWilds, got: wilds)) }

        let naturalRanks = cards.compactMap { $0.isWild ? nil : $0.rank }
        guard let first = naturalRanks.first else {
            return .failure(.cannotDetermineNaturalRank)
        }
        guard naturalRanks.allSatisfy({ $0 == first }) else {
            return .failure(.tripletMixedRanks)
        }
        return .success(())
    }

    /// Validate a proposed sequence.
    /// Cards must be presented in display order (lowest natural rank → highest).
    /// Wild cards are inferred to fill their positional slot.
    public static func validateSequence(_ cards: [Card]) -> Result<Void, ValidationError> {
        guard !cards.isEmpty else { return .failure(.emptyMeld) }
        guard cards.count >= RulesConfig.minSequenceSize else {
            return .failure(.tooFewCards(min: RulesConfig.minSequenceSize, got: cards.count))
        }
        let maxWilds = RulesConfig.maxWilds(inMeldOfSize: cards.count)
        let wilds = cards.filter(\.isWild).count
        if wilds > maxWilds { return .failure(.tooManyWilds(max: maxWilds, got: wilds)) }

        // All non-wilds must share a suit.
        let naturalSuits = cards.compactMap { $0.isWild ? nil : $0.suit }
        guard let first = naturalSuits.first else {
            return .failure(.cannotDetermineNaturalRank)
        }
        guard naturalSuits.allSatisfy({ $0 == first }) else {
            return .failure(.sequenceMixedSuits)
        }

        // Try Ace-low first. If that fails and the meld contains an Ace, try Ace-high.
        if consecutiveCheck(cards, aceHigh: false) { return .success(()) }
        let containsAce = cards.contains { !$0.isWild && $0.rank == .ace }
        if containsAce && consecutiveCheck(cards, aceHigh: true) { return .success(()) }
        return .failure(.sequenceNotConsecutive)
    }

    /// Convenience: try both meld kinds, return whichever succeeds (triplet first).
    public static func validate(_ cards: [Card]) -> Result<Meld.Kind, ValidationError> {
        if case .success = validateTriplet(cards) { return .success(.triplet) }
        return validateSequence(cards).map { .sequence }
    }

    // MARK: - Extensions to existing melds

    /// Validate adding `cards` to an already-laid `meld`.
    /// For triplets: added cards must match the triplet's rank (or be wild), and
    /// the resulting wild count must not exceed the new size's floor(size/2) limit.
    /// For sequences: cards can be added to either or both ends, keeping the run
    /// contiguous in the same suit, with the wild limit respected.
    ///
    /// Returns the proposed new full meld cards on success.
    public static func validateAddition(
        addingCards: [Card],
        atStart: [Card],
        atEnd: [Card],
        to meld: Meld
    ) -> Result<[Card], ValidationError> {
        guard atStart.count + atEnd.count == addingCards.count else {
            return .failure(.sequenceNotConsecutive) // reuse; caller passed inconsistent split
        }
        let proposed: [Card] = atStart + meld.cards + atEnd
        switch meld.kind {
        case .triplet:
            // For triplets, position doesn't matter — just re-validate as a triplet.
            let allAdded = meld.cards + addingCards
            return validateTriplet(allAdded).map { allAdded }
        case .sequence:
            return validateSequence(proposed).map { proposed }
        }
    }

    // MARK: - Internal

    /// Given cards in intended sequence order, check that non-wild positions
    /// match a monotonically increasing rank progression with same suit.
    /// `aceHigh` treats an Ace natural card as rank 14.
    private static func consecutiveCheck(_ cards: [Card], aceHigh: Bool) -> Bool {
        var startRank: Int? = nil
        for (idx, card) in cards.enumerated() {
            if card.isWild { continue }
            guard let r = card.rank else { return false }
            let effectiveRank: Int
            if r == .ace && aceHigh {
                effectiveRank = 14
            } else {
                effectiveRank = r.rawValue
            }
            let inferredStart = effectiveRank - idx
            if let s = startRank {
                if s != inferredStart { return false }
            } else {
                startRank = inferredStart
            }
        }
        guard let start = startRank else { return false }
        let end = start + cards.count - 1
        // Ace-low progression: start >= 1, end <= 13.
        // Ace-high progression: start >= 2 (can't start below 2 with ace at top), end <= 14.
        if aceHigh {
            return start >= 2 && end <= 14
        } else {
            return start >= 1 && end <= 13
        }
    }
}
