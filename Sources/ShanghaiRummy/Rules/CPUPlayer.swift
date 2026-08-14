import Foundation

/// Deterministic "practice bot" opponent (M1e). Produces the next
/// `TurnEngine.Action` for a given player based purely on the current
/// `GameState` — no learning, no lookahead beyond one action.
///
/// Design goals:
///  * Correct — never proposes an illegal action; caller can dispatch the
///    result straight to `TurnEngine.apply`.
///  * Reasonable — takes wild cards off the discard, goes down as soon as
///    its hand satisfies the contract, lays off cards when possible,
///    discards the highest-penalty non-wild otherwise.
///  * Pure — no side effects, safe from any thread.
///  * Testable — every heuristic is exposed as an internal helper.
///
/// Not covered in this iteration (deferred): wild redemption and
/// discard-guarding to prevent opponents from completing a contract.
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
                if state.discard.last?.isWild == true {
                    return .acceptBuyOffer(playerId: player.id)
                }
                return .passBuyOffer(playerId: player.id)
            }
            return chooseDraw(player: player, state: state)
        case .awaitingMeldOrDiscard:
            return chooseMeldOrDiscard(player: player, state: state)
        case .roundEnded, .gameEnded:
            return .draw(playerId: playerId, source: .stock)
        }
    }

    // MARK: - Draw phase

    /// Take the discard when it's a wild card (joker or live 2). Otherwise
    /// draw from stock. We do NOT try to detect "the discard would complete
    /// a meld I'm missing" here — that's the next-iteration heuristic.
    static func chooseDraw(player: Player, state: GameState) -> TurnEngine.Action {
        if let top = state.discard.last, top.isWild {
            return .draw(playerId: player.id, source: .discard)
        }
        return .draw(playerId: player.id, source: .stock)
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
        // 2. Already down — try to lay off a hand card onto an existing meld
        //    (but not on the same turn we went down).
        if player.hasGoneDownThisRound, !player.laidDownThisTurn,
           let action = findLayOff(playerId: player.id,
                                   hand: player.hand,
                                   melds: state.melds) {
            return action
        }
        // 3. Discard.
        return .discard(playerId: player.id,
                        card: chooseDiscard(hand: player.hand,
                                            player: player,
                                            state: state))
    }

    // MARK: - Discard selection

    /// Pick the card to throw away this turn. Priorities:
    ///  1. Never discard a card that fits an existing meld we could lay off.
    ///  2. Prefer highest-point non-wild card so the penalty tab keeps shrinking.
    ///  3. Never discard a wild if any non-wild is available.
    static func chooseDiscard(hand: [Card],
                              player: Player,
                              state: GameState) -> Card {
        precondition(!hand.isEmpty, "CPU asked to discard from an empty hand")
        // Filter out cards that could be laid off (only relevant post-godown).
        let uselessForLayoff: (Card) -> Bool = { card in
            if !player.hasGoneDownThisRound { return true }
            return !CPUPlayer.canLayOff(card: card, on: state.melds)
        }
        let candidates = hand.filter(uselessForLayoff)
        let pool = candidates.isEmpty ? hand : candidates
        let nonWilds = pool.filter { !$0.isWild }
        if let pick = nonWilds.max(by: { $0.points < $1.points }) {
            return pick
        }
        // All wilds in the pool — pick the lowest-penalty one to keep options open.
        return pool.min(by: { $0.points < $1.points }) ?? hand[0]
    }

    // MARK: - Lay-off search

    /// If any hand card can extend an existing meld (prepend or append),
    /// return the corresponding action. Prefers extending at the end.
    static func findLayOff(playerId: UUID,
                           hand: [Card],
                           melds: [Meld]) -> TurnEngine.Action? {
        for meld in melds {
            for card in hand {
                // Try appending first.
                if canAdd(card, to: meld, atStart: false) {
                    return .addToMeld(playerId: playerId, meldId: meld.id,
                                      cardsAtStart: [], cardsAtEnd: [card])
                }
                // Then prepending.
                if canAdd(card, to: meld, atStart: true) {
                    return .addToMeld(playerId: playerId, meldId: meld.id,
                                      cardsAtStart: [card], cardsAtEnd: [])
                }
            }
        }
        return nil
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
        let wilds = hand.filter { $0.isWild }
        var byRank: [Rank: [Card]] = [:]
        for c in hand where !c.isWild {
            if let r = c.rank { byRank[r, default: []].append(c) }
        }
        let maxWilds = RulesConfig.maxWilds(inMeldOfSize: size)
        var candidates: [[Card]] = []
        for (_, naturals) in byRank {
            var firstCardBySuit: [Suit: Card] = [:]
            for natural in naturals {
                guard let suit = natural.suit, firstCardBySuit[suit] == nil else {
                    continue
                }
                firstCardBySuit[suit] = natural
            }
            let distinctSuitNaturals = Suit.allCases.compactMap {
                firstCardBySuit[$0]
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
        return candidates.sorted { a, b in
            a.filter(\.isWild).count < b.filter(\.isWild).count
        }
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
        var bySuit: [Suit: [Rank: [Card]]] = [:]
        for c in hand where !c.isWild {
            if let s = c.suit, let r = c.rank {
                bySuit[s, default: [:]][r, default: []].append(c)
            }
        }
        let maxWilds = RulesConfig.maxWilds(inMeldOfSize: size)
        let highestStart = Rank.king.rawValue - size + 1
        guard highestStart >= Rank.ace.rawValue else { return [] }

        var candidates: [[Card]] = []
        for (_, byRank) in bySuit {
            for startRaw in Rank.ace.rawValue...highestStart {
                var picked: [Card] = []
                var wildsUsed = 0
                var ok = true
                for i in 0..<size {
                    guard let neededRank = Rank(rawValue: startRaw + i) else {
                        ok = false; break
                    }
                    if let match = byRank[neededRank]?.first {
                        picked.append(match)
                    } else if wildsUsed < wilds.count && wildsUsed < maxWilds {
                        picked.append(wilds[wildsUsed])
                        wildsUsed += 1
                    } else {
                        ok = false; break
                    }
                }
                if ok && picked.count == size {
                    candidates.append(picked)
                }
            }
        }
        return candidates.sorted { a, b in
            a.filter(\.isWild).count < b.filter(\.isWild).count
        }
    }
}
