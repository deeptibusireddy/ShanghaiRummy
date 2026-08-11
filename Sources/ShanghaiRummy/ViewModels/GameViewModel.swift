import Foundation
import Combine

/// Owns the current `GameState` for the UI and forwards user actions to
/// `TurnEngine`. Pure rules + persistence live in the engine; this class only
/// glues them to SwiftUI/SpriteKit.
///
/// Hot-seat mode applies actions locally. Online mode sends actions to the
/// authoritative Game Center host and publishes the returned snapshots.
@MainActor
public final class GameViewModel: ObservableObject {

    // MARK: - Published state

    @Published public private(set) var state: GameState
    /// The most recent error a user-facing action produced, if any. Cleared on
    /// the next successful action.
    @Published public private(set) var lastError: String?
    /// True when the outgoing player has just discarded and we're waiting for
    /// the next player to take the device (hot-seat privacy interstitial).
    @Published public var isBetweenTurns: Bool = false
    /// Cards the current player has moved to the meld-staging tray. Used by
    /// the UI to render staged cards separately from the hand fan and to
    /// preview meld legality before committing (M2d-b).
    @Published public private(set) var stagedCardIds: Set<UUID> = []

    /// IDs of players controlled by the CPU practice bot (M1e). Empty in
    /// hot-seat / GameKit modes.
    @Published public var cpuPlayerIds: Set<UUID> = []
    @Published public private(set) var isSubmittingOnlineAction = false

    /// Non-nil in online mode. The local hand remains at the bottom even while
    /// another participant owns the turn.
    public let localPlayerId: UUID?

    /// Re-entrancy guard for the CPU auto-play loop (see `dispatch`).
    private var isRunningCPUTurns: Bool = false
    private var onlineActionSubmitter: ((TurnEngine.Action) -> Bool)?

    // MARK: - Init

    public init(state: GameState, localPlayerId: UUID? = nil) {
        self.state = state
        self.localPlayerId = localPlayerId
    }

    /// Convenience factory: build a fresh match from names.
    public static func newHotSeat(playerNames: [String], seed: UInt64? = nil) -> GameViewModel {
        let s = seed ?? UInt64.random(in: 0...UInt64.max)
        return GameViewModel(state: GameFactory.newGame(playerNames: playerNames, seed: s))
    }

    // MARK: - Derived helpers used by views

    public var turnPlayer: Player { state.players[state.currentTurnIndex] }
    public var currentPlayer: Player {
        guard let localPlayerId,
              let local = state.players.first(where: { $0.id == localPlayerId }) else {
            return turnPlayer
        }
        return local
    }
    public var currentPlayerName: String { turnPlayer.name }
    public var displayedPlayerIndex: Int {
        guard let localPlayerId,
              let index = state.players.firstIndex(where: { $0.id == localPlayerId }) else {
            return state.currentTurnIndex
        }
        return index
    }
    public var isOnlineGame: Bool { localPlayerId != nil }
    public var isLocalPlayersTurn: Bool {
        localPlayerId == nil || state.currentPlayerId == localPlayerId
    }
    public var currentContractDescription: String {
        state.contract(forPlayer: currentPlayer.id)?.displayName ?? "—"
    }
    public var canDrawFromDiscard: Bool {
        isLocalPlayersTurn && state.phase == .awaitingDraw && !state.discard.isEmpty
    }
    public var canDrawFromStock: Bool {
        isLocalPlayersTurn && state.phase == .awaitingDraw && !state.stock.isEmpty
    }
    public var hasRequestedBuy: Bool {
        state.buyRequestPlayerIds.contains(currentPlayer.id)
    }
    public var canRequestBuy: Bool {
        isOnlineGame
            && !isLocalPlayersTurn
            && state.phase == .awaitingDraw
            && !state.discard.isEmpty
            && currentPlayer.buysUsedThisRound < RulesConfig.maxBuysPerRound
            && !hasRequestedBuy
    }
    public var prioritizedBuyRequesterName: String? {
        guard let id = state.prioritizedBuyRequesterId else { return nil }
        return state.players.first(where: { $0.id == id })?.name
    }
    public var canAdvanceHand: Bool {
        state.phase == .roundEnded && isLocalPlayersTurn
    }

    // MARK: - Action dispatch

