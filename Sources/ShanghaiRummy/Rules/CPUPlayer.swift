import Foundation

/// Deterministic "practice bot" opponent (M1e). Produces the next
/// `TurnEngine.Action` for a given player based purely on the current
/// `GameState` — no learning, no lookahead beyond one action.
///
/// Design goals:
///  * Correct — never proposes an illegal action; caller can dispatch the
///    result straight to `TurnEngine.apply`.
///  * Reasonable — evaluates draws and buys against the active contract,
///    preserves useful groups and runs, goes down promptly, and sheds cards
///    efficiently after going down.
///  * Pure — no side effects, safe from any thread.
///  * Testable — every heuristic is exposed as an internal helper.
public enum CPUPlayer {

    // MARK: - Public entry point

    /// The next action this CPU would take. Assumes it is this player's turn
    /// or the active buyer during a purchase round.
    /// If the phase is `.roundEnded` / `.gameEnded`, returns a harmless
    /// stock draw (the caller should not be asking on those phases).
    public static func nextAction(for playerId: UUID,
                                  in state: GameState) -> TurnEngine.Action {
        guard let player = state.players.first(where: { $0.id == playerId }) else {
            return .draw(playerId: playerId, source: .stock)
        }
        switch state.phase {
        case .awaitingDraw:
            if state.buyDecisionPlayerId != state.currentPlayerId {
                return shouldBuyDiscard(player: player, state: state)
                    ? .acceptBuyOffer(playerId: player.id)
                    : .passBuyOffer(playerId: player.id)
            }
            return chooseDraw(player: player, state: state)
        case .awaitingMeldOrDiscard:
            return chooseMeldOrDiscard(player: player, state: state)
        case .roundEnded, .gameEnded:
            return .draw(playerId: playerId, source: .stock)
        }
    }

    // MARK: - Draw phase

    static func chooseDraw(player: Player, state: GameState) -> TurnEngine.Action {
        if let top = state.discard.last,
           shouldTakeDiscard(top, player: player, state: state) {
            return .draw(playerId: player.id, source: .discard)
        }
        return .draw(playerId: player.id, source: .stock)
    }

    static func shouldTakeDiscard(
        _ card: Card,
        player: Player,
        state: GameState
    ) -> Bool {
        if player.hasGoneDownThisRound {
            return canLayOff(card: card, on: state.melds)
                || redemptionCreatesPlayableWild(
                    replacement: card,
                    melds: state.melds
                )
        }
        guard let contract = state.contract(forPlayer: player.id) else {
            return card.isWild
        }
        if card.isWild { return true }

        let improvedHand = player.hand + [card]
        if improvedHand.count > contract.totalCards,
           findContractSatisfaction(
               hand: improvedHand,
               contract: contract
           ) != nil {
            return true
        }

        let improvement =
            contractProgressScore(hand: improvedHand, contract: contract)
            - contractProgressScore(hand: player.hand, contract: contract)
        return improvement >= 300
            || (improvement > 0
                && supportsRequiredPattern(
                    card,
                    in: player.hand,
                    contract: contract
                ))
    }

    static func shouldBuyDiscard(
        player: Player,
        state: GameState
    ) -> Bool {
        guard let card = state.discard.last,
              let contract = state.contract(forPlayer: player.id),
              !player.hasGoneDownThisRound else {
            return false
        }
        if card.isWild { return true }

        let improvedHand = player.hand + [card]
        if improvedHand.count >= contract.totalCards,
           findContractSatisfaction(
               hand: improvedHand,
               contract: contract
           ) != nil {
            return true
        }

        let improvement =
            contractProgressScore(hand: improvedHand, contract: contract)
            - contractProgressScore(hand: player.hand, contract: contract)
        let supportsPattern = supportsRequiredPattern(
            card,
            in: player.hand,
            contract: contract
        )
        if card.isDead2 && !supportsPattern {
            return false
        }
        let buysRemaining = max(
            0,
            RulesConfig.maxBuysPerRound - player.buysUsedThisRound
        )
        let strategicBuyBudget: Int
        switch player.currentLevel {
        case ...4: strategicBuyBudget = 1
        case 5...6: strategicBuyBudget = 2
        default: strategicBuyBudget = RulesConfig.maxBuysPerRound
        }
        if player.buysUsedThisRound < strategicBuyBudget,
           (improvement >= 300
            || (improvement > 0 && supportsPattern)) {
            return true
        }

        // An off-turn buyer will still receive its normal draw before it can
        // go down, so only the remaining contract-card deficit must be bought.
        let handShortage = max(
            0,
            contract.totalCards - player.hand.count
        )
        let minimumBuysNeeded = (handShortage + 1) / 2
        if player.currentLevel >= 7,
           minimumBuysNeeded > 0,
           minimumBuysNeeded <= buysRemaining {
            return true
        }

        return false
    }

