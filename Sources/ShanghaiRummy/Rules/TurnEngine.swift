import Foundation

/// State machine that mutates `GameState` in response to player actions.
///
/// Design: every mutation is a pure function `apply(_:to:)`. This keeps the
/// engine trivially unit-testable and lets us replay a match by re-applying
/// its action log — useful for spectator mode and bug reports.
public enum TurnEngine {

    // MARK: - Actions

    public enum Action: Codable, Equatable, Sendable {
        case draw(playerId: UUID, source: DrawSource)
        case goDown(playerId: UUID, contract: [[Card]])
        case addToMeld(playerId: UUID, meldId: UUID, cardsAtStart: [Card], cardsAtEnd: [Card])
        case redeemWild(playerId: UUID, meldId: UUID, wildCardId: UUID, replacementCard: Card)
        case discard(playerId: UUID, card: Card)
        case requestBuy(playerId: UUID)
        case cancelBuyRequest(playerId: UUID)
        case advanceHand(playerId: UUID)

        public var actorPlayerId: UUID {
            switch self {
            case .draw(let playerId, _),
                 .goDown(let playerId, _),
                 .addToMeld(let playerId, _, _, _),
                 .redeemWild(let playerId, _, _, _),
                 .discard(let playerId, _),
                 .requestBuy(let playerId),
                 .cancelBuyRequest(let playerId),
                 .advanceHand(let playerId):
                return playerId
            }
        }
    }

    public enum DrawSource: String, Codable, Equatable, Sendable {
        case stock, discard
    }

    // MARK: - Errors

    public enum ActionError: Error, Equatable, CustomStringConvertible {
        case notYourTurn
        case wrongPhase(GameState.Phase)
        case alreadyWentDown
        case notYetWentDown
        case cardNotInHand
        case meldNotFound
        case emptyStock
        case emptyDiscard
        case invalidContract(reason: String)
        case invalidMeldValidation(MeldValidator.ValidationError)
        case invalidAddition(MeldValidator.ValidationError)
        case buysExhausted
        case buyNotAllowedByTurnPlayer
        case buyAlreadyRequested
        case buyNotRequested
        case gameOver
        case cannotActOnGoDownTurn
        case notASequence
        case notAWildCard
        case invalidRedemption(reason: String)

        public var description: String {
            switch self {
            case .notYourTurn: return "It is not this player's turn"
            case .wrongPhase(let p): return "Wrong phase for this action (\(p.rawValue))"
            case .alreadyWentDown: return "Player has already gone down this round"
            case .notYetWentDown: return "Player must go down before adding to melds"
            case .cardNotInHand: return "Card not in player's hand"
            case .meldNotFound: return "Meld not found"
            case .emptyStock: return "Stock is empty"
            case .emptyDiscard: return "Discard pile is empty"
            case .invalidContract(let r): return "Invalid contract: \(r)"
            case .invalidMeldValidation(let e): return "Invalid meld: \(e)"
            case .invalidAddition(let e): return "Invalid meld addition: \(e)"
            case .buysExhausted: return "Player has used all buys this round"
            case .buyNotAllowedByTurnPlayer: return "Turn player has first refusal on the discard"
            case .buyAlreadyRequested: return "Player has already requested this discard"
            case .buyNotRequested: return "Player has not requested this discard"
            case .gameOver: return "Game is over"
            case .cannotActOnGoDownTurn: return "Cannot add to or redeem from other melds on the turn you go down"
            case .notASequence: return "Wild redemption is only allowed on sequences"
            case .notAWildCard: return "Target card is not currently a wild"
            case .invalidRedemption(let r): return "Invalid wild redemption: \(r)"
            }
        }
    }

    // MARK: - Apply

    public static func apply(_ action: Action, to state: GameState) -> Result<GameState, ActionError> {
        guard state.phase != .gameEnded else { return .failure(.gameOver) }
        switch action {
        case .draw(let pid, let source):
            return draw(playerId: pid, source: source, state: state)
        case .goDown(let pid, let contract):
            return goDown(playerId: pid, contract: contract, state: state)
        case .addToMeld(let pid, let meldId, let atStart, let atEnd):
            return addToMeld(playerId: pid, meldId: meldId,
                             cardsAtStart: atStart, cardsAtEnd: atEnd, state: state)
        case .redeemWild(let pid, let meldId, let wildId, let replacement):
            return redeemWild(playerId: pid, meldId: meldId,
                              wildCardId: wildId, replacementCard: replacement, state: state)
        case .discard(let pid, let card):
            return discard(playerId: pid, card: card, state: state)
        case .requestBuy(let pid):
            return requestBuy(playerId: pid, state: state)
        case .cancelBuyRequest(let pid):
            return cancelBuyRequest(playerId: pid, state: state)
        case .advanceHand(let pid):
            guard state.currentPlayerId == pid else { return .failure(.notYourTurn) }
            return advanceHand(state: state)
        }
    }