    /// Central action dispatcher. Applies the action to the engine, publishes
    /// the new state or the error message, and returns `true` on success.
    @discardableResult
    public func dispatch(_ action: TurnEngine.Action) -> Bool {
        if let onlineActionSubmitter {
            guard !isSubmittingOnlineAction else { return false }
            if case .failure(let error) = TurnEngine.apply(action, to: state) {
                lastError = error.description
                return false
            }
            isSubmittingOnlineAction = true
            let submitted = onlineActionSubmitter(action)
            if !submitted {
                isSubmittingOnlineAction = false
            }
            return submitted
        }
        return applyAuthoritative(action)
    }

    @discardableResult
    public func applyAuthoritative(_ action: TurnEngine.Action) -> Bool {
        let outgoingId = state.currentPlayerId
        switch TurnEngine.apply(action, to: state) {
        case .success(let newState):
            let didAdvanceTurn =
                newState.currentTurnIndex != state.currentTurnIndex
                && newState.phase == .awaitingDraw
            state = newState
            lastError = nil
            if didAdvanceTurn {
                let incomingId = newState.currentPlayerId
                let outgoingIsCPU = cpuPlayerIds.contains(outgoingId)
                let incomingIsCPU = cpuPlayerIds.contains(incomingId)
                // Only show the pass-and-play interstitial when handing off
                // between two humans. Bot ↔ human and bot ↔ bot skip it.
                isBetweenTurns = !isOnlineGame
                    && !(outgoingIsCPU || incomingIsCPU)
                stagedCardIds.removeAll()
                contractDraft.removeAll()
                // Auto-pump the CPU's turn(s) so the UI never has to wait on
                // a bot. Re-entrancy guard prevents recursion from the loop.
                if incomingIsCPU && !isRunningCPUTurns {
                    runAllCPUTurns()
                }
            }
            return true
        case .failure(let err):
            lastError = err.description
            return false
        }
    }

    public func configureOnlineActionSubmitter(
        _ submitter: @escaping (TurnEngine.Action) -> Bool
    ) {
        onlineActionSubmitter = submitter
    }

    public func receiveAuthoritativeState(
        _ newState: GameState,
        completesPendingAction: Bool = true
    ) {
        state = newState
        lastError = nil
        if completesPendingAction {
            isSubmittingOnlineAction = false
        }
        isBetweenTurns = false
        reconcileDraftWithAuthoritativeHand()
    }

    public func rejectOnlineAction(message: String, state newState: GameState) {
        state = newState
        lastError = message
        isSubmittingOnlineAction = false
        isBetweenTurns = false
        reconcileDraftWithAuthoritativeHand()
    }

    public func reportOnlineIssue(_ message: String) {
        lastError = message
    }

    private func reconcileDraftWithAuthoritativeHand() {
        guard isLocalPlayersTurn,
              state.phase == .awaitingMeldOrDiscard else {
            stagedCardIds.removeAll()
            contractDraft.removeAll()
            return
        }
        let handIds = Set(currentPlayer.hand.map(\.id))
        stagedCardIds.formIntersection(handIds)
        contractDraft.removeAll { meld in
            !meld.allSatisfy { handIds.contains($0.id) }
        }
    }

    // Convenience wrappers for common actions.
    public func drawFromStock() { dispatch(.draw(playerId: currentPlayer.id, source: .stock)) }
    public func drawFromDiscard() { dispatch(.draw(playerId: currentPlayer.id, source: .discard)) }
    public func discard(_ card: Card) { dispatch(.discard(playerId: currentPlayer.id, card: card)) }
    public func goDown(contract: [[Card]]) {
        dispatch(.goDown(playerId: currentPlayer.id, contract: contract))
    }
    public func addToMeld(_ meldId: UUID, atStart: [Card], atEnd: [Card]) {
        dispatch(.addToMeld(playerId: currentPlayer.id, meldId: meldId,
                            cardsAtStart: atStart, cardsAtEnd: atEnd))
    }
    public func redeemWild(meldId: UUID, wildCardId: UUID, replacementCard: Card) {
        dispatch(.redeemWild(playerId: currentPlayer.id, meldId: meldId,
                             wildCardId: wildCardId, replacementCard: replacementCard))
    }
    public func requestBuy(as playerId: UUID) {
        dispatch(.requestBuy(playerId: playerId))
    }
    public func cancelBuyRequest(as playerId: UUID) {
        dispatch(.cancelBuyRequest(playerId: playerId))
    }
    public func toggleLocalBuyRequest() {
        if hasRequestedBuy {
            cancelBuyRequest(as: currentPlayer.id)
        } else if canRequestBuy {
            requestBuy(as: currentPlayer.id)
        }
    }

