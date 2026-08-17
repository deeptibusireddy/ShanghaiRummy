import Foundation

/// Validates whether a collection of cards forms a legal triplet or sequence
/// under Shanghai Rummy rules. See `docs/rules.md` for the source-of-truth spec.
///
/// This is a *pure* function — no side effects. Deterministic, easy to test,
/// safe to call from any thread.
public enum MeldValidator {

    // MARK: - Public API

    public struct WildRepresentation: Equatable, Sendable {
        public let suit: Suit
        public let rank: Rank
    }

    public enum ValidationError: Error, Equatable, CustomStringConvertible {
        case emptyMeld
        case tooFewCards(min: Int, got: Int)
        case tooManyWilds(max: Int, got: Int)
        case tripletMixedRanks
        case tripletDuplicateSuits
        case sequenceMixedSuits
        case sequenceNotConsecutive
        case sequenceOutOfRange   // e.g. K-A-2 wrap or start < ace
        case cannotDetermineNaturalRank // all wilds — impossible under rules but guard anyway

        public var description: String {
            switch self {
            case .emptyMeld: return "Meld has no cards"
            case .tooFewCards(let min, let got): return "Meld needs \(min) cards, got \(got)"
            case .tooManyWilds(let max, let got): return "Initial meld allows at most \(max) wild cards, got \(got)"
            case .tripletMixedRanks: return "Triplet cards must all be the same rank"
            case .tripletDuplicateSuits: return "Natural cards in a triplet must have different suits"
            case .sequenceMixedSuits: return "Sequence cards must all be the same suit"
            case .sequenceNotConsecutive: return "Sequence cards must be consecutive"
            case .sequenceOutOfRange: return "Sequence goes out of bounds (Ace does not wrap)"
            case .cannotDetermineNaturalRank: return "Cannot determine the natural rank of an all-wild meld"
            }
        }
    }

    /// Validate a proposed triplet — natural cards must share a rank and use unique suits.
    public static func validateTriplet(_ cards: [Card]) -> Result<Void, ValidationError> {
        validateTriplet(
            cards,
            requiresDistinctNaturalSuits: true,
            enforcesWildLimit: true
        )
    }

    private static func validateTriplet(
        _ cards: [Card],
        requiresDistinctNaturalSuits: Bool,
        enforcesWildLimit: Bool
    ) -> Result<Void, ValidationError> {
        validateTripletRank(
            cards,
            requiresDistinctNaturalSuits: requiresDistinctNaturalSuits,
            enforcesWildLimit: enforcesWildLimit
        ).map { _ in () }
    }

    private static func validateTripletRank(
        _ cards: [Card],
        requiresDistinctNaturalSuits: Bool,
        enforcesWildLimit: Bool
    ) -> Result<Rank, ValidationError> {
        guard !cards.isEmpty else { return .failure(.emptyMeld) }
        guard cards.count >= RulesConfig.minTripletSize else {
            return .failure(.tooFewCards(min: RulesConfig.minTripletSize, got: cards.count))
        }
        let candidateRanks = Rank.allCases.filter { rank in
            cards.contains { $0.isNatural(inTripletOf: rank) }
        }
        guard !candidateRanks.isEmpty else {
            if enforcesWildLimit {
                let maxWilds = RulesConfig.maxWilds(
                    inMeldOfSize: cards.count
                )
                let wildCount = cards.filter(\.isWild).count
                if wildCount > maxWilds {
                    return .failure(
                        .tooManyWilds(max: maxWilds, got: wildCount)
                    )
                }
            }
            return .failure(.cannotDetermineNaturalRank)
        }

        var deferredError: ValidationError = .tripletMixedRanks
        for rank in candidateRanks {
            var naturals: [Card] = []
            var wildCount = 0
            var containsWrongNatural = false

            for card in cards {
                if card.isNatural(inTripletOf: rank) {
                    naturals.append(card)
                } else if card.isWild {
                    wildCount += 1
                } else {
                    containsWrongNatural = true
                    break
                }
            }
            if containsWrongNatural { continue }

            if enforcesWildLimit {
                let maxWilds = RulesConfig.maxWilds(
                    inMeldOfSize: cards.count
                )
                if wildCount > maxWilds {
                    deferredError = .tooManyWilds(
                        max: maxWilds,
                        got: wildCount
                    )
                    continue
                }
            }
            if requiresDistinctNaturalSuits {
                let naturalSuits = naturals.compactMap(\.suit)
                if Set(naturalSuits).count != naturalSuits.count {
                    deferredError = .tripletDuplicateSuits
                    continue
                }
            }
            return .success(rank)
        }
        return .failure(deferredError)
    }