    // MARK: - Meld / discard phase

    static func chooseMeldOrDiscard(player: Player,
                                    state: GameState) -> TurnEngine.Action {
        // 1. Try to go down on this player's own contract.
        if !player.hasGoneDownThisRound,
           let contract = state.contract(forPlayer: player.id),
           let melds = findContractSatisfaction(
               hand: player.hand,
               contract: contract
           ),
           melds.flatMap({ $0 }).count < player.hand.count {
            return .goDown(playerId: player.id, contract: melds)
        }
        // 2. Redeem a useful wild when the returned wild can immediately be
        //    played elsewhere.
        if player.hasGoneDownThisRound, !player.laidDownThisTurn,
           let action = findWildRedemption(
               playerId: player.id,
               hand: player.hand,
               melds: state.melds
           ) {
            return action
        }
        // 3. Already down — lay off the highest-penalty playable card.
        if player.hasGoneDownThisRound, !player.laidDownThisTurn,
           let action = findLayOff(playerId: player.id,
                                   hand: player.hand,
                                   melds: state.melds) {
            return action
        }
        // 4. Discard.
        return .discard(playerId: player.id,
                        card: chooseDiscard(hand: player.hand,
                                            player: player,
                                            state: state))
    }

    // MARK: - Discard selection

    /// Pick the card to throw away this turn. Before going down, preserve cards
    /// whose removal would most damage contract progress. After going down,
    /// shed the highest penalty card that cannot currently be laid off.
    static func chooseDiscard(hand: [Card],
                              player: Player,
                              state: GameState) -> Card {
        precondition(!hand.isEmpty, "CPU asked to discard from an empty hand")
        let uselessForLayoff: (Card) -> Bool = { card in
            if !player.hasGoneDownThisRound { return true }
            return !CPUPlayer.canLayOff(card: card, on: state.melds)
        }
        let candidates = hand.filter(uselessForLayoff)
        let pool = candidates.isEmpty ? hand : candidates
        let nonWilds = pool.filter { !$0.isWild }
        let discardable = nonWilds.isEmpty ? pool : nonWilds

        guard !player.hasGoneDownThisRound,
              let contract = state.contract(forPlayer: player.id) else {
            return discardable.min(by: discardTieBreaker) ?? hand[0]
        }

        let baseline = contractProgressScore(
            hand: hand,
            contract: contract
        )
        return discardable.min { lhs, rhs in
            let lhsLoss = contractLoss(
                removing: lhs,
                from: hand,
                contract: contract,
                baseline: baseline
            )
            let rhsLoss = contractLoss(
                removing: rhs,
                from: hand,
                contract: contract,
                baseline: baseline
            )
            if lhsLoss != rhsLoss {
                return lhsLoss < rhsLoss
            }

            let lhsRisk = publicDiscardRisk(lhs, state: state)
            let rhsRisk = publicDiscardRisk(rhs, state: state)
            if lhsRisk != rhsRisk {
                return lhsRisk < rhsRisk
            }
            return discardTieBreaker(lhs, rhs)
        } ?? hand[0]
    }

    private struct PartialContractMatch {
        let targetSize: Int
        let naturalCount: Int
        let maxWilds: Int
        var wildsUsed = 0