    /// Trigger end-of-hand accounting: score, advance levels, deal next hand.
    /// Fails silently (setting `lastError`) if the game isn't in `.roundEnded`.
    public func advanceHand() {
        dispatch(.advanceHand(playerId: currentPlayer.id))
    }

    // MARK: - Derived helpers for hand/game lifecycle

    public var isHandOver: Bool { state.phase == .roundEnded }
    public var isGameOver: Bool { state.phase == .gameEnded }
    public var winnerNames: [String] {
        state.gameWinnerIds.compactMap { id in
            state.players.first(where: { $0.id == id })?.name
        }
    }

    /// The next player has acknowledged the pass-and-play prompt.
    public func acknowledgeTurnPassed() { isBetweenTurns = false }

    // MARK: - End-of-hand summary (M2e)

    /// One row of the round-over scoreboard.
    public struct HandSummaryRow: Identifiable, Equatable {
        public let id: UUID          // player id
        public let name: String
        /// Penalty added this round (0 for the player who went out).
        public let roundPoints: Int
        /// Cumulative total AFTER this round's points are added.
        public let totalAfter: Int
        /// The contract level this player is on FOR THE ROUND JUST PLAYED.
        public let currentLevel: Int
        /// True if this player will advance a level when the next hand is dealt
        /// (i.e., they went down this hand).
        public let didLevelUp: Bool
        /// True if this player emptied their hand this round.
        public let wentOut: Bool
    }

    /// Round-over scoreboard rows sorted by cumulative total ascending.
    /// Non-nil only while `phase == .roundEnded`. Computed on demand.
    public var pendingHandSummary: [HandSummaryRow]? {
        guard state.phase == .roundEnded else { return nil }
        let wentOutId = state.players.first {
            $0.hand.isEmpty && $0.hasGoneDownThisRound
        }?.id
        let scores = Scoring.endOfRound(players: state.players,
                                        wentOutPlayerId: wentOutId)
        let rows = state.players.map { p -> HandSummaryRow in
            let round = scores[p.id] ?? 0
            return HandSummaryRow(
                id: p.id,
                name: p.name,
                roundPoints: round,
                totalAfter: p.totalScore + round,
                currentLevel: p.currentLevel,
                didLevelUp: p.hasGoneDownThisRound,
                wentOut: p.id == wentOutId
            )
        }
        return rows.sorted { $0.totalAfter < $1.totalAfter }
    }

    /// One row of the final scoreboard.
    public struct FinalScoreRow: Identifiable, Equatable {
        public let id: UUID
        public let name: String
        public let totalScore: Int
        public let currentLevel: Int
        public let isWinner: Bool
    }

    /// Final scoreboard, non-nil only while `phase == .gameEnded`. Sorted
    /// by score ascending (lowest = winner in Shanghai Rummy).
    public var finalScoreboard: [FinalScoreRow]? {
        guard state.phase == .gameEnded else { return nil }
        let winners = Set(state.gameWinnerIds)
        let rows = state.players.map { p in
            FinalScoreRow(
                id: p.id, name: p.name,
                totalScore: p.totalScore,
                currentLevel: p.currentLevel,
                isWinner: winners.contains(p.id)
            )
        }
        return rows.sorted { $0.totalScore < $1.totalScore }
    }

    // MARK: - Hand display order (M2f)

    /// Per-player, UI-only ordering of hand card IDs so the human can
    /// arrange their fan for readability. Cleared and rebuilt whenever a
    /// hand contains an ID not yet tracked (newly drawn card is appended);
    /// missing IDs (played cards) are pruned lazily on access.
    ///
    /// Keyed by player ID so multiple players in hot-seat mode keep their
    /// own preferred order across turns.
    @Published private var handOrderByPlayer: [UUID: [UUID]] = [:]