    private static func validateTriplet(
        _ cards: [Card],
        as rank: Rank,
        requiresDistinctNaturalSuits: Bool,
        enforcesWildLimit: Bool
    ) -> Result<Void, ValidationError> {
        var naturals: [Card] = []
        var wildCount = 0
        for card in cards {
            if card.isNatural(inTripletOf: rank) {
                naturals.append(card)
            } else if card.isWild {
                wildCount += 1
            } else {
                return .failure(.tripletMixedRanks)
            }
        }
        if enforcesWildLimit {
            let maxWilds = RulesConfig.maxWilds(inMeldOfSize: cards.count)
            if wildCount > maxWilds {
                return .failure(.tooManyWilds(max: maxWilds, got: wildCount))
            }
        }
        if requiresDistinctNaturalSuits {
            let naturalSuits = naturals.compactMap(\.suit)
            guard Set(naturalSuits).count == naturalSuits.count else {
                return .failure(.tripletDuplicateSuits)
            }
        }
        return .success(())
    }

    /// Validate a proposed sequence.
    /// Cards must be presented in display order (lowest natural rank → highest).
    /// Wild cards are inferred to fill their positional slot.
    public static func validateSequence(_ cards: [Card]) -> Result<Void, ValidationError> {
        validateSequence(cards, enforcesWildLimit: true)
    }

    /// Validate a sequence that is already on the table, where the initial
    /// contract wild limit no longer applies.
    static func validateEstablishedSequence(
        _ cards: [Card]
    ) -> Result<Void, ValidationError> {
        validateSequence(cards, enforcesWildLimit: false)
    }

    private static func validateSequence(
        _ cards: [Card],
        enforcesWildLimit: Bool
    ) -> Result<Void, ValidationError> {
        if let error = sequencePrecheck(
            cards,
            enforcesWildLimit: enforcesWildLimit
        ) {
            return .failure(error)
        }

        // Try both Ace interpretations. Ace-high must also be checked when a
        // trailing wild represents the Ace, for example J-Q-K-joker.
        if consecutiveCheck(cards, aceHigh: false) { return .success(()) }
        if consecutiveCheck(cards, aceHigh: true) { return .success(()) }
        return .failure(.sequenceNotConsecutive)
    }

    /// Accept cards in any hand order and return a legal display order.
    /// Existing valid positional order is preserved so explicitly placed wilds
    /// keep their intended rank.
    public static func arrangedSequence(
        _ cards: [Card]
    ) -> Result<[Card], ValidationError> {
        if let error = sequencePrecheck(cards) { return .failure(error) }
        if case .success = validateSequence(cards) { return .success(cards) }

        let candidates =
            sequenceCandidates(from: cards, aceHigh: false)
            + sequenceCandidates(from: cards, aceHigh: true)
        guard let best = candidates.min(by: { lhs, rhs in
            if lhs.leadingWilds != rhs.leadingWilds {
                return lhs.leadingWilds < rhs.leadingWilds
            }
            if lhs.trailingWilds != rhs.trailingWilds {
                return lhs.trailingWilds < rhs.trailingWilds
            }
            return lhs.startRank > rhs.startRank
        }) else {
            return .failure(.sequenceNotConsecutive)
        }
        return .success(best.cards)
    }

    /// Return every legal positional interpretation for an initial sequence.
    /// Each result represents a different set of ranks occupied by wild cards.
    public static func sequenceArrangements(
        _ cards: [Card]
    ) -> Result<[[Card]], ValidationError> {
        if let error = sequencePrecheck(cards, enforcesWildLimit: true) {
            return .failure(error)
        }

        let candidates =
            sequenceCandidates(from: cards, aceHigh: false)
            + sequenceCandidates(from: cards, aceHigh: true)
        var seenOrders = Set<String>()
        let arrangements = candidates.compactMap { candidate -> [Card]? in
            let key = candidate.cards.map(\.id.uuidString).joined(separator: "|")
            return seenOrders.insert(key).inserted ? candidate.cards : nil
        }
        guard !arrangements.isEmpty else {
            return .failure(.sequenceNotConsecutive)
        }
        return .success(arrangements)
    }

    /// Return the wild slot that `replacement` can legally redeem.
    public static func redeemableWildCardId(
        in meld: Meld,
        using replacement: Card
    ) -> UUID? {
        guard meld.kind == .sequence, !replacement.isWild else { return nil }

        for (index, wild) in meld.cards.enumerated() where wild.isWild {
            var proposed = meld.cards
            proposed[index] = replacement
            if case .success = validateSequence(
                proposed,
                enforcesWildLimit: false
            ) {
                return wild.id
            }
        }
        return nil
    }