        var filledCount: Int {
            min(targetSize, naturalCount + wildsUsed)
        }
    }

    private static func contractProgressScore(
        hand: [Card],
        contract: Contract
    ) -> Int {
        if findContractSatisfaction(
            hand: hand,
            contract: contract
        ) != nil {
            return 10_000
        }

        var availableNaturals = hand.filter { !$0.isPrintedJoker }
        var usedNaturalIds = Set<UUID>()
        let orderedComponents = contract.components.sorted { lhs, rhs in
            if lhs.cardCount != rhs.cardCount {
                return lhs.cardCount > rhs.cardCount
            }
            return isSequence(lhs) && !isSequence(rhs)
        }
        var matches: [PartialContractMatch] = []
        for component in orderedComponents {
            let cards = bestNaturalMatch(
                for: component,
                from: availableNaturals
            )
            let ids = Set(cards.map(\.id))
            usedNaturalIds.formUnion(ids)
            availableNaturals.removeAll { ids.contains($0.id) }
            matches.append(
                PartialContractMatch(
                    targetSize: component.cardCount,
                    naturalCount: cards.count,
                    maxWilds: RulesConfig.maxWilds(
                        inMeldOfSize: component.cardCount
                    )
                )
            )
        }

        var remainingWilds = hand.filter {
            $0.isWild && !usedNaturalIds.contains($0.id)
        }.count
        while remainingWilds > 0 {
            var bestIndex: Int?
            var bestGain = 0
            for index in matches.indices {
                let match = matches[index]
                guard match.naturalCount > 0,
                      match.wildsUsed < match.maxWilds,
                      match.filledCount < match.targetSize else {
                    continue
                }
                let gain =
                    componentProgressScore(
                        filled: match.filledCount + 1,
                        target: match.targetSize
                    )
                    - componentProgressScore(
                        filled: match.filledCount,
                        target: match.targetSize
                    )
                if gain > bestGain {
                    bestGain = gain
                    bestIndex = index
                }
            }
            guard let bestIndex else { break }
            matches[bestIndex].wildsUsed += 1
            remainingWilds -= 1
        }

        let matchedScore = matches.reduce(0) { total, match in
            total + componentProgressScore(
                filled: match.filledCount,
                target: match.targetSize
            )
        }
        return matchedScore + remainingWilds * 35
    }

    private static func bestNaturalMatch(
        for component: ContractComponent,
        from cards: [Card]
    ) -> [Card] {
        switch component {
        case .triplet(let size):
            var best: [Card] = []
            for rank in Rank.allCases {
                let matching = Suit.allCases.compactMap { suit in
                    cards.first {
                        $0.isNatural(inTripletOf: rank)
                            && $0.suit == suit
                    }
                }
                let candidate = Array(matching.prefix(size))
                if isBetterNaturalMatch(candidate, than: best) {
                    best = candidate
                }
            }
            return best

        case .sequence(let size):
            let latestStart = 14 - size + 1
            guard latestStart >= 1 else { return [] }
            var best: [Card] = []
            for suit in Suit.allCases {
                for start in 1...latestStart {
                    var candidate: [Card] = []
                    for value in start..<(start + size) {
                        guard let rank = sequenceRank(for: value),
                              let card = cards.first(where: {
                                  !$0.isWild
                                      && $0.suit == suit
                                      && $0.rank == rank
                              }) else {
                            continue
                        }
                        candidate.append(card)
                    }
                    if isBetterNaturalMatch(candidate, than: best) {
                        best = candidate
                    }
                }
            }
            return best
        }
    }

    private static func isBetterNaturalMatch(
        _ candidate: [Card],
        than current: [Card]
    ) -> Bool {
        if candidate.count != current.count {
            return candidate.count > current.count
        }
        return candidate.reduce(0) { $0 + $1.points }
            > current.reduce(0) { $0 + $1.points }
    }

    private static func componentProgressScore(
        filled: Int,
        target: Int
    ) -> Int {
        guard filled > 0 else { return 0 }
        var score = filled * 100
        if filled == target {
            score += 800
        } else if filled == target - 1 {
            score += 300
        } else if filled >= 2 {
            score += 60
        }
        return score
    }

