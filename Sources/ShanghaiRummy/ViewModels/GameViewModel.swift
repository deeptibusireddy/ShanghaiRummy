import Foundation
import Combine

/// Owns the current `GameState` for the UI and forwards user actions to
/// `TurnEngine`. Pure rules + persistence live in the engine; this class only
/// glues them to SwiftUI/SpriteKit.
///
/// Hot-seat mode: a single instance drives all players on one device. When we
/// wire GameKit in M3 this will grow a `sendTurn(state:)` hook, but the surface
/// area stays the same for the UI.
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

    /// Whether the "Build Meld" modal overlay is visible. Toggled by the
    /// on-table button chip; kept on the VM so UI tests can drive it via a
    /// launch flag.
    @Published public var isMeldOverlayOpen: Bool = false

    /// IDs of players controlled by the CPU practice bot (M1e). Empty in
    /// hot-seat / GameKit modes.
    @Published public var cpuPlayerIds: Set<UUID> = []

    /// Re-entrancy guard for the CPU auto-play loop (see `dispatch`).
    private var isRunningCPUTurns: Bool = false

    // MARK: - Init

    public init(state: GameState) {
        self.state = state
    }

    /// Convenience factory: build a fresh match from names.
    public static func newHotSeat(playerNames: [String], seed: UInt64? = nil) -> GameViewModel {
        let s = seed ?? UInt64.random(in: 0...UInt64.max)
        return GameViewModel(state: GameFactory.newGame(playerNames: playerNames, seed: s))
    }

    // MARK: - Derived helpers used by views

    public var currentPlayer: Player { state.players[state.currentTurnIndex] }
    public var currentPlayerName: String { currentPlayer.name }
    public var currentContractDescription: String {
        state.currentContract?.displayName ?? "—"
    }
    public var canDrawFromDiscard: Bool {
        state.phase == .awaitingDraw && !state.discard.isEmpty
    }
    public var canDrawFromStock: Bool {
        state.phase == .awaitingDraw && !state.stock.isEmpty
    }

    // MARK: - Action dispatch

    /// Central action dispatcher. Applies the action to the engine, publishes
    /// the new state or the error message, and returns `true` on success.
    @discardableResult
    public func dispatch(_ action: TurnEngine.Action) -> Bool {
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
                isBetweenTurns = !(outgoingIsCPU || incomingIsCPU)
                stagedCardIds.removeAll()
                contractDraft.removeAll()
                isMeldOverlayOpen = false
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
    public func buy(as playerId: UUID) {
        dispatch(.buy(playerId: playerId))
    }

    /// Trigger end-of-hand accounting: score, advance levels, deal next hand.
    /// Fails silently (setting `lastError`) if the game isn't in `.roundEnded`.
    public func advanceHand() {
        switch TurnEngine.advanceHand(state: state) {
        case .success(let newState):
            state = newState
            lastError = nil
            isBetweenTurns = false
        case .failure(let err):
            lastError = err.description
        }
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

    // MARK: - Staging (M2d)

    /// Toggle a card's staged state. Staged cards render above the hand fan
    /// and are the working set for the next `.goDown` or `.addToMeld` action.
    /// Silently ignored if the card isn't in the current player's hand.
    public func toggleStaged(cardId: UUID) {
        guard currentPlayer.hand.contains(where: { $0.id == cardId }) else { return }
        if stagedCardIds.contains(cardId) {
            stagedCardIds.remove(cardId)
        } else {
            stagedCardIds.insert(cardId)
        }
    }

    /// Cards currently staged, in the order they appear in the player's hand.
    public var stagedCards: [Card] {
        currentPlayer.hand.filter { stagedCardIds.contains($0.id) }
    }

    /// Cards remaining in-hand after staging (rendered in the hand fan).
    public var unstagedCards: [Card] {
        currentPlayer.hand.filter { !stagedCardIds.contains($0.id) }
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

    /// Move the current staged tray into the draft as a new completed
    /// meld. No-op if staging is empty or invalid.
    @discardableResult
    public func saveStagedAsMeld() -> Bool {
        guard case .success = stagedValidation else { return false }
        contractDraft.append(stagedCards)
        stagedCardIds.removeAll()
        return true
    }

    /// Undo one saved draft meld: cards return to the hand's un-staged pool.
    /// (They're still in `currentPlayer.hand` — the draft is a UI overlay.)
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
        guard !currentPlayer.hasGoneDownThisRound else { return false }
        return draftShape == contractShape && !contractShape.isEmpty
    }

    /// Progress summary for the overlay ("Need 1 more triplet of 3", etc.).
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
        if ok {
            contractDraft.removeAll()
            stagedCardIds.removeAll()
            isMeldOverlayOpen = false
        }
        return ok
    }

    // MARK: - Tap-to-lay-off (M2d-c)

    /// If the player has gone down and `card` extends some existing meld,
    /// dispatch the `.addToMeld`. Returns true if the layoff succeeded.
    /// Called from a single-tap on a hand card (not a drag).
    @discardableResult
    public func layoffTappedHandCard(_ card: Card) -> Bool {
        guard currentPlayer.hasGoneDownThisRound,
              !currentPlayer.laidDownThisTurn else { return false }
        for meld in state.melds {
            let appended = meld.cards + [card]
            let prepended = [card] + meld.cards
            if isValid(meld.kind, cards: appended) {
                return dispatch(.addToMeld(playerId: currentPlayer.id,
                                           meldId: meld.id,
                                           cardsAtStart: [],
                                           cardsAtEnd: [card]))
            }
            if isValid(meld.kind, cards: prepended) {
                return dispatch(.addToMeld(playerId: currentPlayer.id,
                                           meldId: meld.id,
                                           cardsAtStart: [card],
                                           cardsAtEnd: []))
            }
        }
        return false
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