    // MARK: - Hand lifecycle

    /// Advance from `.roundEnded` to either the next hand or `.gameEnded`.
    ///
    /// Independent-contract variant:
    /// 1. Add end-of-hand penalty points to every player's `totalScore`.
    /// 2. Every player who went down THIS HAND advances their `currentLevel`.
    /// 3. If any player has `currentLevel > RulesConfig.maxLevel`, the game ends;
    ///    winner = that player. If multiple players finished level 10 in the
    ///    same hand, tiebreaker is lowest `totalScore`.
    /// 4. Otherwise, deal a new hand via `GameFactory.newHand`.
    public static func advanceHand(state: GameState) -> Result<GameState, ActionError> {
        guard state.phase == .roundEnded else { return .failure(.wrongPhase(state.phase)) }

        // 1. Score.
        let wentOutId = state.players.first {
            $0.hand.isEmpty && $0.hasGoneDownThisRound
        }?.id
        let handScores = Scoring.endOfRound(players: state.players,
                                            wentOutPlayerId: wentOutId)
        var s = state
        for i in s.players.indices {
            s.players[i].totalScore += handScores[s.players[i].id] ?? 0
        }

        // 2. Advance levels for players who went down this hand.
        for i in s.players.indices where s.players[i].hasGoneDownThisRound {
            s.players[i].currentLevel += 1
        }

        // 3. Check win condition.
        let finishers = s.players.filter { $0.currentLevel > RulesConfig.maxLevel }
        if !finishers.isEmpty {
            let minScore = finishers.map(\.totalScore).min() ?? 0
            let winners = finishers.filter { $0.totalScore == minScore }
            s.gameWinnerIds = winners.map(\.id)
            s.phase = .gameEnded
            return .success(s)
        }

        // 4. Deal next hand.
        return .success(GameFactory.newHand(from: s))
    }

    // MARK: - Handlers

    private static func draw(playerId: UUID, source: DrawSource, state: GameState) -> Result<GameState, ActionError> {
        guard state.currentPlayerId == playerId else { return .failure(.notYourTurn) }
        guard state.phase == .awaitingDraw else { return .failure(.wrongPhase(state.phase)) }
        var s = state
        switch source {
        case .stock:
            if s.prioritizedBuyRequesterId != nil {
                guard s.stock.count > RulesConfig.penaltyCardsOnBuy else {
                    return .failure(.emptyStock)
                }
                resolvePrioritizedBuy(state: &s)
            }
            guard let c = s.stock.popLast() else { return .failure(.emptyStock) }
            s.players[s.currentTurnIndex].hand.append(c)
        case .discard:
            guard let c = s.discard.popLast() else { return .failure(.emptyDiscard) }
            s.players[s.currentTurnIndex].hand.append(c)
        }
        s.buyRequestPlayerIds.removeAll()
        s.phase = .awaitingMeldOrDiscard
        return .success(s)
    }

    private static func goDown(playerId: UUID, contract: [[Card]], state: GameState) -> Result<GameState, ActionError> {
        guard state.currentPlayerId == playerId else { return .failure(.notYourTurn) }
        guard state.phase == .awaitingMeldOrDiscard else { return .failure(.wrongPhase(state.phase)) }
        var s = state
        let player = s.players[s.currentTurnIndex]
        guard !player.hasGoneDownThisRound else { return .failure(.alreadyWentDown) }
        guard let expected = s.currentContract else {
            return .failure(.invalidContract(reason: "No contract for round \(s.currentRound)"))
        }

        // 1. Every proposed meld must be individually valid.
        var validatedKinds: [Meld.Kind] = []
        for meldCards in contract {
            switch MeldValidator.validate(meldCards) {
            case .failure(let e): return .failure(.invalidMeldValidation(e))
            case .success(let kind): validatedKinds.append(kind)
            }
        }

        // 2. Contract shape must match the round's requirement (kind + exact size).
        if !contractShapeMatches(proposed: contract, kinds: validatedKinds, required: expected) {
            return .failure(.invalidContract(reason: "Round \(s.currentRound) requires \(expected.displayName)"))
        }

        // 3. All contract cards must be in the player's hand.
        let allCards = contract.flatMap { $0 }
        guard removeFromHand(allCards, playerIndex: s.currentTurnIndex, state: &s) else {
            return .failure(.cardNotInHand)
        }

        // 4. Add melds to the table.
        for (meldCards, kind) in zip(contract, validatedKinds) {
            s.melds.append(Meld(kind: kind, cards: meldCards, ownerId: playerId))
        }
        s.players[s.currentTurnIndex].hasGoneDownThisRound = true
        // Enforced by `laidDownThisTurn`: no `addToMeld` or `redeemWild` on the
        // same turn as `goDown`. The flag is cleared when the turn advances
        // in `discard`.
        s.players[s.currentTurnIndex].laidDownThisTurn = true
        return .success(s)
    }