    private static func supportsRequiredPattern(
        _ card: Card,
        in hand: [Card],
        contract: Contract
    ) -> Bool {
        if card.isWild { return true }
        for component in contract.components {
            switch component {
            case .triplet:
                if hand.contains(where: {
                    !$0.isWild
                        && $0.rank == card.rank
                        && $0.suit != card.suit
                }) {
                    return true
                }
            case .sequence(let size):
                if hand.contains(where: {
                    !$0.isWild
                        && $0.suit == card.suit
                        && sharesSequenceWindow(
                            card,
                            $0,
                            size: size
                        )
                }) {
                    return true
                }
            }
        }
        return false
    }

    private static func sharesSequenceWindow(
        _ lhs: Card,
        _ rhs: Card,
        size: Int
    ) -> Bool {
        let latestStart = 14 - size + 1
        guard latestStart >= 1 else { return false }
        for lhsValue in sequenceValues(for: lhs) {
            for rhsValue in sequenceValues(for: rhs) {
                for start in 1...latestStart
                where (start..<(start + size)).contains(lhsValue)
                    && (start..<(start + size)).contains(rhsValue) {
                    return true
                }
            }
        }
        return false
    }

    private static func sequenceValues(for card: Card) -> [Int] {
        guard let rank = card.rank else { return [] }
        return rank == .ace ? [Rank.ace.rawValue, 14] : [rank.rawValue]
    }

    private static func sequenceRank(for value: Int) -> Rank? {
        value == 14 ? .ace : Rank(rawValue: value)
    }

    private static func isSequence(_ component: ContractComponent) -> Bool {
        if case .sequence = component { return true }
        return false
    }

    private static func contractLoss(
        removing card: Card,
        from hand: [Card],
        contract: Contract,
        baseline: Int
    ) -> Int {
        let remaining = hand.filter { $0.id != card.id }
        return max(
            0,
            baseline - contractProgressScore(
                hand: remaining,
                contract: contract
            )
        )
    }

    private static func publicDiscardRisk(
        _ card: Card,
        state: GameState
    ) -> Int {
        if card.isWild { return 1_000 }
        return canLayOff(card: card, on: state.melds) ? 100 : 0
    }