    /// Current player's hand in the user's chosen display order. New cards
    /// (drawn from stock/discard) show up at the right end. Played cards
    /// vanish from the fan.
    public var orderedHand: [Card] {
        let hand = currentPlayer.hand
        let ids = Set(hand.map { $0.id })
        var order = (handOrderByPlayer[currentPlayer.id] ?? [])
            .filter { ids.contains($0) }
        for c in hand where !order.contains(c.id) {
            order.append(c.id)
        }
        let byId = Dictionary(uniqueKeysWithValues: hand.map { ($0.id, $0) })
        return order.compactMap { byId[$0] }
    }

    /// Reorder relative to another visible card. This remains correct while
    /// some cards are staged and therefore absent from the hand fan.
    public func moveHandCard(_ cardId: UUID, before targetId: UUID?) {
        var order = orderedHand.map { $0.id }
        guard let from = order.firstIndex(of: cardId) else { return }
        order.remove(at: from)
        if let targetId, let target = order.firstIndex(of: targetId) {
            order.insert(cardId, at: target)
        } else {
            order.append(cardId)
        }
        handOrderByPlayer[currentPlayer.id] = order
    }

    public func sortHandByRank() {
        let sorted = orderedHand.sorted {
            rankSortKey($0) < rankSortKey($1)
        }
        handOrderByPlayer[currentPlayer.id] = sorted.map(\.id)
    }

    public func sortHandBySuit() {
        let sorted = orderedHand.sorted {
            suitSortKey($0) < suitSortKey($1)
        }
        handOrderByPlayer[currentPlayer.id] = sorted.map(\.id)
    }

    private func rankSortKey(_ card: Card) -> String {
        let wildBucket = card.isWild ? 1 : 0
        let rank = card.rank?.rawValue ?? 99
        let suit = suitIndex(card.suit)
        return String(format: "%01d-%02d-%01d-%@",
                      wildBucket, rank, suit, card.id.uuidString)
    }

    private func suitSortKey(_ card: Card) -> String {
        let wildBucket = card.isWild ? 1 : 0
        let suit = suitIndex(card.suit)
        let rank = card.rank?.rawValue ?? 99
        return String(format: "%01d-%01d-%02d-%@",
                      wildBucket, suit, rank, card.id.uuidString)
    }

    private func suitIndex(_ suit: Suit?) -> Int {
        switch suit {
        case .clubs: return 0
        case .diamonds: return 1
        case .hearts: return 2
        case .spades: return 3
        case .none: return 4
        }
    }

    // MARK: - Staging (M2d)

    /// Toggle a card's staged state. Staged cards render above the hand fan
    /// and are the working set for the next `.goDown` or `.addToMeld` action.
    /// Silently ignored if the card isn't in the current player's hand.
    public func toggleStaged(cardId: UUID) {
        guard isLocalPlayersTurn,
              currentPlayer.hand.contains(where: { $0.id == cardId }),
              !draftCardIds.contains(cardId) else { return }
        if stagedCardIds.contains(cardId) {
            stagedCardIds.remove(cardId)
        } else {
            stagedCardIds.insert(cardId)
        }
    }

    /// Cards currently staged. Valid sequences are returned in canonical table
    /// order even when their cards were scattered throughout the hand.
    public var stagedCards: [Card] {
        let selected = orderedHand.filter { stagedCardIds.contains($0.id) }
        if case .success = MeldValidator.validateTriplet(selected) {
            return selected
        }
        if case .success(let arranged) = MeldValidator.arrangedSequence(selected) {
            return arranged
        }
        return selected
    }

    /// Cards remaining in-hand after staging (rendered in the hand fan).
    public var unstagedCards: [Card] {
        orderedHand.filter {
            !stagedCardIds.contains($0.id) && !draftCardIds.contains($0.id)
        }
    }

    /// Live validation of the current staging tray. `nil` when empty; on
    /// non-empty tray it returns the underlying `MeldValidator.validate`
    /// result so the UI can show ✓ (with kind) or ✗ (with reason).
    public var stagedValidation: Result<Meld.Kind, MeldValidator.ValidationError>? {
        let cards = stagedCards
        guard !cards.isEmpty else { return nil }
        return MeldValidator.validate(cards)
    }

    /// Clear staging. Called after a turn ends or the player cancels.
    public func clearStaging() { stagedCardIds.removeAll() }

    // MARK: - Go-down draft (M2d-c)

    /// Completed melds toward the current player's go-down contract. Each
    /// entry is a valid meld the player has "saved" from the staging tray
    /// but not yet committed. Committed together on `confirmGoDown`.
    @Published public private(set) var contractDraft: [[Card]] = []