    private static func addToMeld(
        playerId: UUID, meldId: UUID,
        cardsAtStart: [Card], cardsAtEnd: [Card],
        state: GameState
    ) -> Result<GameState, ActionError> {
        guard state.currentPlayerId == playerId else { return .failure(.notYourTurn) }
        guard state.phase == .awaitingMeldOrDiscard else { return .failure(.wrongPhase(state.phase)) }
        var s = state
        let player = s.players[s.currentTurnIndex]
        guard player.hasGoneDownThisRound else { return .failure(.notYetWentDown) }
        if player.laidDownThisTurn { return .failure(.cannotActOnGoDownTurn) }
        guard let idx = s.melds.firstIndex(where: { $0.id == meldId }) else {
            return .failure(.meldNotFound)
        }

        let added = cardsAtStart + cardsAtEnd
        switch MeldValidator.validateAddition(
            addingCards: added,
            atStart: cardsAtStart,
            atEnd: cardsAtEnd,
            to: s.melds[idx]
        ) {
        case .failure(let e): return .failure(.invalidAddition(e))
        case .success(let newCards):
            guard removeFromHand(added, playerIndex: s.currentTurnIndex, state: &s) else {
                return .failure(.cardNotInHand)
            }
            s.melds[idx].cards = newCards
            return .success(s)
        }
    }

    /// Redeem a wild (joker or live wild 2) from a sequence meld by producing
    /// the exact positional card it stands in for. See docs/rules.md.
    private static func redeemWild(
        playerId: UUID, meldId: UUID,
        wildCardId: UUID, replacementCard: Card,
        state: GameState
    ) -> Result<GameState, ActionError> {
        guard state.currentPlayerId == playerId else { return .failure(.notYourTurn) }
        guard state.phase == .awaitingMeldOrDiscard else { return .failure(.wrongPhase(state.phase)) }
        var s = state
        let player = s.players[s.currentTurnIndex]
        guard player.hasGoneDownThisRound else { return .failure(.notYetWentDown) }
        if player.laidDownThisTurn { return .failure(.cannotActOnGoDownTurn) }

        guard let meldIdx = s.melds.firstIndex(where: { $0.id == meldId }) else {
            return .failure(.meldNotFound)
        }
        guard s.melds[meldIdx].kind == .sequence else {
            return .failure(.notASequence)
        }
        guard let wildIdx = s.melds[meldIdx].cards.firstIndex(where: { $0.id == wildCardId }) else {
            return .failure(.invalidRedemption(reason: "Wild not found in meld"))
        }
        let wildCard = s.melds[meldIdx].cards[wildIdx]
        guard wildCard.isWild else { return .failure(.notAWildCard) }

        // Replacement must not itself be a wild — otherwise nothing is redeemed.
        if replacementCard.isWild {
            return .failure(.invalidRedemption(reason: "Replacement card must not be a wild"))
        }
        // Player must have the exact replacement card in hand.
        guard s.players[s.currentTurnIndex].hand.contains(where: { $0.id == replacementCard.id }) else {
            return .failure(.cardNotInHand)
        }

        // Verify the replacement is positionally exact: swap and re-validate as a
        // sequence. If the sequence stays legal AND wild count decreases by 1, the
        // exact-positional-card rule is satisfied.
        var proposed = s.melds[meldIdx].cards
        proposed[wildIdx] = replacementCard
        let wildsBefore = s.melds[meldIdx].cards.filter(\.isWild).count
        let wildsAfter = proposed.filter(\.isWild).count
        guard wildsAfter == wildsBefore - 1 else {
            return .failure(.invalidRedemption(reason: "Replacement does not reduce wild count by one"))
        }
        switch MeldValidator.validateSequence(proposed) {
        case .failure(let e):
            return .failure(.invalidRedemption(reason: "Result would be an illegal sequence (\(e))"))
        case .success:
            break
        }

        // Perform swap: replacement goes into meld, wild goes into hand.
        guard removeFromHand([replacementCard], playerIndex: s.currentTurnIndex, state: &s) else {
            return .failure(.cardNotInHand)
        }
        s.melds[meldIdx].cards = proposed
        s.players[s.currentTurnIndex].hand.append(wildCard)
        return .success(s)
    }