    /// `true` when `lhs` is the preferred discard among equally useful cards.
    private static func discardTieBreaker(
        _ lhs: Card,
        _ rhs: Card
    ) -> Bool {
        if lhs.points != rhs.points {
            return lhs.points > rhs.points
        }
        let lhsRank = lhs.rank?.rawValue ?? Int.max
        let rhsRank = rhs.rank?.rawValue ?? Int.max
        if lhsRank != rhsRank {
            return lhsRank > rhsRank
        }
        let lhsSuit = lhs.suit?.rawValue ?? ""
        let rhsSuit = rhs.suit?.rawValue ?? ""
        if lhsSuit != rhsSuit {
            return lhsSuit < rhsSuit
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    // MARK: - Lay-off search

    /// If any hand card can extend an existing meld, return the action that
    /// sheds the highest-penalty card first.
    static func findLayOff(playerId: UUID,
                           hand: [Card],
                           melds: [Meld]) -> TurnEngine.Action? {
        var best: (action: TurnEngine.Action, card: Card)?
        for meld in melds {
            for card in hand {
                if canAdd(card, to: meld, atStart: false) {
                    let action = TurnEngine.Action.addToMeld(
                        playerId: playerId,
                        meldId: meld.id,
                        cardsAtStart: [],
                        cardsAtEnd: [card]
                    )
                    if best == nil
                        || discardTieBreaker(card, best!.card) {
                        best = (action, card)
                    }
                }
                if canAdd(card, to: meld, atStart: true) {
                    let action = TurnEngine.Action.addToMeld(
                        playerId: playerId,
                        meldId: meld.id,
                        cardsAtStart: [card],
                        cardsAtEnd: []
                    )
                    if best == nil
                        || discardTieBreaker(card, best!.card) {
                        best = (action, card)
                    }
                }
            }
        }
        return best?.action
    }

    /// Redeem a positional wild only when that wild can be laid off after the
    /// swap, ensuring the two-action sequence reduces the bot's hand.
    static func findWildRedemption(
        playerId: UUID,
        hand: [Card],
        melds: [Meld]
    ) -> TurnEngine.Action? {
        var best: (action: TurnEngine.Action, replacement: Card)?
        for card in hand where !card.isWild {
            guard let opportunity = playableRedemption(
                replacement: card,
                melds: melds
            ) else {
                continue
            }
            let action = TurnEngine.Action.redeemWild(
                playerId: playerId,
                meldId: opportunity.meldId,
                wildCardId: opportunity.wildCardId,
                replacementCard: card
            )
            if best == nil
                || discardTieBreaker(card, best!.replacement) {
                best = (action, card)
            }
        }
        return best?.action
    }

    /// True if the given card would extend some existing meld.
    static func canLayOff(card: Card, on melds: [Meld]) -> Bool {
        for meld in melds {
            if canAdd(card, to: meld, atStart: false) { return true }
            if canAdd(card, to: meld, atStart: true) { return true }
        }
        return false
    }

    private static func canAdd(_ card: Card, to meld: Meld, atStart: Bool) -> Bool {
        let cardsAtStart = atStart ? [card] : []
        let cardsAtEnd = atStart ? [] : [card]
        if case .success = MeldValidator.validateAddition(
            addingCards: [card],
            atStart: cardsAtStart,
            atEnd: cardsAtEnd,
            to: meld
        ) {
            return true
        }
        return false
    }

    private static func redemptionCreatesPlayableWild(
        replacement: Card,
        melds: [Meld]
    ) -> Bool {
        playableRedemption(
            replacement: replacement,
            melds: melds
        ) != nil
    }

    private static func playableRedemption(
        replacement: Card,
        melds: [Meld]
    ) -> (meldId: UUID, wildCardId: UUID)? {
        guard !replacement.isWild else { return nil }

        for meldIndex in melds.indices {
            let meld = melds[meldIndex]
            guard let wildCardId = MeldValidator.redeemableWildCardId(
                in: meld,
                using: replacement
            ),
            let wildIndex = meld.cards.firstIndex(where: {
                $0.id == wildCardId
            }) else {
                continue
            }

            let wild = meld.cards[wildIndex]
            var updatedMelds = melds
            updatedMelds[meldIndex].cards[wildIndex] = replacement
            if canLayOff(card: wild, on: updatedMelds) {
                return (meld.id, wildCardId)
            }
        }
        return nil
    }

    // MARK: - Contract satisfaction search

    /// Try to partition a subset of `hand` into melds that satisfy every
    /// component of `contract`. Returns the partition (one meld per
    /// component, in contract order) or nil if impossible with the current
    /// hand. Uses a small backtracking search with wild-count preference.
    public static func findContractSatisfaction(hand: [Card],
                                                contract: Contract) -> [[Card]]? {
        var used = Set<UUID>()
        var result: [[Card]] = []
        if search(components: contract.components,
                  hand: hand, used: &used, result: &result) {
            return result
        }
        return nil
    }

    private static func search(components: [ContractComponent],
                               hand: [Card],
                               used: inout Set<UUID>,
                               result: inout [[Card]]) -> Bool {
        guard let head = components.first else { return true }
        let rest = Array(components.dropFirst())
        for candidate in candidateMelds(for: head, hand: hand, used: used) {
            for c in candidate { used.insert(c.id) }
            result.append(candidate)
            if search(components: rest, hand: hand, used: &used, result: &result) {
                return true
            }
            result.removeLast()
            for c in candidate { used.remove(c.id) }
        }
        return false
    }

    static func candidateMelds(for component: ContractComponent,
                               hand: [Card],
                               used: Set<UUID>) -> [[Card]] {
        let available = hand.filter { !used.contains($0.id) }
        switch component {
        case .triplet(let n):
            return candidateTriplets(of: n, from: available)
        case .sequence(let n):
            return candidateSequences(of: n, from: available)
        }
    }

    /// All ways to build a triplet of `size` from `hand`. Prefers fewer wilds.
    static func candidateTriplets(of size: Int, from hand: [Card]) -> [[Card]] {
        let maxWilds = RulesConfig.maxWilds(inMeldOfSize: size)
        var candidates: [[Card]] = []
        for rank in Rank.allCases {
            let wilds = hand.filter {
                $0.isWild && !$0.isNatural(inTripletOf: rank)
            }
            let distinctSuitNaturals = Suit.allCases.compactMap { suit in
                hand.first(where: {
                    $0.isNatural(inTripletOf: rank)
                        && $0.suit == suit
                })
            }
            for w in 0...min(maxWilds, wilds.count) {
                let naturalsNeeded = size - w
                guard naturalsNeeded >= 1 else { continue }
                guard distinctSuitNaturals.count >= naturalsNeeded else {
                    continue
                }
                for pickedNaturals in combinations(
                    distinctSuitNaturals,
                    choosing: naturalsNeeded
                ) {
                    candidates.append(
                        pickedNaturals + Array(wilds.prefix(w))
                    )
                }
            }
        }
        return candidates.sorted(by: prefersContractCandidate)
    }

    private static func combinations<T>(
        _ values: [T],
        choosing count: Int
    ) -> [[T]] {
        guard count >= 0, count <= values.count else { return [] }
        if count == 0 { return [[]] }
        if count == values.count { return [values] }

        var result: [[T]] = []
        for index in 0...(values.count - count) {
            let tails = combinations(
                Array(values.dropFirst(index + 1)),
                choosing: count - 1
            )
            result.append(contentsOf: tails.map { [values[index]] + $0 })
        }
        return result
    }

    /// All ways to build a sequence of `size` from `hand`. Prefers fewer wilds.
    static func candidateSequences(of size: Int, from hand: [Card]) -> [[Card]] {
        let wilds = hand.filter { $0.isWild }
        let maxWilds = RulesConfig.maxWilds(inMeldOfSize: size)
        let latestStart = 14 - size + 1
        guard latestStart >= 1 else { return [] }

        var candidates: [[Card]] = []
        var seen = Set<String>()
        for suit in Suit.allCases {
            for start in 1...latestStart {
                var picked: [Card] = []
                var wildsUsed = 0
                for value in start..<(start + size) {
                    guard let neededRank = sequenceRank(for: value) else {
                        picked.removeAll()
                        break
                    }
                    if let match = hand.first(where: {
                        !$0.isWild
                            && $0.suit == suit
                            && $0.rank == neededRank
                    }) {
                        picked.append(match)
                    } else if wildsUsed < wilds.count && wildsUsed < maxWilds {
                        picked.append(wilds[wildsUsed])
                        wildsUsed += 1
                    } else {
                        picked.removeAll()
                        break
                    }
                }
                guard picked.count == size,
                      case .success =
                        MeldValidator.validateSequence(picked) else {
                    continue
                }
                let key = picked.map(\.id.uuidString).joined(separator: "|")
                if seen.insert(key).inserted {
                    candidates.append(picked)
                }
            }
        }
        return candidates.sorted(by: prefersContractCandidate)
    }

    private static func prefersContractCandidate(
        _ lhs: [Card],
        _ rhs: [Card]
    ) -> Bool {
        let lhsWilds = lhs.filter(\.isWild).count
        let rhsWilds = rhs.filter(\.isWild).count
        if lhsWilds != rhsWilds {
            return lhsWilds < rhsWilds
        }
        let lhsPoints = lhs.reduce(0) { $0 + $1.points }
        let rhsPoints = rhs.reduce(0) { $0 + $1.points }
        if lhsPoints != rhsPoints {
            return lhsPoints > rhsPoints
        }
        let lhsKey = lhs.map(\.id.uuidString).joined(separator: "|")
        let rhsKey = rhs.map(\.id.uuidString).joined(separator: "|")
        return lhsKey < rhsKey
    }
}
