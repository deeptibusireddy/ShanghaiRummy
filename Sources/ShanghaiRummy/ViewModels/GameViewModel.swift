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
        switch TurnEngine.apply(action, to: state) {
        case .success(let newState):
            let didAdvanceTurn =
                newState.currentTurnIndex != state.currentTurnIndex
                && newState.phase == .awaitingDraw
            state = newState
            lastError = nil
            if didAdvanceTurn {
                // Trigger the pass-and-play interstitial before the next player
                // takes the device.
                isBetweenTurns = true
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
}