    private static func discard(playerId: UUID, card: Card, state: GameState) -> Result<GameState, ActionError> {
        guard state.currentPlayerId == playerId else { return .failure(.notYourTurn) }
        guard state.phase == .awaitingMeldOrDiscard else { return .failure(.wrongPhase(state.phase)) }
        var s = state
        guard removeFromHand([card], playerIndex: s.currentTurnIndex, state: &s) else {
            return .failure(.cardNotInHand)
        }
        // A discarded 2 dies permanently for the round. The dead status
        // persists on the card so whoever later draws or buys it inherits it.
        s.discard.append(card.markedDeadIfTwo())

        // Round ends immediately if this player goes out (hand empty AND has gone down).
        if s.players[s.currentTurnIndex].hand.isEmpty
            && s.players[s.currentTurnIndex].hasGoneDownThisRound {
            s.phase = .roundEnded
            return .success(s)
        }

        // Clear per-turn go-down flag before advancing.
        s.players[s.currentTurnIndex].laidDownThisTurn = false
        // Advance to next player.
        s.currentTurnIndex = (s.currentTurnIndex + 1) % s.players.count
        s.phase = .awaitingDraw
        return .success(s)
    }

    private static func requestBuy(
        playerId: UUID,
        state: GameState
    ) -> Result<GameState, ActionError> {
        guard state.phase == .awaitingDraw else { return .failure(.wrongPhase(state.phase)) }
        if state.currentPlayerId == playerId {
            return .failure(.buyNotAllowedByTurnPlayer) // turn player draws, doesn't buy
        }
        guard let buyerIdx = state.players.firstIndex(where: { $0.id == playerId }) else {
            return .failure(.notYourTurn)
        }
        guard state.players[buyerIdx].buysUsedThisRound < RulesConfig.maxBuysPerRound else {
            return .failure(.buysExhausted)
        }
        guard !state.discard.isEmpty else { return .failure(.emptyDiscard) }
        guard !state.buyRequestPlayerIds.contains(playerId) else {
            return .failure(.buyAlreadyRequested)
        }
        var s = state
        s.buyRequestPlayerIds.append(playerId)
        return .success(s)
    }

    private static func cancelBuyRequest(
        playerId: UUID,
        state: GameState
    ) -> Result<GameState, ActionError> {
        guard state.phase == .awaitingDraw else { return .failure(.wrongPhase(state.phase)) }
        guard let requestIndex = state.buyRequestPlayerIds.firstIndex(of: playerId) else {
            return .failure(.buyNotRequested)
        }
        var s = state
        s.buyRequestPlayerIds.remove(at: requestIndex)
        return .success(s)
    }

    private static func resolvePrioritizedBuy(state: inout GameState) {
        guard let buyerId = state.prioritizedBuyRequesterId,
              let buyerIndex = state.players.firstIndex(where: { $0.id == buyerId }),
              let bought = state.discard.popLast() else {
            return
        }
        state.players[buyerIndex].hand.append(bought)
        for _ in 0..<RulesConfig.penaltyCardsOnBuy {
            guard let penalty = state.stock.popLast() else { break }
            state.players[buyerIndex].hand.append(penalty)
        }
        state.players[buyerIndex].buysUsedThisRound += 1
    }

    // MARK: - Helpers

    /// Removes exactly the cards in `cards` from a player's hand. Returns true
    /// only if every card was found and removed.
    private static func removeFromHand(_ cards: [Card], playerIndex: Int, state: inout GameState) -> Bool {
        var hand = state.players[playerIndex].hand
        for target in cards {
            guard let idx = hand.firstIndex(of: target) else { return false }
            hand.remove(at: idx)
        }
        state.players[playerIndex].hand = hand
        return true
    }

    /// Check that a proposed contract's melds match the round's required shape.
    /// Compares as a multiset of (kind, size) pairs.
    private static func contractShapeMatches(
        proposed: [[Card]],
        kinds: [Meld.Kind],
        required: Contract
    ) -> Bool {
        let proposedShape = zip(proposed, kinds).map { ($1, $0.count) }
        let requiredShape: [(Meld.Kind, Int)] = required.components.map {
            switch $0 {
            case .triplet(let n): return (.triplet, n)
            case .sequence(let n): return (.sequence, n)
            }
        }
        // Compare as sorted tuples.
        let normalize: ([(Meld.Kind, Int)]) -> [String] = { shape in
            shape.map { "\($0.0.rawValue)-\($0.1)" }.sorted()
        }
        return normalize(proposedShape) == normalize(requiredShape)
    }
}
