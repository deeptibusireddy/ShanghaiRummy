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
}