    private var draftCardIds: Set<UUID> {
        Set(contractDraft.flatMap { $0.map(\.id) })
    }

    /// Move the current staged tray into the draft as a new completed
    /// meld. No-op if staging is empty or invalid.
    @discardableResult
    public func saveStagedAsMeld() -> Bool {
        guard isLocalPlayersTurn,
              state.phase == .awaitingMeldOrDiscard,
              case .success = stagedValidation else {
            return false
        }
        contractDraft.append(stagedCards)
        stagedCardIds.removeAll()
        return true
    }

    /// Undo one saved draft meld: cards return to the hand's un-staged pool.
    /// They're still in `currentPlayer.hand`; the draft is UI-side state.
    public func removeDraftMeld(at index: Int) {
        guard contractDraft.indices.contains(index) else { return }
        contractDraft.remove(at: index)
    }

    public func clearContractDraft() {
        contractDraft.removeAll()
    }

    /// The draft's shape (kind + size for each meld), sorted for order-
    /// independent comparison against the current contract.
    private var draftShape: [String] {
        contractDraft.compactMap { cards -> String? in
            switch MeldValidator.validate(cards) {
            case .success(let kind): return "\(kind.rawValue)-\(cards.count)"
            case .failure: return nil
            }
        }.sorted()
    }

    private var contractShape: [String] {
        guard let c = state.contract(forPlayer: currentPlayer.id) else { return [] }
        return c.components.map { comp -> String in
            switch comp {
            case .triplet(let n): return "triplet-\(n)"
            case .sequence(let n): return "sequence-\(n)"
            }
        }.sorted()
    }

    /// True when the draft exactly satisfies the current player's contract.
    public var canConfirmGoDown: Bool {
        guard isLocalPlayersTurn,
              state.phase == .awaitingMeldOrDiscard,
              !currentPlayer.hasGoneDownThisRound else {
            return false
        }
        return draftShape == contractShape && !contractShape.isEmpty
    }

    /// Progress summary for the inline meld tray.
    public var goDownProgressText: String {
        guard let c = state.contract(forPlayer: currentPlayer.id) else {
            return "No contract"
        }
        if canConfirmGoDown { return "✓ Ready to go down" }
        let needed = c.components.map { comp -> String in
            switch comp {
            case .triplet(let n): return "triplet-\(n)"
            case .sequence(let n): return "sequence-\(n)"
            }
        }
        var remaining = needed.sorted()
        for saved in draftShape {
            if let i = remaining.firstIndex(of: saved) { remaining.remove(at: i) }
        }
        if remaining.isEmpty { return "✓ Ready to go down" }
        let pretty = remaining.map { key -> String in
            let parts = key.split(separator: "-")
            let n = parts.last ?? "?"
            return parts.first == "triplet" ? "triplet of \(n)" : "sequence of \(n)"
        }.joined(separator: " + ")
        return "Still need: \(pretty)"
    }

    /// Commit the draft as `.goDown`. Returns whether the dispatch succeeded.
    @discardableResult
    public func confirmGoDown() -> Bool {
        guard canConfirmGoDown else { return false }
        let draft = contractDraft
        let ok = dispatch(.goDown(playerId: currentPlayer.id, contract: draft))
        if ok && !isOnlineGame {
            contractDraft.removeAll()
            stagedCardIds.removeAll()
        }
        return ok
    }

    // MARK: - Table card play (M2d-c)

    public func redemptionWildCardId(for card: Card, in meld: Meld) -> UUID? {
        guard canPlayFromHand(card) else { return nil }
        return MeldValidator.redeemableWildCardId(in: meld, using: card)
    }

    public func canPlay(_ card: Card, to meld: Meld) -> Bool {
        redemptionWildCardId(for: card, in: meld) != nil
            || canLayOff(card, to: meld)
    }

    public func canPlayAnyHandCard(to meld: Meld) -> Bool {
        currentPlayer.hand.contains { canPlay($0, to: meld) }
    }

    @discardableResult
    public func playHandCard(_ card: Card, to meldId: UUID) -> Bool {
        guard let meld = state.melds.first(where: { $0.id == meldId }) else {
            return false
        }
        if let wildCardId = redemptionWildCardId(for: card, in: meld) {
            return dispatch(
                .redeemWild(
                    playerId: currentPlayer.id,
                    meldId: meld.id,
                    wildCardId: wildCardId,
                    replacementCard: card
                )
            )
        }
        return layoffHandCard(card, to: meldId)
    }

