import Foundation

/// Convenience factory for setting up a fresh match. Used by tests today and
/// by the UI/lobby code later.
public enum GameFactory {
    /// Deal a fresh round: sets up stock, deals `RulesConfig.handSizeAtDeal`
    /// cards to each player, and flips the initial discard card. Uses a
    /// deterministic RNG so multiplayer clients agree.
    public static func newGame(playerNames: [String], seed: UInt64) -> GameState {
        precondition(playerNames.count >= RulesConfig.minPlayers, "Too few players")
        precondition(playerNames.count <= RulesConfig.maxPlayers, "Too many players")

        var rng = SeededRNG(seed: seed)
        var deck = Deck(playerCount: playerNames.count)
        deck.shuffle(using: &rng)

        var players = playerNames.map { Player(name: $0) }
        for pi in players.indices {
            for _ in 0..<RulesConfig.handSizeAtDeal {
                if let c = deck.draw() { players[pi].hand.append(c) }
            }
        }
        let initialDiscard = deck.draw().map { [$0] } ?? []

        return GameState(
            players: players,
            currentRound: 1,
            currentTurnIndex: (0 + 1) % players.count, // player to dealer's left
            dealerIndex: 0,
            stock: deck.cards,
            discard: initialDiscard,
            melds: [],
            phase: .awaitingDraw,
            stockReshufflesUsed: 0,
            randomSeed: seed
        )
    }

    /// Deal the next hand while carrying forward player identities, cumulative
    /// scores, and current levels. Called by `TurnEngine.advanceHand` after a
    /// hand ends. Deterministic — same match seed + hand number always
    /// produces the same shuffle across all clients.
    public static func newHand(from state: GameState) -> GameState {
        let nextHandNumber = state.currentRound + 1
        // Derive a distinct-but-deterministic seed for this hand from the
        // match seed. Hand 1 uses the raw match seed (for compatibility with
        // `newGame`); hands 2+ mix in the hand number.
        let handSeed = state.randomSeed &+
            (UInt64(nextHandNumber - 1) &* 0x9E3779B97F4A7C15)
        var rng = SeededRNG(seed: handSeed)
        var deck = Deck(playerCount: state.players.count)
        deck.shuffle(using: &rng)

        // Reset per-hand player state; preserve id, name, totalScore, currentLevel.
        var players = state.players.map { p in
            Player(
                id: p.id,
                name: p.name,
                hand: [],
                totalScore: p.totalScore,
                buysUsedThisRound: 0,
                hasGoneDownThisRound: false,
                laidDownThisTurn: false,
                currentLevel: p.currentLevel
            )
        }
        for pi in players.indices {
            for _ in 0..<RulesConfig.handSizeAtDeal {
                if let c = deck.draw() { players[pi].hand.append(c) }
            }
        }
        let initialDiscard = deck.draw().map { [$0] } ?? []

        // Rotate dealer left; first to act is player after new dealer.
        let newDealer = (state.dealerIndex + 1) % players.count
        return GameState(
            players: players,
            currentRound: nextHandNumber,
            currentTurnIndex: (newDealer + 1) % players.count,
            dealerIndex: newDealer,
            stock: deck.cards,
            discard: initialDiscard,
            melds: [],
            phase: .awaitingDraw,
            stockReshufflesUsed: 0,
            randomSeed: state.randomSeed,
            gameWinnerIds: []
        )
    }
}
