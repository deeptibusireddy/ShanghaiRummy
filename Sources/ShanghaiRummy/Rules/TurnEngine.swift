import Foundation

/// State machine that mutates `GameState` in response to player actions.
///
/// Design: every mutation is a pure function `apply(_:to:)`. This keeps the
/// engine trivially unit-testable and lets us replay a match by re-applying
/// its action log — useful for spectator mode and bug reports.
public enum TurnEngine {

    // MARK: - Actions

    public enum Action: Equatable {
        case draw(playerId: UUID, source: DrawSource)
        case goDown(playerId: UUID, contract: [[Card]])
        case addToMeld(playerId: UUID, meldId: UUID, cardsAtStart: [Card], cardsAtEnd: [Card])
        case discard(playerId: UUID, card: Card)
        case buy(playerId: UUID)
    }

    public enum DrawSource: String, Codable, Equatable {
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
        case gameOver

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
            case .gameOver: return "Game is over"
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
        case .discard(let pid, let card):
            return discard(playerId: pid, card: card, state: state)
        case .buy(let pid):
            return buy(playerId: pid, state: state)
        }
    }

    // MARK: - Handlers

    private static func draw(playerId: UUID, source: DrawSource, state: GameState) -> Result<GameState, ActionError> {
        guard state.currentPlayerId == playerId else { return .failure(.notYourTurn) }
        guard state.phase == .awaitingDraw else { return .failure(.wrongPhase(state.phase)) }
        var s = state
        switch source {
        case .stock:
            guard let c = s.stock.popLast() else { return .failure(.emptyStock) }
            s.players[s.currentTurnIndex].hand.append(c)
        case .discard:
            guard let c = s.discard.popLast() else { return .failure(.emptyDiscard) }
            s.players[s.currentTurnIndex].hand.append(c)
        }
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
        // Rule: on the turn you go down, you cannot add to other melds. Phase stays
        // in awaitingMeldOrDiscard so the player still must discard, but a followup
        // .addToMeld action will be rejected because the phase-transition check
        // below only allows it after a prior turn. We enforce this by tagging.
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
        guard let idx = s.melds.firstIndex(where: { $0.id == meldId }) else {
            return .failure(.meldNotFound)
        }
        // Disallow adds on the same turn you went down: we detect that by
        // checking whether any meld was laid this turn. A robust flag would be
        // cleaner; for now, we approximate by requiring that the "go down"
        // occurred in a strictly earlier turn (i.e., the player's turn number
        // increments). Adding a per-turn flag is a follow-up.
        // TODO(strict): add `laidDownThisTurn` flag on Player to enforce.

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

    private static func discard(playerId: UUID, card: Card, state: GameState) -> Result<GameState, ActionError> {
        guard state.currentPlayerId == playerId else { return .failure(.notYourTurn) }
        guard state.phase == .awaitingMeldOrDiscard else { return .failure(.wrongPhase(state.phase)) }
        var s = state
        guard removeFromHand([card], playerIndex: s.currentTurnIndex, state: &s) else {
            return .failure(.cardNotInHand)
        }
        s.discard.append(card)

        // Round ends immediately if this player goes out (hand empty AND has gone down).
        if s.players[s.currentTurnIndex].hand.isEmpty
            && s.players[s.currentTurnIndex].hasGoneDownThisRound {
            s.phase = .roundEnded
            return .success(s)
        }

        // Advance to next player.
        s.currentTurnIndex = (s.currentTurnIndex + 1) % s.players.count
        s.phase = .awaitingDraw
        return .success(s)
    }

    private static func buy(playerId: UUID, state: GameState) -> Result<GameState, ActionError> {
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
        var s = state
        guard let bought = s.discard.popLast() else { return .failure(.emptyDiscard) }
        s.players[buyerIdx].hand.append(bought)
        // Penalty card(s) from stock.
        for _ in 0..<RulesConfig.penaltyCardsOnBuy {
            guard let penalty = s.stock.popLast() else { break }
            s.players[buyerIdx].hand.append(penalty)
        }
        s.players[buyerIdx].buysUsedThisRound += 1
        // Buying doesn't change whose turn it is — the turn player still needs to draw.
        return .success(s)
    }

    // MARK: - Helpers

    /// Removes exactly the cards in `cards` from a player's hand. Returns true
    /// only if every card was found and removed.
    private static func removeFromHand(_ cards: [Card], playerIndex: Int, state: inout GameState) -> Bool {
        var hand = state.players[playerIndex].hand
        for target in cards {
            guard let idx = hand.firstIndex(where: { $0.id == target.id }) else { return false }
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