    @discardableResult
    public func playTappedHandCard(_ card: Card) -> Bool {
        guard canPlayFromHand(card) else { return false }

        // Prefer the exact-slot redemption when a tap could also extend
        // another meld; dragging still lets the player choose a specific meld.
        for meld in state.melds
            where redemptionWildCardId(for: card, in: meld) != nil {
            return playHandCard(card, to: meld.id)
        }
        for meld in state.melds where canLayOff(card, to: meld) {
            return layoffHandCard(card, to: meld.id)
        }
        return false
    }

    /// If the player has gone down and `card` extends some existing meld,
    /// dispatch the `.addToMeld`. Returns true if the layoff succeeded.
    /// Called from a single-tap on a hand card (not a drag).
    @discardableResult
    public func layoffTappedHandCard(_ card: Card) -> Bool {
        guard currentPlayer.hasGoneDownThisRound,
              !currentPlayer.laidDownThisTurn else { return false }
        for meld in state.melds {
            if layoffHandCard(card, to: meld.id) { return true }
        }
        return false
    }

    public func canLayOff(_ card: Card, to meld: Meld) -> Bool {
        guard canPlayFromHand(card) else { return false }
        return isValid(meld.kind, cards: meld.cards + [card])
            || isValid(meld.kind, cards: [card] + meld.cards)
    }

    public func canLayOffAnyHandCard(to meld: Meld) -> Bool {
        currentPlayer.hand.contains { canLayOff($0, to: meld) }
    }

    @discardableResult
    public func layoffHandCard(_ card: Card, to meldId: UUID) -> Bool {
        guard let meld = state.melds.first(where: { $0.id == meldId }),
              canLayOff(card, to: meld) else { return false }
        if isValid(meld.kind, cards: meld.cards + [card]) {
            return dispatch(.addToMeld(playerId: currentPlayer.id,
                                       meldId: meld.id,
                                       cardsAtStart: [],
                                       cardsAtEnd: [card]))
        }
        return dispatch(.addToMeld(playerId: currentPlayer.id,
                                   meldId: meld.id,
                                   cardsAtStart: [card],
                                   cardsAtEnd: []))
    }

    private func canPlayFromHand(_ card: Card) -> Bool {
        isLocalPlayersTurn
            && state.phase == .awaitingMeldOrDiscard
            && currentPlayer.hasGoneDownThisRound
            && !currentPlayer.laidDownThisTurn
            && currentPlayer.hand.contains(where: { $0.id == card.id })
    }

    private func isValid(_ kind: Meld.Kind, cards: [Card]) -> Bool {
        switch kind {
        case .triplet:
            if case .success = MeldValidator.validateTriplet(cards) { return true }
        case .sequence:
            if case .success = MeldValidator.validateSequence(cards) { return true }
        }
        return false
    }

    // MARK: - CPU practice bot (M1e)

    /// True when the player whose turn it is right now is a CPU.
    public var isCurrentPlayerCPU: Bool {
        cpuPlayerIds.contains(state.currentPlayerId)
    }

    /// If the current player is a CPU and the round is still live, run a
    /// single action (typically draw OR meld/discard). Returns whether an
    /// action was applied. Safe to call any time.
    @discardableResult
    public func stepCurrentCPUTurn() -> Bool {
        guard isCurrentPlayerCPU else { return false }
        guard state.phase == .awaitingDraw
                || state.phase == .awaitingMeldOrDiscard else { return false }
        let action = CPUPlayer.nextAction(for: state.currentPlayerId, in: state)
        return dispatch(action)
    }

    /// Pump CPU actions until it's a human's turn (or the round/game ends).
    /// Caps iterations to avoid any theoretical infinite loop from a bad
    /// heuristic — 200 covers dozens of full turns per player.
    public func runAllCPUTurns() {
        isRunningCPUTurns = true
        defer { isRunningCPUTurns = false }
        var guardCounter = 0
        while isCurrentPlayerCPU
                && (state.phase == .awaitingDraw
                    || state.phase == .awaitingMeldOrDiscard)
                && guardCounter < 200 {
            if !stepCurrentCPUTurn() { break }
            guardCounter += 1
        }
    }
}