    /// Resolve the natural card represented by a positional wild in a sequence.
    public static func representedNatural(
        for wildCardId: UUID,
        in meld: Meld
    ) -> WildRepresentation? {
        guard meld.kind == .sequence,
              meld.cards.contains(where: { $0.id == wildCardId && $0.isWild }),
              let suit = meld.cards.first(where: { !$0.isWild })?.suit else {
            return nil
        }

        for rank in Rank.allCases {
            var candidate = Card(suit: suit, rank: rank)
            if rank == .two {
                candidate = candidate.markedDeadIfTwo()
            }
            if redeemableWildCardId(in: meld, using: candidate) == wildCardId {
                return WildRepresentation(suit: suit, rank: rank)
            }
        }
        return nil
    }

    /// Convenience: try both meld kinds, return whichever succeeds (triplet first).
    public static func validate(_ cards: [Card]) -> Result<Meld.Kind, ValidationError> {
        let tripletResult = validateTriplet(cards)
        if case .success = tripletResult { return .success(.triplet) }

        let sequenceResult = validateSequence(cards)
        if case .success = sequenceResult { return .success(.sequence) }

        if case .failure(let tripletError) = tripletResult,
           (cards.count < RulesConfig.minSequenceSize
                || tripletError == .tripletDuplicateSuits) {
            return .failure(tripletError)
        }
        return sequenceResult.map { .sequence }
    }

    // MARK: - Extensions to existing melds

    /// Validate adding `cards` to an already-laid `meld`.
    /// For triplets: added natural cards must match the rank, but may repeat a
    /// suit already present.
    /// For sequences: cards can be added to either or both ends, keeping the run
    /// contiguous in the same suit. The initial-contract wild limit does not
    /// apply to either kind after it is on the table.
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
            // Initial-contract suit and wild limits do not apply to table play.
            let allAdded = meld.cards + addingCards
            return validateTripletRank(
                meld.cards,
                requiresDistinctNaturalSuits: false,
                enforcesWildLimit: false
            ).flatMap { rank in
                validateTriplet(
                    allAdded,
                    as: rank,
                    requiresDistinctNaturalSuits: false,
                    enforcesWildLimit: false
                )
            }.map { allAdded }
        case .sequence:
            return validateSequence(
                proposed,
                enforcesWildLimit: false
            ).map { proposed }
        }
    }

    // MARK: - Internal

    private struct SequenceCandidate {
        let cards: [Card]
        let leadingWilds: Int
        let trailingWilds: Int
        let startRank: Int
    }

    private static func sequencePrecheck(
        _ cards: [Card],
        enforcesWildLimit: Bool = true
    ) -> ValidationError? {
        guard !cards.isEmpty else { return .emptyMeld }
        guard cards.count >= RulesConfig.minSequenceSize else {
            return .tooFewCards(min: RulesConfig.minSequenceSize, got: cards.count)
        }
        if enforcesWildLimit {
            let maxWilds = RulesConfig.maxWilds(inMeldOfSize: cards.count)
            let wildCount = cards.filter(\.isWild).count
            if wildCount > maxWilds {
                return .tooManyWilds(max: maxWilds, got: wildCount)
            }
        }

        let naturalSuits = cards.compactMap { $0.isWild ? nil : $0.suit }
        guard let firstSuit = naturalSuits.first else {
            return .cannotDetermineNaturalRank
        }
        guard naturalSuits.allSatisfy({ $0 == firstSuit }) else {
            return .sequenceMixedSuits
        }
        return nil
    }

    private static func sequenceCandidates(
        from cards: [Card],
        aceHigh: Bool
    ) -> [SequenceCandidate] {
        let naturals = cards.filter { !$0.isWild }
        let wilds = cards.filter(\.isWild)
        let lowestRank = aceHigh ? 2 : 1
        let highestRank = aceHigh ? 14 : 13
        let latestStart = highestRank - cards.count + 1
        guard latestStart >= lowestRank else { return [] }

        var naturalsByRank: [Int: Card] = [:]
        for card in naturals {
            guard let rank = card.rank else { return [] }
            let value = rank == .ace && aceHigh ? 14 : rank.rawValue
            guard naturalsByRank[value] == nil else { return [] }
            naturalsByRank[value] = card
        }

        var candidates: [SequenceCandidate] = []
        for start in lowestRank...latestStart {
            let end = start + cards.count - 1
            guard naturalsByRank.keys.allSatisfy({
                $0 >= start && $0 <= end
            }) else { continue }

            var arranged: [Card] = []
            var wildIndex = 0
            for value in start...end {
                if let natural = naturalsByRank[value] {
                    arranged.append(natural)
                } else {
                    arranged.append(wilds[wildIndex])
                    wildIndex += 1
                }
            }
            candidates.append(
                SequenceCandidate(
                    cards: arranged,
                    leadingWilds: arranged.prefix(while: { $0.isWild }).count,
                    trailingWilds: arranged.reversed()
                        .prefix(while: { $0.isWild }).count,
                    startRank: start
                )
            )
        }
        return candidates
    }

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
